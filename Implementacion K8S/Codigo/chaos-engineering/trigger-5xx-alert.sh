#!/bin/sh
# Chaos: genera errores 5xx eliminando el pod de base de datos y enviando requests.
# Activa la alerta "[PharmaGo] High 5xx Error Rate" en Grafana.
# Uso: ./trigger-5xx-alert.sh [cantidad_requests] [gateway_url]
# Requiere port-forward activo: kubectl port-forward -n pharmago svc/pharmago-api-gateway 5000:80

N="${1:-300}"
URL="${2:-http://127.0.0.1:5000/api/login}"
NS="pharmago"

echo "=== Chaos: trigger 5xx error rate alert ==="
echo "Paso 1: eliminando pod de DB para romper dependencia..."
kubectl delete pod -n "$NS" -l app=pharmago-db --grace-period=0 --force 2>/dev/null || true
echo "  Pod DB eliminado. Kubernetes lo recreara automaticamente (autohealing)."

echo "Paso 2: enviando $N requests al gateway mientras DB esta caida..."
i=0
while [ $i -lt $N ]; do
  curl -s -o /dev/null \
    -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: chaos-5xx-$(date +%s%3N)-$i" \
    -d '{"userName":"chaos_test","password":"trigger_5xx"}' &
  i=$((i+1))
done
wait

echo ""
echo "=== Resultado ==="
echo "  $N requests enviados. Verificar en Grafana la alerta '[PharmaGo] High 5xx Error Rate'."
echo "  Si la alerta no dispara, aumentar N o reducir el umbral en grafana-alerting.yaml."
echo "  El pod de DB se recreara solo. Seguir runbook RB-01 para el procedimiento completo."
