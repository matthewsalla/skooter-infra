#!/bin/bash
set -e

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

SECRET_NAME="sealed-secrets-key"
NAMESPACE="kube-system"
DAYS_VALID=3650

echo "🔐 Generating private key..."
openssl genrsa -out tls.key 4096

echo "📜 Generating self-signed certificate..."
openssl req -x509 -new -nodes -key tls.key -sha256 -days $DAYS_VALID \
  -subj "/CN=sealed-secret/O=sealed-secret" \
  -out tls.crt

echo "📄 Saving PEM-formatted public certificate for kubeseal..."
cp tls.crt sealed-secret-controller-cert.pem

echo "📦 Creating and applying labeled TLS secret directly..."
kubectl create secret tls "$SECRET_NAME" \
  --cert=tls.crt \
  --key=tls.key \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml |
  kubectl label --local -f - \
    sealedsecrets.bitnami.com/sealed-secrets-key=active \
    --dry-run=client -o yaml |
  kubectl apply -f -

echo "📂 Copying public certificate to \$SECRETS_PATH..."
mkdir -p "$SECRETS_PATH"
cp sealed-secret-controller-cert.pem "$SECRETS_PATH/"

echo "🧹 Cleaning up intermediate files..."
rm -f tls.key tls.crt sealed-secret-controller-cert.pem

echo "✅ Secret applied and public certificate copied to \$SECRETS_PATH."
