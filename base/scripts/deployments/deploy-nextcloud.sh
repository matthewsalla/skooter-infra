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

echo "📡 Deploying Nextcloud"

# Create Namespace
kubectl create namespace nextcloud || true

echo "🔑 Import Secrets..."
kubectl apply -f "$SECRETS_PATH/nextcloud-creds-sealed-secret.yaml"

# Restore Persistent Volume from backup
echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore nextcloud-data --wrapper
base/scripts/longhorn-automation.sh restore nextcloud-config --wrapper
base/scripts/longhorn-automation.sh restore nextcloud-postgres-db --wrapper
# base/scripts/longhorn-automation.sh restore nextcloud-redis --wrapper
echo "✅ Persistent Data Volume Restored!"

# Deploy correct ClusterIssuer based on DEPLOYMENT_MODE
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀 Deploying Production..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/nextcloud/nextcloud-values.yaml"
  VOLUMES_VALUES_FILE="$HELM_VALUES_PATH/prod/nextcloud/nextcloud-volumes-values.yaml"
else
  echo "⚠️  Deploying Staging..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/nextcloud/nextcloud-values.yaml"
  VOLUMES_VALUES_FILE="$HELM_VALUES_PATH/staging/nextcloud/nextcloud-volumes-values.yaml"
fi

echo "Deploying App Volumes..."
helm dependency update "$HELM_CHARTS_PATH/nextcloud/volumes"
helm upgrade --install nextcloud-volumes "$HELM_CHARTS_PATH/nextcloud/volumes" \
  --namespace nextcloud \
  --values "$VOLUMES_VALUES_FILE" \
  --values "$HELM_VALUES_PATH/nextcloud-data-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/nextcloud-config-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/nextcloud-postgres-db-restored-volume.yaml" \
#   --values "$HELM_VALUES_PATH/nextcloud-redis-restored-volume.yaml"

# Deploy App
helm dependency update "$HELM_CHARTS_PATH/nextcloud/app"
helm upgrade --install nextcloud "$HELM_CHARTS_PATH/nextcloud/app" \
  --namespace nextcloud \
  --values "$VALUES_FILE"

echo "✅ Nextcloud Deployed Successfully!"
