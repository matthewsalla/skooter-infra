#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source the configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
else
  # Fallback: Try to source config from the thin repo if available
  if [ -f "$SCRIPT_DIR/../../scripts/config.sh" ]; then
    source "$SCRIPT_DIR/../../scripts/config.sh"
  else
    echo "Missing config.sh file. Exiting."
    exit 1
  fi
fi

echo "Deploying Cert Manager"

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --values "$HELM_VALUES_PATH/cert-manager-values.yaml" \
  --set global.leaderElection.namespace=cert-manager

echo "Cert Manager deployed!"

echo "🔑 Import CloudFlare api key"
kubectl apply -f "$SECRETS_PATH/cert-manager-cloudflare-api-credentials-sealed-secret.yaml"
echo "🎯 Key successfully imported!"

# Deploy correct ClusterIssuer based on DEPLOYMENT_MODE
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀 Deploying Let's Encrypt Production ClusterIssuer..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/cert-manager-clusterissuer-values.yaml"
else
  echo "⚠️  Deploying Let's Encrypt Staging ClusterIssuer..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/cert-manager-clusterissuer-values.yaml"
fi

helm dependency update "$HELM_CHARTS_PATH/clusterissuer-chart"
helm upgrade --install clusterissuer-chart "$HELM_CHARTS_PATH/clusterissuer-chart" \
  --namespace cert-manager \
  --values "$VALUES_FILE"

echo "🎉 Cluster Issuer deployed successfully!"
