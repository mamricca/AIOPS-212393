#!/bin/sh
# Chaos: CPU spike simultaneo en todos los pods backend del namespace pharmago.
# Activa la alerta "[PharmaGo] High CPU p95" en Grafana.
# Uso: ./trigger-cpu-p95-alert.sh [segundos]
# El spike dura SECS segundos y luego los procesos terminan solos.

SECS="${1:-120}"
NS="pharmago"
SERVICES="pharmago-api-gateway pharmago-users-service pharmago-pharmacy-service"

echo "=== Chaos: trigger CPU p95 alert (${SECS}s) ==="
echo "Lanzando CPU spike en todos los pods backend..."

for DEPLOY in $SERVICES; do
  # Atacar TODOS los pods del deployment (ambas replicas)
  PODS=$(kubectl get pod -n "$NS" -l app="$DEPLOY" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [ -z "$PODS" ]; then
    echo "  Skip: no se encontraron pods para $DEPLOY"
    continue
  fi
  for POD in $PODS; do
    echo "  Spike en: $POD"
    kubectl exec -n "$NS" "$POD" -- sh -c \
      "(while :;do :;done)& (while :;do :;done)& (while :;do :;done)& (while :;do :;done)& sleep $SECS" &
  done
done

echo ""
echo "  Spikes lanzados. Espera ~60s para que Prometheus raspe las metricas."
echo "  Verificar en Grafana -> PharmaGo -> 'CPU por pod' y la alerta '[PharmaGo] High CPU p95'."
echo "  Al terminar los ${SECS}s, los procesos se detienen solos."
echo "  Seguir runbook RB-02 para el procedimiento completo."

wait
echo "=== CPU spikes completados ==="
