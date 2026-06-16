# RB-02 — Alto Consumo CPU p95

| Campo | Valor |
|---|---|
| **Nombre** | RB-02 Alto Consumo CPU p95 |
| **Versión** | 2026-06-10 |
| **Autor** | Equipo SRE / DevOps |
| **Severidad estimada** | Sev2 / Sev3 |
| **Activación** | Alerta Grafana `[PharmaGo] High CPU p95` |
| **Objetivo** | Identificar la causa, reducir el consumo y estabilizar en < 30 min |

---

## 1. Alcance

Cubre incidentes en los que el percentil 95 del uso de CPU de los pods del namespace `pharmago` supera el 40% de un core durante más de 1 minuto.

No cubre problemas de CPU en el nodo Minikube subyacente ni en pods del stack de observabilidad (Prometheus, Grafana, etc.).

---

## 2. Criterios de Activación

- Alerta Grafana `[PharmaGo] High CPU p95` en estado **Firing**.
- `quantile(0.95, sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pharmago"}[5m]))) * 100 > 40` durante ≥ 1 minuto.
- O detección manual: latencia elevada en respuestas, pods en estado `Throttling`.

### Validación previa

1. **Grafana** → Panel "PharmaGo - Infra" → "CPU por pod (pharmago)" → identificar pod con spike.
2. **kubectl top** → confirmar consumo real de CPU.
3. **Kibana** → revisar si hay aumento de errores correlacionado con el spike de CPU.

---

## 3. Precondiciones

- Acceso a `kubectl` con contexto correcto.
- `kubectl top` disponible (metrics-server instalado en Minikube: `minikube addons enable metrics-server`).
- Acceso a Grafana: `kubectl port-forward -n pharmago svc/grafana 3000:3000`.

---

## 4. Procedimiento

### Paso 1 — Identificar el pod afectado (2 min)

```bash
# Ver consumo de CPU y memoria por pod en tiempo real
kubectl top pods -n pharmago --sort-by=cpu

# Ver uso de recursos detallado
kubectl top pods -n pharmago --containers

# Confirmar con Grafana: panel "CPU por pod (pharmago)"
# Query: sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pharmago"}[5m])) * 100
```

**Criterio de salida:** identificar el pod o pods con CPU elevado.

---

### Paso 2 — Descartar procesos de chaos / carga artificial (1 min)

```bash
# Ver procesos dentro del pod afectado
kubectl exec -n pharmago <POD> -- ps aux 2>/dev/null || \
kubectl exec -n pharmago <POD> -- top -b -n1 2>/dev/null | head -20

# Si hay procesos sh/bash en bucle (artefacto de chaos), terminarlos
kubectl exec -n pharmago <POD> -- sh -c "pkill -f 'while :' 2>/dev/null; true"
```

Si el spike es por chaos controlado, parar el script y monitorear retorno a baseline.

**Criterio de salida:** confirmar si el spike es por carga real de trabajo o por proceso externo.

---

### Paso 3 — Revisar logs para correlacionar con tráfico (2 min)

```bash
# Ver logs del pod afectado buscando requests de alta carga
kubectl logs -n pharmago <POD> --tail=100 | grep -E "correlation_id|operation|outcome"

# Ver si hay loop o error que provoca re-intentos
kubectl logs -n pharmago <POD> --tail=100 | grep -i "error\|exception\|retry"
```

En Kibana buscar tráfico inusual en el window temporal de la alerta:
```
component: "PurchasesController" OR component: "LoginController"
```

**Criterio de salida:** identificar si el spike es por tráfico legítimo, loop de errores o proceso descontrolado.

---

### Paso 4a — Contención: reiniciar el pod afectado

Si el pod tiene un proceso colgado o en loop:

```bash
# Reiniciar solo el pod afectado (K8s creará uno nuevo automáticamente)
kubectl delete pod -n pharmago <POD>

# Verificar que el nuevo pod levanta correctamente
kubectl get pods -n pharmago -w
```

**Criterio de salida:** nuevo pod en `Running 1/1`, CPU vuelve a baseline.

---

### Paso 4b — Mitigación: escalar horizontalmente para absorber carga

Si el CPU alto es por tráfico legítimo elevado:

```bash
# Escalar el deployment afectado
kubectl scale deployment/pharmago-api-gateway -n pharmago --replicas=3
kubectl scale deployment/pharmago-users-service -n pharmago --replicas=3

# Verificar que las nuevas réplicas están listas
kubectl rollout status deployment/pharmago-api-gateway -n pharmago
kubectl get pods -n pharmago -l app=pharmago-api-gateway
```

**Criterio de salida:** CPU distribuido entre réplicas, p95 < 40%.

---

### Paso 4c — Contención: rollback si el spike empezó con un nuevo deploy

```bash
# Ver cuándo empezó el spike vs. historial de despliegues
kubectl rollout history deployment/pharmago-api-gateway -n pharmago
kubectl rollout history deployment/pharmago-users-service -n pharmago

# Rollback al estado previo
kubectl rollout undo deployment/pharmago-api-gateway -n pharmago

# Verificar
kubectl rollout status deployment/pharmago-api-gateway -n pharmago
```

**Criterio de salida:** alerta en estado `Normal`, CPU p95 < 40% sostenido.

---

### Paso 5 — Verificación post-recuperación (5 min)

```bash
# Confirmar CPU bajó en todos los pods
kubectl top pods -n pharmago --sort-by=cpu

# Confirmar alerta en estado Normal
# En Grafana: quantile(0.95, ...) < 40 durante al menos 5 min

# Test de smoke: login y compra responden con latencia normal
curl -s -w "HTTP %{http_code} - %{time_total}s\n" -o /dev/null \
  -X POST http://127.0.0.1:5000/api/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"test","password":"test"}'
# Esperado: tiempo < 500ms
```

**Criterio de salida:** CPU p95 < 40%, alerta `Normal`, latencia de respuesta normal.

---

## 5. Rollback de este runbook

Si el escalamiento horizontal empeora la situación (por presión sobre DB):

```bash
# Volver a 2 réplicas
kubectl scale deployment/pharmago-api-gateway -n pharmago --replicas=2
kubectl scale deployment/pharmago-users-service -n pharmago --replicas=2
kubectl scale deployment/pharmago-pharmacy-service -n pharmago --replicas=2
```

---

## 6. Indicadores de Éxito

| Indicador | Valor esperado |
|---|---|
| `quantile(0.95, ...)` CPU p95 | < 40% de 1 core |
| Alerta Grafana `[PharmaGo] High CPU p95` | `Normal` |
| `kubectl top pods` | Todos los pods < 200m CPU |
| Latencia respuesta login | < 500ms |

---

## 7. Contactos y Escalamiento

| Rol | Acción |
|---|---|
| Incident Commander | Escalar a Sev1 si latencia impacta a usuarios |
| Líder Técnico | Revisar código si el spike es por loop o re-intentos |
| Equipo SRE | Ejecutar este runbook |

---

## 8. Referencias

- Dashboard Grafana: `http://localhost:3000` → "PharmaGo - Infra" → panel "CPU por pod"
- Script caos: `Codigo/chaos-engineering/trigger-cpu-p95-alert.sh`
- Script cpu genérico: `Codigo/chaos-engineering/cpu-spike.sh`
- Plan de incidentes: `Documentacion/Plan-Incidentes.md`

---

## 9. Historial de Cambios

| Fecha | Cambio | Autor |
|---|---|---|
| 2026-06-10 | Versión inicial | Equipo SRE |
