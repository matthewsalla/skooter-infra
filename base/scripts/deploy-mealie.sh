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

echo "📡 Deploying Mealie..."

# Create Namespace
kubectl create namespace mealie || true

# Restore Persistent Volume from backup for Mealie
echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore mealie
echo "✅ Persistent Data Volume Restored!"

# Deploy Mealie
helm dependency update "$HELM_CHARTS_PATH/mealie"
helm upgrade --install mealie "$HELM_CHARTS_PATH/mealie" \
  --namespace mealie \
  --values "$HELM_VALUES_PATH/mealie-values.yaml" \
  --values "$HELM_VALUES_PATH/mealie-restored-volume.yaml"

echo "✅ Mealie Deployed Successfully!"
