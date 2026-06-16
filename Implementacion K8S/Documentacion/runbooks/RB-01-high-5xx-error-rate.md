# RB-01 — Alto Error Rate 5xx

| Campo | Valor |
|---|---|
| **Nombre** | RB-01 Alto Error Rate 5xx |
| **Versión** | 2026-06-10 |
| **Autor** | Equipo SRE / DevOps |
| **Severidad estimada** | Sev1 / Sev2 |
| **Activación** | Alerta Grafana `[PharmaGo] High 5xx Error Rate` |
| **Objetivo** | Identificar, contener y restaurar el servicio en < 30 min |

---

## 1. Alcance

Cubre incidentes en los que los servicios backend de PharmaGo (api-gateway, users-service, pharmacy-service) retornan errores HTTP 5xx a una tasa sostenida > 0.1 req/s durante más de 1 minuto.

No cubre errores 4xx (bad request, unauthorized) ni problemas en el frontend.

---

## 2. Criterios de Activación

- Alerta Grafana `[PharmaGo] High 5xx Error Rate` en estado **Firing**.
- `rate(pharmago_http_errors_total[5m]) > 0.1` durante ≥ 1 minuto.
- O detección manual: usuarios reportan errores 500/502/503 al intentar login o compra.

### Validación previa (no escalar sin confirmar las 3 fuentes)

1. **Grafana** → Panel "PharmaGo - Infra" → verificar `pharmago_http_errors_total` subiendo.
2. **Kibana** → buscar `log: error` o `outcome: failed` en el window temporal de la alerta.
3. **kubectl** → verificar estado de pods (ver Paso 1 del procedimiento).

---

## 3. Precondiciones

- Acceso a `kubectl` con contexto apuntando al cluster (`kubectl config current-context`).
- Port-forward activo o acceso directo al gateway (si se necesita probar endpoints).
- Acceso a Grafana: `kubectl port-forward -n pharmago svc/grafana 3000:3000`.
- Acceso a Kibana: `kubectl port-forward -n pharmago svc/kibana 5601:5601`.

---

## 4. Procedimiento

### Paso 1 — Diagnóstico inicial (2 min)

```bash
# Estado general del namespace
kubectl get pods -n pharmago

# Ver pods con problemas
kubectl get pods -n pharmago | grep -v Running

# Ver eventos recientes del namespace
kubectl get events -n pharmago --sort-by='.lastTimestamp' | tail -20
```

**Criterio de salida:** identificar qué pod/servicio está generando los errores.

---

### Paso 2 — Revisar logs del servicio afectado (3 min)

```bash
# Reemplazar <POD> por el pod identificado en el paso anterior
kubectl logs -n pharmago <POD> --tail=100

# Con follow para ver errores en tiempo real
kubectl logs -n pharmago <POD> -f --tail=50

# Si el pod ya se reinició, ver logs del contenedor anterior
kubectl logs -n pharmago <POD> --previous --tail=100
```

En Kibana buscar por `correlation_id` para rastrear la cadena de llamadas:
```
component: "LoginController" AND outcome: "failed"
component: "PurchasesController" AND outcome: "failed"
```

**Criterio de salida:** identificar el stack trace / mensaje de error raíz.

---

### Paso 3 — Verificar dependencias críticas (2 min)

```bash
# Estado de la base de datos
kubectl get pod -n pharmago -l app=pharmago-db
kubectl logs -n pharmago -l app=pharmago-db --tail=30

# Conectividad DB desde un pod de servicio
kubectl exec -n pharmago deployment/pharmago-users-service -- \
  wget -q -O- http://pharmago-db:1433 2>&1 | head -5
```

**Criterio de salida:** confirmar si el problema es en la aplicación o en una dependencia (DB caída → ir a Paso 4a; error de aplicación → ir a Paso 4b).

---

### Paso 4a — Contención: DB caída o reiniciando

