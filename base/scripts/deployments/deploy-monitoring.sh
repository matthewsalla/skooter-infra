#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source the configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
else
  # Fallback: Try to source config from the thin repo if available
  if [ -f "$SCRIPT_DIR/../../../scripts/config.sh" ]; then
    source "$SCRIPT_DIR/../../../scripts/config.sh"
  else
    echo "Missing config.sh file. Exiting."
    exit 1
  fi
fi

echo "📡 Deploying Monitoring Stack..."

# Create Namespace
kubectl create namespace monitoring || true

echo "🔐 Restoring Data Volume..."
base/scripts//longhorn-automation.sh restore grafana
echo "✅ Persistent Data Volume Restored!"

echo "🔑 Import Grafana Secrets..."
kubectl apply -f "$SECRETS_PATH/grafana-admin-credentials-sealed-secret.yaml"

# Deploy Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$HELM_VALUES_PATH/prometheus-values.yaml"

# Deploy Staging or Prod
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀 Deploying Production..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/grafana-values.yaml"
else
  echo "⚠️  Deploying Staging..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/grafana-values.yaml"
fi

# Deploy Grafana
helm dependency update "$HELM_CHARTS_PATH/monitoring/grafana"
helm upgrade --install grafana "$HELM_CHARTS_PATH/monitoring/grafana" \
    --namespace monitoring \
    --values "$VALUES_FILE" \
    --values "$HELM_VALUES_PATH/grafana-restored-volume.yaml"

echo "✅ Monitoring Stack Deployed Successfully!"
