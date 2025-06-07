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

echo "🚀 Deploying Traefik"

# Deploy based on DEPLOYMENT_MODE
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀  Deploying Traefik w/ Production ClusterIssuer..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/traefik-values.yaml"
else
  echo "⚠️  Deploying Traefik w/ Staging ClusterIssuer..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/traefik-values.yaml"
fi

helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --values "$VALUES_FILE" \
  --set certIssuer=$CERT_ISSUER

echo "✅ Traefik deployed using $CERT_ISSUER!"

echo "Importing CloudFlare API Key"
kubectl apply -f "$SECRETS_PATH/traefik-cloudflare-api-credentials-sealed-secret.yaml"
echo "CloudFlare API Key Imported Successfully!"

echo "Adding Traefik Middleware"
kubectl apply -f "$MIDDLEWARES_PATH/hsts-middleware.yaml"
echo "Done deploying Traefik Middleware!"

echo "Restarting Traefik now..."
kubectl rollout restart deployment traefik -n traefik
echo "Traefik has been restarted!"

for i in {15..1}; do
  echo "⏳ Waiting... $i seconds left"
  sleep 1
done

echo "Done!"