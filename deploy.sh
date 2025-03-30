#!/bin/bash
# Thin repo: deploy.sh

# Navigate to the base Terraform directory
cd base/terraform || exit
terraform init
cd ../.. || exit

source base/terraform/scripts/nuke-deploy-cluster.sh staging

# Step 1: Handle Sealed Secrets (restore or deploy)
PEM_FILE="secrets/sealed-secret-controller-cert.pem"

if [ -f "$PEM_FILE" ]; then
  echo "🔁 Existing PEM found at $PEM_FILE. Restoring Sealed Secrets key..."
  bash scripts/restore-sealed-secrets.sh
else
  echo "🔐 No PEM file found. Generating Sealed Secrets key..."
  bash base/scripts/generate-sealed-secrets-key.sh
fi

echo "🚀 Deploying Sealed Secrets..."
bash base/scripts/deploy-sealed-secrets.sh

# Step 2: Deploy sealed secrets used by Helm-based apps
echo "🔐 Applying sealed secrets for app deployments..."
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash base/scripts/generate-sealed-secret.sh $line
# TODO: Store helm_credentials in bitwarden
done < ./secrets/helm_credentials.txt
echo "✅ All app-related sealed secrets applied!"

# Step 3: Deploy Cert-Manager
bash base/scripts/deploy-cert-manager.sh

# Step 4: Deploy Traefik v3
bash base/scripts/deploy-traefik.sh

# Step 5: Deploy Longhorn
# bash base/scripts/deploy-longhorn.sh

# Step 6: Deploy Monitoring Tools
# bash base/scripts/deploy-monitoring.sh

# Step X: Deploy TriliumNext
# bash base/scripts/deploy-trilium.sh

# Step X: Deploy Mealie
# bash base/scripts/deploy-mealie.sh

# Step X: Deploy Gitea
# bash base/scripts/deploy-gitea.sh

echo "✅ Deployment Completed Successfully!"