```bash
# Forzar recreación del pod de DB (ya lo hace K8s automáticamente via Deployment)
kubectl rollout restart deployment/pharmago-db -n pharmago

# Esperar a que la DB esté Ready
kubectl rollout status deployment/pharmago-db -n pharmago --timeout=120s

# Reiniciar los servicios que dependen de la DB para limpiar connection pools
kubectl rollout restart deployment/pharmago-users-service -n pharmago
kubectl rollout restart deployment/pharmago-pharmacy-service -n pharmago
```

**Criterio de salida:** DB y servicios en estado `Running 1/1`. Error rate vuelve a 0.

---

### Paso 4b — Contención: error de aplicación (regresión de deploy)

```bash
# Ver historial de rollouts del servicio afectado
kubectl rollout history deployment/pharmago-users-service -n pharmago
kubectl rollout history deployment/pharmago-pharmacy-service -n pharmago
kubectl rollout history deployment/pharmago-api-gateway -n pharmago

# Hacer rollback a la revisión anterior
kubectl rollout undo deployment/pharmago-users-service -n pharmago
# O a una revisión específica:
kubectl rollout undo deployment/pharmago-users-service -n pharmago --to-revision=<N>

# Verificar el rollback
kubectl rollout status deployment/pharmago-users-service -n pharmago
```

**Criterio de salida:** alerta en Grafana vuelve a estado `Normal`. Error rate < 0.05 req/s.

---

### Paso 5 — Escalamiento horizontal como mitigación temporal

Si los errores persisten por sobrecarga (no por DB ni regresión):

```bash
# Escalar el servicio afectado a 3 réplicas
kubectl scale deployment/pharmago-users-service -n pharmago --replicas=3
kubectl scale deployment/pharmago-pharmacy-service -n pharmago --replicas=3

# Verificar que las réplicas estén Ready
kubectl get pods -n pharmago -l app=pharmago-users-service
```

**Criterio de salida:** las nuevas réplicas están `Running`. Error rate decrece.

---

### Paso 6 — Verificación post-recuperación (5 min)

```bash
# Confirmar todos los pods en Running
kubectl get pods -n pharmago

# Test manual de login
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://127.0.0.1:5000/api/login \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: recovery-check-$(date +%s)" \
  -d '{"userName":"test","password":"test"}'
# Esperado: 200 o 400 (no 500)

# Confirmar alerta en Grafana en estado Normal
# Verificar que rate(pharmago_http_errors_total[5m]) < 0.05 en los últimos 5 min
```

**Criterio de salida:** todos los pods `Running`, alerta Grafana `Normal`, error rate < umbral.

---

## 5. Rollback de este runbook

Si los pasos de contención empeoran la situación:

```bash
# Restaurar réplicas originales
kubectl scale deployment/pharmago-users-service -n pharmago --replicas=2
kubectl scale deployment/pharmago-pharmacy-service -n pharmago --replicas=2

# Volver a la revisión previa al incidente
kubectl rollout undo deployment/<nombre> -n pharmago
```

---

## 6. Indicadores de Éxito

| Indicador | Valor esperado |
|---|---|
| `rate(pharmago_http_errors_total[5m])` | < 0.05 req/s |
| Alerta Grafana `[PharmaGo] High 5xx Error Rate` | `Normal` |
| Todos los pods | `Running` y `Ready` |
| Test curl al endpoint de login | HTTP 200 o 400 (no 5xx) |

---

## 7. Contactos y Escalamiento

| Rol | Acción |
|---|---|
| Incident Commander | Coordinar war room si no se resuelve en 15 min |
| Líder Técnico | Analizar RCA una vez estabilizado |
| Equipo SRE | Ejecutar este runbook |

---

## 8. Referencias

- Dashboard Grafana: `http://localhost:3000` → carpeta PharmaGo → "PharmaGo - Infra"
- Logs Kibana: `http://localhost:5601` → buscar `pharma_biz: login_fail` o `outcome: failed`
- Script caos: `Codigo/chaos-engineering/trigger-5xx-alert.sh`
- Plan de incidentes: `Documentacion/Plan-Incidentes.md`

---

## 9. Historial de Cambios

| Fecha | Cambio | Autor |
|---|---|---|
| 2026-06-10 | Versión inicial | Equipo SRE |
