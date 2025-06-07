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

echo "📡 Deploying Planka"

# Create Namespace
kubectl create namespace planka || true

echo "🔑 Import Secrets..."
kubectl apply -f "$SECRETS_PATH/planka-creds-sealed-secret.yaml"

# Restore Persistent Volume from backup
echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore planka-data --wrapper
base/scripts/longhorn-automation.sh restore planka-postgres-db --wrapper
echo "✅ Persistent Data Volume Restored!"

# Deploy correct ClusterIssuer based on DEPLOYMENT_MODE
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀 Deploying Production..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/planka/planka-values.yaml"
  VOLUMES_VALUES_FILE="$HELM_VALUES_PATH/prod/planka/planka-volumes-values.yaml"
else
  echo "⚠️  Deploying Staging..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/planka/planka-values.yaml"
  VOLUMES_VALUES_FILE="$HELM_VALUES_PATH/staging/planka/planka-volumes-values.yaml"
fi

echo "Deploying App Volumes..."
helm dependency update "$HELM_CHARTS_PATH/planka/volumes"
helm upgrade --install planka-volumes "$HELM_CHARTS_PATH/planka/volumes" \
  --namespace planka \
  --values "$VOLUMES_VALUES_FILE" \
  --values "$HELM_VALUES_PATH/planka-data-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/planka-postgres-db-restored-volume.yaml" \

# Deploy App
helm dependency update "$HELM_CHARTS_PATH/planka/app"
helm upgrade --install planka "$HELM_CHARTS_PATH/planka/app" \
  --namespace planka \
  --values "$VALUES_FILE"

echo "✅ planka Deployed Successfully!"
