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

POD=$(kubectl get pod -n "$NS" -l "$NEXTCLOUD_LABEL" -o jsonpath='{.items[0].metadata.name}')

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

# === Wait for Nextcloud pod ===
wait_for_ready "$NEXTCLOUD_LABEL" "Nextcloud"

# === INSTALL & ENABLE draw.io ===
exec_occ app:install drawio || true
exec_occ app:enable drawio
