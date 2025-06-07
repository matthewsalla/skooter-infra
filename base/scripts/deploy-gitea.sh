#!/bin/bash
set -euo pipefail

# -----------------------------------------
# Load configuration
# -----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
else
  if [ -f "$SCRIPT_DIR/../../scripts/config.sh" ]; then
    source "$SCRIPT_DIR/../../scripts/config.sh"
  else
    echo "Missing config.sh file. Exiting."
    exit 1
  fi
fi

if [ -f ./terraform/.env ]; then
  source ./terraform/.env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

# -----------------------------------------
# Deploy Gitea
# -----------------------------------------
echo "📡 Deploying Gitea..."

kubectl create namespace gitea || true

echo "🏷️  Labeling node for Gitea..."
kubectl label node ${GITEA_NODE_NAME} dedicated=gitea --overwrite

# -----------------------------------------
# Conditionally Restore Postgres Volume
# -----------------------------------------
if [[ "${ENABLE_GITEA_POSTGRES_RESTORE:-false}" == "true" ]]; then
  echo "📦 Restoring Gitea PostgreSQL Volume..."
  base/scripts/longhorn-automation.sh restore gitea-postgres-db --wrapper

  echo "💾 Including PostgreSQL volume values in Helm release..."
  POSTGRES_RESTORE_VALUES="--values $HELM_VALUES_PATH/gitea-postgres-db-restored-volume.yaml"
else
  echo "⏩ Skipping PostgreSQL restore and volume config."
  POSTGRES_RESTORE_VALUES=""
fi

echo "🔐 Restoring Data Volume..."
base/scripts/longhorn-automation.sh restore gitea
base/scripts/longhorn-automation.sh restore gitea-actions-docker --wrapper
echo "✅ Persistent Data Volume Restored!"

echo "Deploying Gitea Volumes..."
helm dependency update "$HELM_CHARTS_PATH/gitea-volumes"
helm upgrade --install gitea-volumes "$HELM_CHARTS_PATH/gitea-volumes" \
  --namespace gitea \
  --values "$HELM_VALUES_PATH/gitea-volumes-values.yaml" \
  --values "$HELM_VALUES_PATH/gitea-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/gitea-actions-docker-restored-volume.yaml" \
  $POSTGRES_RESTORE_VALUES

echo "Deploying Gitea via Helm..."
helm dependency update "$HELM_CHARTS_PATH/gitea"
helm upgrade --install gitea "$HELM_CHARTS_PATH/gitea" \
  --namespace gitea \
  --values "$HELM_VALUES_PATH/gitea-values.yaml"

# -----------------------------------------
# Wait for Gitea Pod to be Ready
# -----------------------------------------
echo "⏳ Waiting for a Gitea pod to become Ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=gitea -n gitea --timeout=300s

# Retrieve the name of one ready Gitea pod
GITEA_POD=$(kubectl get pods -n gitea -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}')
if [ -z "$GITEA_POD" ]; then
  echo "Error: Could not find a ready Gitea pod in the gitea namespace."
  exit 1
fi
echo "Using Gitea pod: $GITEA_POD"

# -----------------------------------------
# Retrieve Runner Token from Gitea Pod
# -----------------------------------------
echo "Retrieving Gitea Actions Runner Token from pod '$GITEA_POD'..."
TOKEN=$(kubectl exec -n gitea "$GITEA_POD" -- gitea actions generate-runner-token)
if [ -z "$TOKEN" ]; then
  echo "Error: Runner token is empty. Verify that 'gitea actions generate-runner-token' runs correctly."
  exit 1
fi
echo "Runner token retrieved."

# -----------------------------------------
# Generate Sealed Secret for Runner Token
# -----------------------------------------
echo "Generating sealed secret for Gitea Actions Token..."
# Assumes generate-sealed-secret.sh is in the same directory as this script.
SEAL_SCRIPT="$SCRIPT_DIR/generate-sealed-secret.sh"
if [ ! -x "$SEAL_SCRIPT" ]; then
  echo "Error: Sealed secret generation script not found or not executable at $SEAL_SCRIPT."
  exit 1
fi

# Call the sealed secret generator with usage: <namespace> <secret-name> <key=value> ...
# Here the secret is named "gitea-actions-token" and the key is "token".
"$SEAL_SCRIPT" gitea gitea-actions-token token="$TOKEN"

# -----------------------------------------
# Import the Sealed Secret into the Cluster
# -----------------------------------------
echo "Importing Gitea Actions Token sealed secret..."
kubectl apply -f "$SECRETS_PATH/gitea-actions-token-sealed-secret.yaml"
echo "Gitea Actions Token Imported Successfully!"

echo "✅ Gitea Deployed Successfully!"
