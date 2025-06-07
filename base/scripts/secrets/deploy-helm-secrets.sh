#!/bin/bash
# Script: deploy-helm-secrets.sh
# Purpose: Deploy sealed secrets for Helm-based app deployments.

set -euo pipefail

# Paths & variables
PEM_FILE="secrets/sealed-secret-controller-cert.pem"
HELM_CREDENTIALS="secrets/helm_credentials.txt"
GENERATE_SECRET_SCRIPT="base/scripts/generate-sealed-secret.sh"

# Ensure PEM file is present
if [ ! -f "$PEM_FILE" ]; then
  echo "❌ PEM file not found at $PEM_FILE. Please generate or restore the sealed secrets key first."
  exit 1
fi

# Ensure the credentials file exists
if [ ! -f "$HELM_CREDENTIALS" ]; then
  echo "❌ Credentials file not found: $HELM_CREDENTIALS"
  exit 1
fi

echo "🔐 Applying sealed secrets for app deployments..."

# Loop through each line
while IFS= read -r line || [ -n "$line" ]; do
  # Skip comments and empty lines
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue

  echo "Processing sealed secret for: $line"
  # Use eval and `bash -c` to split args correctly while preserving quoted values
  bash -c "$GENERATE_SECRET_SCRIPT $line"
done < "$HELM_CREDENTIALS"

echo "✅ All app-related sealed secrets applied!"
