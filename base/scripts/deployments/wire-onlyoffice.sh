#!/usr/bin/env bash
set -euo pipefail

# Load sensitive configuration from .env
if [ -f ./terraform/.env ]; then
  source ./terraform/.env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

# === CONFIG ===
NS="${NEXTCLOUD_NAMESPACE:-nextcloud}"
NEXTCLOUD_LABEL="${NEXTCLOUD_LABEL:-app.kubernetes.io/name=nextcloud}"
ONLYOFFICE_LABEL="${ONLYOFFICE_LABEL:-app=docservice}"
ONLYOFFICE_SECRET="${ONLYOFFICE_SECRET:-onlyoffice-creds}"

PUBLIC_URL="${ONLYOFFICE_PUBLIC_URL:-https://onlyoffice.example.com}"
INTERNAL_URL="${ONLYOFFICE_INTERNAL_URL:-http://documentserver}"
STORAGE_URL="${NEXTCLOUD_STORAGE_URL:-http://nextcloud:8080}"

POD=$(kubectl get pod -n "$NS" -l "$NEXTCLOUD_LABEL" -o jsonpath='{.items[0].metadata.name}')
JWT_SECRET=$(kubectl get secret "$ONLYOFFICE_SECRET" -n "$NS" -o jsonpath='{.data.JWT_SECRET}' | base64 --decode)

exec_occ() {
  kubectl exec -n "$NS" "$POD" -- su -s /bin/bash www-data -c "php occ $*"
}

wait_for_ready() {
  local label=$1
  local appname=$2
  echo "🔄 Waiting for $appname pod to become Ready..."
  until kubectl wait --for=condition=ready pod -n "$NS" -l "$label" --timeout=10s 2>/dev/null; do
    echo "⏳ Still waiting for $appname..."
    sleep 5
  done
}

wait_for_ready "$NEXTCLOUD_LABEL" "Nextcloud"
wait_for_ready "$ONLYOFFICE_LABEL" "OnlyOffice"

# === INSTALL ONLYOFFICE APP ===
exec_occ app:install onlyoffice || true
exec_occ app:enable onlyoffice

# === APPLY MINIMAL CONFIG ===
exec_occ config:app:set onlyoffice DocumentServerUrl --value="$PUBLIC_URL"
exec_occ config:app:set onlyoffice DocumentServerInternalUrl --value="$INTERNAL_URL"
exec_occ config:app:set onlyoffice StorageUrl --value="$STORAGE_URL"
exec_occ config:app:set onlyoffice jwt_secret --value="$JWT_SECRET" >/dev/null 2>&1
#exec_occ config:app:set onlyoffice jwt_secret --value="$JWT_SECRET"
