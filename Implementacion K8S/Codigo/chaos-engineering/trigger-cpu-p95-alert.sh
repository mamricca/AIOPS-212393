#!/bin/sh
# Chaos: CPU spike en los pods de api-gateway.
# Activa la alerta "[PharmaGo] High CPU p95" en Grafana.
#
# Flujo del demo:
#   1. Script inyecta carga CPU en los 2 pods existentes -> avg > 40% -> ALERTA
#   2. Operador escala a 3 replicas (RB-02) -> nueva replica sin carga -> avg baja a ~35% -> RECOVERY
#   3. Script termina -> pods vuelven a baseline ~5% -> CPU cae aun mas
#
# Uso: ./trigger-cpu-p95-alert.sh [segundos]
# Requiere: cluster Minikube corriendo con namespace pharmago activo.

SECS="${1:-300}"
NS="pharmago"
DEPLOY="pharmago-api-gateway"

echo "=== Chaos: trigger CPU p95 alert (${SECS}s) ==="
echo "Objetivo: pods de $DEPLOY en namespace $NS"
echo ""

PODS=$(kubectl get pod -n "$NS" -l app="$DEPLOY" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ -z "$PODS" ]; then
  echo "ERROR: no se encontraron pods para $DEPLOY en $NS"
  exit 1
fi

echo "Pods encontrados:"
for POD in $PODS; do
  echo "  - $POD"
done
echo ""
echo "Lanzando CPU spike (${SECS}s) en cada pod..."

for POD in $PODS; do
  echo "  Spike en: $POD"
  kubectl exec -n "$NS" "$POD" -- sh -c \
    "trap 'kill 0' TERM INT; (while :;do :;done)& (while :;do :;done)& (while :;do :;done)& (while :;do :;done)& sleep $SECS; kill 0" &
done

echo ""
echo "=== Spikes lanzados. ==="
echo ""
echo "PASO 1: Espera ~60s y verifica en Grafana que la alerta '[PharmaGo] High CPU p95' este en PENDING/FIRING."
echo "        Metrica: avg CPU de pods api-gateway deberia superar 40%."
echo ""
echo "PASO 2 (Mitigation - RB-02): Cuando el alert este FIRING, escala a 3 replicas:"
echo "        kubectl scale deployment/$DEPLOY -n $NS --replicas=3"
echo "        La nueva replica arranca sin carga -> avg CPU baja a ~35% -> alerta se cura."
echo ""
echo "PASO 3: Cuando el script termine (${SECS}s), todos los spikes se detienen."
echo "        El CPU vuelve al baseline (~5%) confirmando la recuperacion completa."
echo ""

wait
echo "=== CPU spikes completados. Pods volviendo a baseline. ==="
echo "    Para restaurar 2 replicas: kubectl scale deployment/$DEPLOY -n $NS --replicas=2"
