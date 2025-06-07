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

echo "📡 Deploying Trilium..."

# Create Namespace
kubectl create namespace trilium || true

# Restore Persistent Volume from backup for Trilium
echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore trilium
echo "✅ Persistent Data Volume Restored!"

# Deploy Trilium
helm dependency update "$HELM_CHARTS_PATH/trilium"
helm upgrade --install trilium "$HELM_CHARTS_PATH/trilium" \
  --namespace trilium \
  --values "$HELM_VALUES_PATH/trilium-values.yaml" \
  --values "$HELM_VALUES_PATH/trilium-restored-volume.yaml"

echo "✅ Trilium Deployed Successfully!"
