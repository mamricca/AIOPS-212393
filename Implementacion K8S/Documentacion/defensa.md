# Guión de Defensa — PharmaGo AIOps

## Índice
1. [Setup inicial del cluster](#1-setup-inicial)
2. [Verificación pre-demo](#2-verificación-pre-demo)
3. [Demo RB-01 — Alto error rate 5xx](#3-demo-rb-01)
4. [Demo RB-02 — Alto CPU p95](#4-demo-rb-02)
5. [Limpieza post-demo](#5-limpieza)
6. [Troubleshooting si algo sale mal](#6-troubleshooting)

---

## 1. Setup inicial

> Ejecutar esto **antes** de la defensa. Tarda ~3-5 minutos.

### 1.1 Levantar Minikube

```powershell
minikube start --memory=7168 --cpus=4
```

### 1.2 Aplicar todos los manifiestos

```powershell
cd "Implementacion K8S\Codigo\k8s"
.\apply-k8s.ps1
# Luego aplicar los configmaps adicionales de Grafana:
kubectl apply -f configmaps\grafana-alerting.yaml
kubectl apply -f configmaps\grafana-dashboard-rb01.yaml
kubectl apply -f configmaps\grafana-dashboard-backend-cpu.yaml
```

### 1.3 Esperar que todos los pods estén Running

```powershell
kubectl get pods -n pharmago -w
```

> Esperar hasta ver todos en `Running`. Puede tardar 2-4 minutos (SQL Server tarda más).

### 1.4 Cargar imágenes de la app en Minikube (si es primera vez)

```powershell
minikube image load pharmago-users-service:latest
minikube image load pharmago-pharmacy-service:latest
minikube image load pharmago-api-gateway:latest
minikube image load pharmago-ui:latest
```

### 1.5 Abrir los port-forwards (procesos independientes)

```powershell
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/grafana","3000:3000","-n","pharmago"
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/pharmago-api-gateway","5000:80","-n","pharmago"
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/prometheus","9090:9090","-n","pharmago"
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/kibana","5601:5601","-n","pharmago"
```

### 1.6 Verificar acceso

```powershell
# Grafana
(Invoke-WebRequest -Uri "http://127.0.0.1:3000/api/health" -UseBasicParsing).StatusCode
# Esperado: 200

# API Gateway
(Invoke-WebRequest -Uri "http://127.0.0.1:5000/metrics" -UseBasicParsing).StatusCode
# Esperado: 200
```

---

## 2. Verificación pre-demo

> Confirmar estado limpio antes de arrancar cualquier demo.

### 2.1 Todos los pods sanos

```powershell
kubectl get pods -n pharmago
```

Esperado: todos `Running` con `RESTARTS` bajos (idealmente 0).

### 2.2 Error rate en 0

```powershell
curl.exe -s "http://127.0.0.1:9090/api/v1/query?query=sum(rate(pharmago_http_errors_total[1m]))" `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Error rate:', float(r[0]['value'][1]) if r else 0)"
```

Esperado: `0.0` o sin datos.

### 2.3 CPU en baseline

```powershell
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=avg(sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100)' `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('CPU avg api-gateway:', round(float(r[0]['value'][1]),1), '%' if r else 'sin datos')"
```

Esperado: < 15%.

### 2.4 Réplicas en 2

```powershell
kubectl get deployments -n pharmago pharmago-api-gateway pharmago-users-service pharmago-pharmacy-service
```

Esperado: `READY 2/2` en todas.

### 2.5 Alertas en Normal en Grafana

Abrir: http://127.0.0.1:3000 → Alerting → Alert Rules → carpeta PharmaGo

Ambas alertas deben estar en **Normal** (verde).

---

## 3. Demo RB-01 — Alto error rate 5xx

### Narrativa
> "Vamos a simular una falla en la base de datos que provoca errores 5xx sostenidos en el servicio de usuarios. El sistema detecta la anomalía mediante la alerta configurada en Grafana y seguimos el runbook RB-01 para identificar y resolver el incidente."

---

### 3.1 Mostrar estado normal en Grafana

Abrir en el navegador:
- http://127.0.0.1:3000 → **PharmaGo - RB-01 5xx Error Rate**

Señalar que la tasa de errores es 0 y el pod DB está saludable.

---

### 3.2 Disparar el chaos

```powershell
cd "Implementacion K8S\Codigo\chaos-engineering"
bash trigger-5xx-alert.sh
```

> El script elimina el pod de DB repetidamente y envía requests al gateway (4 req cada 3s, bajo el rate limit). Los servicios no pueden conectar a la DB → errores 5xx.

Mientras corre, mostrar en Grafana el panel **"Tasa de errores"** subiendo y cruzando la línea roja (umbral 0.1 req/s).

---

### 3.3 Confirmar alerta Firing (~60-90s después)

En Grafana → Alerting → Alert Rules → `[PharmaGo] High 5xx Error Rate` → **Firing** (rojo).

Verificar por CLI:
```powershell
curl.exe -s "http://127.0.0.1:9090/api/v1/query?query=sum(rate(pharmago_http_errors_total[1m]))" `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Error rate:', round(float(r[0]['value'][1]),4), 'req/s')"
```

Esperado: > 0.1 req/s.

---

### 3.4 Seguir RB-01 — Paso 1: Diagnóstico inicial

```powershell
# Ver todos los pods — identificar cuál no está Ready
kubectl get pods -n pharmago

# Ver eventos recientes del namespace
kubectl get events -n pharmago --sort-by='.lastTimestamp' | Select-Object -Last 15
```

**Qué decir:** "El pod pharmago-db no está Ready — es la causa raíz más probable."

---

### 3.5 RB-01 — Paso 2: Revisar logs del servicio afectado

```powershell
kubectl logs -n pharmago -l app=pharmago-users-service --tail=10
```

Buscar la línea:
```
"A network-related or instance-specific error occurred while establishing a connection to SQL Server"
```

**Qué decir:** "Los logs confirman que users-service no puede conectar a la DB — `SqlException: Could not open a connection to SQL Server`. Causa raíz confirmada."

---

### 3.6 RB-01 — Paso 3: Verificar estado de la DB

```powershell
kubectl get pod -n pharmago -l app=pharmago-db
```

Esperado: `0/1 Running` o `Init:0/1` — pod caído o reiniciando.

---

### 3.7 RB-01 — Paso 4a: Contención (DB caída)

> El chaos script sigue eliminando el pod cada 3s mientras corre. Esperar a que el script termine (90s total), entonces la DB puede levantarse.

Monitorear la recuperación:
```powershell
kubectl get pod -n pharmago -l app=pharmago-db -w
```

Cuando el script termine y la DB se estabilice:
```powershell
# Si la DB no se recupera sola, forzar restart:
kubectl rollout restart deployment/pharmago-db -n pharmago
kubectl rollout status deployment/pharmago-db -n pharmago --timeout=120s
```

---

### 3.8 RB-01 — Paso 6: Verificar recuperación

```powershell
# Confirmar DB Ready
kubectl get pod -n pharmago -l app=pharmago-db

# Test manual de login
curl.exe -s -o NUL -w "HTTP %{http_code}`n" `
  -X POST http://127.0.0.1:5000/api/login `
  -H "Content-Type: application/json" `
  -d '{\"userName\":\"test\",\"password\":\"test\"}'
```

Esperado: HTTP 400 (credenciales incorrectas, pero el servicio responde — no es 500).

```powershell
# Confirmar error rate volvió a 0
curl.exe -s "http://127.0.0.1:9090/api/v1/query?query=sum(rate(pharmago_http_errors_total[1m]))" `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Error rate:', round(float(r[0]['value'][1]),4) if r else 0)"
```

Esperado: ~0.

En Grafana → alerta vuelve a **Normal** (verde).

---

## 4. Demo RB-02 — Alto CPU p95

> Esperar ~2 minutos después del RB-01 para que el error rate limpie y la métrica de CPU esté en baseline.

### Narrativa
> "Ahora simulamos un escenario de CPU elevado en los pods del API gateway. El sistema detecta que el promedio de CPU supera el 40% y dispara la alerta RB-02. La mitigación consiste en escalar horizontalmente a 3 réplicas, distribuyendo la carga."

---

### 4.1 Mostrar estado normal en Grafana

Abrir: http://127.0.0.1:3000 → **PharmaGo - CPU Backend**

Señalar que el CPU está en baseline (< 15%) en ambos pods del api-gateway.

---

### 4.2 Verificar baseline antes de arrancar

```powershell
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=avg(sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100)' `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('CPU avg:', round(float(r[0]['value'][1]),1), '%')"
```

Esperado: < 15%. Si está en 50%, hay procesos huérfanos — reiniciar los pods:
```powershell
kubectl rollout restart deployment/pharmago-api-gateway -n pharmago
kubectl rollout status deployment/pharmago-api-gateway -n pharmago --timeout=90s
```

---

### 4.3 Disparar el chaos

```powershell
cd "Implementacion K8S\Codigo\chaos-engineering"
bash trigger-cpu-p95-alert.sh
```

> El script inyecta 4 busy-loops dentro de cada pod de api-gateway durante 300 segundos. El CPU de cada pod sube hasta el límite de 500m (50% de un core).

---

### 4.4 Confirmar alerta Firing (~60-90s después)

Mientras espera, mostrar en Grafana el panel **"CPU avg api-gateway"** subiendo y cruzando la línea roja (40%).

```powershell
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=avg(sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100)' `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; v=float(r[0]['value'][1]) if r else 0; print('CPU avg:', round(v,1), '%  -> FIRING' if v>40 else '%  -> esperando')"
```

En Grafana → Alerting → `[PharmaGo] High CPU p95` → **Firing**.

---

### 4.5 Seguir RB-02 — Paso 1: Identificar pods afectados

```powershell
# Ver CPU por pod
kubectl top pods -n pharmago --sort-by=cpu 2>$null
# Si no funciona, usar Prometheus directamente:
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100' `
  | python -c "import sys,json; d=json.load(sys.stdin); [print(r['metric']['pod'], '->', round(float(r['value'][1]),1), '%') for r in d['data']['result']]"
```

**Qué decir:** "Ambos pods del api-gateway están al 50% de CPU — en el límite de su resource limit de 500m. El promedio supera el umbral del 40%."

---

### 4.6 RB-02 — Paso 4b: Mitigación — escalar a 3 réplicas

```powershell
kubectl scale deployment/pharmago-api-gateway -n pharmago --replicas=3
```

Verificar que la nueva réplica levanta:
```powershell
kubectl get pods -n pharmago -l app=pharmago-api-gateway -w
```

Esperado: 3 pods, el nuevo en `0/1 → 1/1 Running`.

---

### 4.7 Confirmar recuperación de la alerta

```powershell
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=avg(sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100)' `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('CPU avg:', round(float(r[0]['value'][1]),1), '%')"
```

Esperado: ~33-35% (bajo el umbral de 40%).

**Qué decir:** "Con la tercera réplica sin carga de chaos, el promedio baja de 50% a ~33%. El sistema sale del estado de alerta. Esta es una mitigación temporal — el paso siguiente sería identificar y eliminar los procesos que consumen CPU anormalmente."

En Grafana → alerta pasa a **Normal**.

---

### 4.8 Script termina → CPU vuelve a baseline

Cuando el script de chaos termina (300s), los busy-loops se matan automáticamente:

```powershell
curl.exe -s 'http://127.0.0.1:9090/api/v1/query?query=avg(sum+by(pod)(rate(container_cpu_usage_seconds_total{namespace="pharmago",pod=~"pharmago-api-gateway.*"}[1m]))*100)' `
  | python -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('CPU avg post-chaos:', round(float(r[0]['value'][1]),1), '%')"
```

Esperado: < 5% en los 3 pods.

---

## 5. Limpieza post-demo

```powershell
# Volver a 2 réplicas
kubectl scale deployment/pharmago-api-gateway -n pharmago --replicas=2

# Confirmar estado final
kubectl get deployments -n pharmago
kubectl get pods -n pharmago
```

---

## 6. Troubleshooting si algo sale mal

### El alert no pasa a Firing
```powershell
# Verificar que la regla existe en Grafana
curl.exe -s "http://admin:admin@127.0.0.1:3000/api/ruler/grafana/api/v1/rules/PharmaGo" | python -m json.tool | Select-Object -First 30

# Verificar que la query devuelve datos en Prometheus
curl.exe -s "http://127.0.0.1:9090/api/v1/query?query=sum(rate(pharmago_http_errors_total[1m]))"
```

### El port-forward del API gateway cayó (HTTP 000)
```powershell
# Buscar el PID que tiene el puerto
netstat -ano | Select-String ":5000 "
# Matar el PID (reemplazar XXXX)
taskkill /PID XXXX /F
# Reabrir
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/pharmago-api-gateway","5000:80","-n","pharmago"
```

### El Grafana no abre (puerto 3000 ocupado)
```powershell
netstat -ano | Select-String ":3000 "
taskkill /PID XXXX /F
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward","svc/grafana","3000:3000","-n","pharmago"
```

### El CPU de api-gateway sigue en 50% sin chaos corriendo (procesos huérfanos)
```powershell
kubectl rollout restart deployment/pharmago-api-gateway -n pharmago
kubectl rollout status deployment/pharmago-api-gateway -n pharmago --timeout=90s
```

### Todos los pods caídos / cluster roto
```powershell
# Ver estado general
kubectl get pods -n pharmago
kubectl get events -n pharmago --sort-by='.lastTimestamp' | Select-Object -Last 20

# Re-aplicar todo
cd "Implementacion K8S\Codigo\k8s"
.\apply-k8s.ps1
kubectl apply -f configmaps\grafana-alerting.yaml
kubectl apply -f configmaps\grafana-dashboard-rb01.yaml
kubectl apply -f configmaps\grafana-dashboard-backend-cpu.yaml
```

### El error rate no sube con el chaos de 5xx
1. Verificar que el port-forward del gateway está activo:
```powershell
(Invoke-WebRequest -Uri "http://127.0.0.1:5000/metrics" -UseBasicParsing).StatusCode
```
2. Hacer un request manual y ver el código:
```powershell
curl.exe -v -X POST http://127.0.0.1:5000/api/login `
  -H "Content-Type: application/json" `
  -d '{\"userName\":\"test\",\"password\":\"test\"}' 2>&1 | Select-String "< HTTP"
```
3. Si devuelve 429 (rate limit), esperar 60s y volver a correr el script.

---

## Dashboards en Grafana

| Dashboard | URL | Cuándo usarlo |
|---|---|---|
| PharmaGo - Overview | http://127.0.0.1:3000/d/afpc545287wg0f | Estado general de la app |
| PharmaGo - Infra | http://127.0.0.1:3000/d/pharmago-infra | CPU/Memoria de nodo y pods |
| PharmaGo - RB-01 5xx Error Rate | http://127.0.0.1:3000/d/pharmago-rb01 | Demo RB-01 |
| PharmaGo - CPU Backend | http://127.0.0.1:3000/d/pharmago-backend-cpu | Demo RB-02 |
| Alerting | http://127.0.0.1:3000/alerting/list | Ver estado de ambas alertas |
