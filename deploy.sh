#!/bin/bash
# Thin repo: deploy.sh

# Navigate to the base Terraform directory
cd base/terraform || exit
terraform init
cd ../.. || exit

source base/terraform/scripts/nuke-deploy-cluster.sh staging

# Step 1: Deploy Sealed Secrets
bash base/scripts/deploy-sealed-secrets.sh

# Step 2: Restore Sealed Secrets Key
# bash scripts/restore-sealed-secrets.sh

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
