#!/bin/bash

# Define common paths for all scripts
export SECRETS_PATH="./secrets"
export MANIFESTS_PATH="./kubernetes/manifests"
export MIDDLEWARES_PATH="./base/kubernetes/manifests/middlewares"
export HELM_VALUES_PATH="./helm"
export HELM_CHARTS_PATH="./base/helm-charts"

# Default values for environment variables
export CERT_ISSUER=${CERT_ISSUER:-letsencrypt-staging}

echo "🔧 Using ClusterIssuer: $CERT_ISSUER"
