#!/bin/bash
# Thin repo: deploy.sh

# record start time
start_time=$(date +%s)

# ————————————————————————————————————————————————
# 1. Navigate to your base Terraform module
# ————————————————————————————————————————————————
cd base/terraform || exit

# ————————————————————————————————————————————————
# 2. Init Terraform with MinIO S3 backend
#    -backend-config points at your backend.hcl
#    -reconfigure forces Terraform to pick up the new backend
# ————————————————————————————————————————————————
terraform init \
  -backend-config="../../terraform/backend.hcl" \
  -reconfigure

# ————————————————————————————————————————————————
# 3. Return to repo root
# ————————————————————————————————————————————————
cd ../.. || exit

source base/terraform/scripts/nuke-deploy-cluster.sh staging --yes

# Step 1: Handle Sealed Secrets (restore or deploy)
PEM_FILE="secrets/sealed-secret-controller-cert.pem"
SKIP_HELM_SECRETS=false

if [ -f "$PEM_FILE" ]; then
  echo "🔁 Existing PEM found at $PEM_FILE. Restoring Sealed Secrets key..."
  bash base/scripts/secrets/restore-cluster-key-keychain-bw-workflow.sh
  SKIP_HELM_SECRETS=true
else
  echo "🔐 No PEM file found. Generating Sealed Secrets key..."
  bash base/scripts/generate-sealed-secrets-key.sh
fi

echo "🚀 Deploying Sealed Secrets..."
bash base/scripts/deploy-sealed-secrets.sh

# Step 2: Deploy sealed secrets used by Helm-based apps
if [ "$SKIP_HELM_SECRETS" = false ]; then
  echo "🔐 Applying sealed secrets for app deployments..."
  bash base/scripts/secrets/apply-helm-secrets.sh
  echo "✅ All app-related sealed secrets applied!"
else
  echo "🔁 Skipping Helm-based app sealed secrets deployment because PEM file existed."
fi

# Step 3: Deploy Cert-Manager
bash base/scripts/deploy-cert-manager.sh

# Step 4: Deploy Traefik v3
bash base/scripts/deploy-traefik.sh

# Step 5: Deploy Longhorn
bash base/scripts/deployments/deploy-longhorn.sh

# Step 6: Deploy Monitoring Tools
# bash base/scripts/deployments/deploy-monitoring.sh

# Step X: Deploy TriliumNext
# bash base/scripts/deploy-trilium.sh

# Step X: Deploy Mealie
# bash base/scripts/deploy-mealie.sh

# Step X: Deploy Gitea
# bash base/scripts/deploy-gitea.sh

# Step X: Deploy Nextcloud
bash base/scripts/deployments/deploy-nextcloud.sh

# Step X: Deploy OnlyOffice
bash base/scripts/deployments/deploy-nextcloud-onlyoffice.sh

# Step X: Deploy draw.io
bash base/scripts/deployments/deploy-nextcloud-drawio.sh

echo "✅ Deployment Completed Successfully!"

# record end time and compute elapsed
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo "⏱ Total elapsed time: ${minutes}m ${seconds}s"
