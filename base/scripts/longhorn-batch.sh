#!/bin/bash
# Script: longhorn-batch.sh
# Purpose: Execute any longhorn-automation.sh commands listed in a file

set -euo pipefail

COMMANDS_FILE="./longhorn-backup-commands.txt"

if [ ! -f "$COMMANDS_FILE" ]; then
  echo "❌ Commands file not found: $COMMANDS_FILE"
  exit 1
fi

echo "🚀 Executing longhorn-automation.sh batch commands..."
echo "📄 Reading from: $COMMANDS_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue  # Skip comment lines
  [[ -z "$line" ]] && continue        # Skip blank lines

  echo "▶️  Running: $line"
  eval "$line"
done < "$COMMANDS_FILE"

echo "✅ All longhorn automation commands completed."
