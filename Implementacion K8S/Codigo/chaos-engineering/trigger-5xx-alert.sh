#!/bin/sh
# Chaos: genera errores 5xx eliminando el pod de base de datos y enviando requests sostenidos.
# Activa la alerta "[PharmaGo] High 5xx Error Rate" en Grafana.
# Uso: ./trigger-5xx-alert.sh [duracion_segundos] [gateway_url]
# Requiere port-forward activo: kubectl port-forward -n pharmago svc/pharmago-api-gateway 5000:80

DURATION="${1:-90}"
URL="${2:-http://127.0.0.1:5000/api/login}"
BATCH=30       # requests por oleada (evita fork bomb en Windows)
INTERVAL=3     # segundos entre oleadas
NS="pharmago"

echo "=== Chaos: trigger 5xx error rate alert ==="
echo "Paso 1: eliminando pod de DB para romper dependencia..."
kubectl delete pod -n "$NS" -l app=pharmago-db --grace-period=0 --force 2>/dev/null || true
echo "  Pod DB eliminado. Kubernetes lo recreara automaticamente (autohealing)."
echo "  Esperando 3s para que la terminacion se propague..."
sleep 3

echo "Paso 2: enviando requests en oleadas de $BATCH cada ${INTERVAL}s durante ${DURATION}s..."
elapsed=0
total=0
while [ $elapsed -lt $DURATION ]; do
  # Si la DB volvio, la eliminamos de nuevo para mantener la falla
  kubectl delete pod -n "$NS" -l app=pharmago-db --grace-period=0 --force 2>/dev/null || true

  i=0
  while [ $i -lt $BATCH ]; do
    curl -s -o /dev/null \
      -X POST "$URL" \
      -H "Content-Type: application/json" \
      -H "X-Correlation-ID: chaos-5xx-$(date +%s%3N)-$i" \
      -d '{"userName":"chaos_test","password":"trigger_5xx"}' &
    i=$((i+1))
  done
  wait
  total=$((total + BATCH))
  elapsed=$((elapsed + INTERVAL))
  echo "  ${elapsed}s / ${DURATION}s — $total requests enviados"
  sleep $INTERVAL
done

echo ""
echo "=== Resultado ==="
echo "  $total requests enviados en ${DURATION}s."
echo "  Verificar en Grafana la alerta '[PharmaGo] High 5xx Error Rate'."
echo "  El pod de DB se recreara solo. Seguir runbook RB-01 para el procedimiento completo."
