#!/bin/bash

USERNAME="ubuntu"
HOST="192.168.1.222"
PUBKEY_PATH="$HOME/.ssh/id_rsa.pub"
SCRIPT_PATH="scripts/transmigrate-ubuntu-server.sh"

# Copy SSH key
ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PUBKEY_PATH" "$USERNAME@$HOST"

# Copy script
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SCRIPT_PATH" "$USERNAME@$HOST:~/"

# Remotely set permissions and run the script
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USERNAME@$HOST" <<EOF
  chmod +x transmigrate-ubuntu-server.sh
  sudo bash ./transmigrate-ubuntu-server.sh
EOF
