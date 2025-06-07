#!/usr/bin/env bash
set -euo pipefail

# default to "staging" if DEPLOYMENT_MODE is not set
: "${DEPLOYMENT_MODE:=staging}"

# Determine script dir & load config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if   [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
elif [ -f "$SCRIPT_DIR/../../../scripts/config.sh" ]; then
  source "$SCRIPT_DIR/../../../scripts/config.sh"
else
  echo "Missing config.sh file. Exiting." >&2
  exit 1
fi

echo "📡 Deploying OnlyOffice Document Server"

# 1️⃣ Create namespace
kubectl create namespace nextcloud 2>/dev/null || true

# 2️⃣ Import Secrets & Middlewares
echo "🔑 Importing OnlyOffice JWT secret..."
kubectl apply -f "$SECRETS_PATH/onlyoffice-creds-sealed-secret.yaml"

echo "🔑 Importing OnlyOffice Middleware for headers..."
kubectl apply -f "$MIDDLEWARES_PATH/onlyoffice-secure-headers.yaml"

# 3️⃣ Restore Volumes via Longhorn
echo "🔐 Restoring OnlyOffice volumes..."
base/scripts/longhorn-automation.sh restore onlyoffice-files   --wrapper
base/scripts/longhorn-automation.sh restore onlyoffice-postgres-db   --wrapper
echo "✅ OnlyOffice volumes restored!"

# 4️⃣ Choose prod vs. staging
if [[ "$DEPLOYMENT_MODE" == "prod" ]]; then
  echo "🚀 Using Production values..."
  VALUES_FILE="$HELM_VALUES_PATH/prod/onlyoffice/onlyoffice-values.yaml"
  VOLS_FILE="$HELM_VALUES_PATH/prod/onlyoffice/onlyoffice-volumes-values.yaml"
  BACKEND_FILE="$HELM_VALUES_PATH/prod/onlyoffice/onlyoffice-backend-values.yaml"
else
  echo "⚠️  Using Staging values..."
  VALUES_FILE="$HELM_VALUES_PATH/staging/onlyoffice/onlyoffice-values.yaml"
  VOLS_FILE="$HELM_VALUES_PATH/staging/onlyoffice/onlyoffice-volumes-values.yaml"
  BACKEND_FILE="$HELM_VALUES_PATH/staging/onlyoffice/onlyoffice-backend-values.yaml"
fi

# 5️⃣ Deploy volumes subchart
echo "📦 Deploying OnlyOffice-volumes chart..."
helm dependency update "$HELM_CHARTS_PATH/onlyoffice/volumes"
helm upgrade --install onlyoffice-volumes "$HELM_CHARTS_PATH/onlyoffice/volumes" \
  --namespace nextcloud \
  --values "$VOLS_FILE" \
  --values "$HELM_VALUES_PATH/onlyoffice-files-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/onlyoffice-postgres-db-restored-volume.yaml" \

# 5️⃣ Deploy backend subchart
echo "📦 Deploying OnlyOffice-backend chart..."
helm dependency update "$HELM_CHARTS_PATH/onlyoffice/backend"
helm upgrade --install onlyoffice-backend "$HELM_CHARTS_PATH/onlyoffice/backend" \
  --namespace nextcloud \
  --values "$BACKEND_FILE" \

# 6️⃣ Deploy the Document Server chart
echo "📦 Deploying OnlyOffice DocumentServer chart..."
helm dependency update "$HELM_CHARTS_PATH/onlyoffice/app"
helm upgrade --install onlyoffice "$HELM_CHARTS_PATH/onlyoffice/app" \
  --namespace nextcloud \
  --values "$VALUES_FILE"
echo "✓ OnlyOffice chart deployed"

# 7️⃣ Wire into Nextcloud
echo "🔧 Configuring Nextcloud to use OnlyOffice..."
bash base/scripts/deployments/wire-onlyoffice.sh
echo "✓ Nextcloud configured with OnlyOffice"

# echo "✅ OnlyOffice deployed and wired into Nextcloud!"
