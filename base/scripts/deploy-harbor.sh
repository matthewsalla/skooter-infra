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

echo "📡 Deploying Harbor.io"

# Create Namespace
kubectl create namespace harbor || true

echo "🔑 Import Harbor Secrets..."
kubectl apply -f "$SECRETS_PATH/harbor-master-secret-sealed-secret.yaml"

# Restore Persistent Volume from backup for Harbor.io
echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore harbor-postgres-db --wrapper
base/scripts/longhorn-automation.sh restore harbor-registry --wrapper
base/scripts/longhorn-automation.sh restore harbor-jobservice --wrapper
base/scripts/longhorn-automation.sh restore harbor-redis --wrapper
base/scripts/longhorn-automation.sh restore harbor-trivy --wrapper
echo "✅ Persistent Data Volume Restored!"

# echo "Deploying Harbor Volumes..."
helm dependency update "$HELM_CHARTS_PATH/harbor-volumes"
helm upgrade --install harbor-volumes "$HELM_CHARTS_PATH/harbor-volumes" \
  --namespace harbor \
  --values "$HELM_VALUES_PATH/harbor-volumes-values.yaml" \
  --values "$HELM_VALUES_PATH/harbor-postgres-db-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/harbor-registry-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/harbor-redis-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/harbor-jobservice-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/harbor-trivy-restored-volume.yaml"

# Deploy Harbor.io App
helm dependency update "$HELM_CHARTS_PATH/harbor"
helm upgrade --install harbor "$HELM_CHARTS_PATH/harbor" \
  --namespace harbor \
  --values "$HELM_VALUES_PATH/harbor-values.yaml"


echo "✅ Harbor.io Deployed Successfully!"
