#!/bin/bash
set -euo pipefail

# Load sensitive configuration from .env
if [ -f ./terraform/.env ]; then
  source ./terraform/.env
else
  echo "❌ Missing .env file. Exiting."
  exit 1
fi

# Validate that all required environment variables are set
required_vars=(BW_SERVER BW_ITEM_NAME KEYCHAIN_CLIENT_ID_ITEM KEYCHAIN_CLIENT_SECRET_ITEM KEYCHAIN_MASTER_PASSWORD_ITEM)
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Required environment variable '$var' is not set in the .env file!"
    exit 1
  fi
done

echo "🔐 Retrieving sensitive credentials from macOS Keychain..."

# Use the item names from the .env file to fetch values from the macOS Keychain
export BW_CLIENTID=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_CLIENT_ID_ITEM" -w)
export BW_CLIENTSECRET=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_CLIENT_SECRET_ITEM" -w)
export BW_PASSWORD=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_MASTER_PASSWORD_ITEM" -w)

if [ -z "$BW_CLIENTID" ] || [ -z "$BW_CLIENTSECRET" ] || [ -z "$BW_PASSWORD" ]; then
  echo "❌ One or more sensitive credentials could not be retrieved from the macOS Keychain!"
  exit 1
fi

# Clear any existing Bitwarden session (critical!)
bw logout || true

# Configure Bitwarden CLI to use the custom server from .env
bw config server "$BW_SERVER"

# Log in to Bitwarden using API key credentials from the Keychain
bw login --apikey
echo "✅ Logged in to Bitwarden using API key!"

# Unlock the vault using the master password obtained from the Keychain
echo "🔓 Unlocking Bitwarden Vault..."
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
echo "✅ Bitwarden Vault unlocked!"

# Retrieve the Sealed Secrets private key from Bitwarden using the item name from .env
echo "🔍 Retrieving Sealed Secrets private key..."
SEALED_SECRET_KEY=$(bw get item "$BW_ITEM_NAME" --session "$BW_SESSION" | jq -r '.notes')

if [ -z "$SEALED_SECRET_KEY" ]; then
  echo "❌ Could not retrieve the Sealed Secrets private key from Bitwarden."
  exit 1
fi

# Apply the private key to Kubernetes
echo "⚙️ Importing Sealed Secrets private key into the cluster..."
echo "$SEALED_SECRET_KEY" | kubectl create --save-config -f -

# Clean up: log out from Bitwarden and unset sensitive environment variables
bw logout
unset BW_CLIENTID
unset BW_CLIENTSECRET
unset BW_PASSWORD
unset BW_SESSION

echo "✅ Sealed Secrets private key restored successfully!"
