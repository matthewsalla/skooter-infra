#!/bin/bash
exec > >(tee -a ~/prep-server.log) 2>&1
set -euo pipefail
set -x

# === Configurable Variables ===
USERNAME="${1:-ubuntu}"
HOST="${2:-192.168.1.222}"
PUBKEY_PATH="${PUBKEY_PATH:-$HOME/.ssh/id_rsa.pub}"
SCRIPT_PATH="${SCRIPT_PATH:-scripts/transmigrate-ubuntu-server.sh}"
REMOTE_SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

# === Copy SSH key ===
echo "🔑 Copying SSH key to $USERNAME@$HOST..."
ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PUBKEY_PATH" "$USERNAME@$HOST"

# === Copy script to remote host ===
echo "📦 Copying script to $USERNAME@$HOST..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SCRIPT_PATH" "$USERNAME@$HOST:~/"

# === Remotely set permissions and run the script ===
echo "🚀 Executing remote commands on $HOST..."
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USERNAME@$HOST" "chmod +x ~/$REMOTE_SCRIPT_NAME && echo '🚀 Running script with sudo...' && sudo -E bash ~/$REMOTE_SCRIPT_NAME"
