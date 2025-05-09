#!/bin/bash
set -euo pipefail

HOST="192.168.14.231"

# record start time
start_time=$(date +%s)

echo "🚀 Running prep-server script (this may reboot the host)..."
bash scripts/prep-server.sh

echo "🔄 Waiting for $HOST to go offline..."
until ! ping -c1 -W1 "$HOST" &>/dev/null; do
  sleep 2
done
echo "⚠️  $HOST is now offline (reboot in progress)."

echo "🔁 Waiting for $HOST to come back online..."
until ping -c1 -W1 "$HOST" &>/dev/null; do
  sleep 2
done
echo "✅ $HOST is back online!"

# small buffer before next steps
sleep 5

echo "▶️  Proceeding with deployment..."
bash deploy.sh

# record end time and compute elapsed
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo "⏱ Total elapsed time: ${minutes}m ${seconds}s"
