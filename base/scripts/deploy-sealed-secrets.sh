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

echo "Deploying Sealed Secrets..."
kubectl create namespace kube-system || true

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Deploy using the preconfigured secret "sealed-secrets-key"
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set existingSecret=sealed-secrets-key

echo "🎉 Sealed Secrets deployed using preconfigured secret 'sealed-secrets-key'!"
