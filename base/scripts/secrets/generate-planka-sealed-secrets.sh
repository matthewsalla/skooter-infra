#!/usr/bin/env bash
set -euo pipefail

# 🔍 Check for required tools
required_tools=("tr" "head" "bash")
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ Required tool '$tool' is not installed or not in PATH."
    exit 1
  fi
done

# 🧪 Check that the sealed secret generator script exists
sealed_secret_script="base/scripts/generate-sealed-secret.sh"
if [[ ! -x "$sealed_secret_script" ]]; then
  echo "❌ Required script '$sealed_secret_script' not found or not executable."
  exit 1
fi

# 🔐 Function to generate a random alphanumeric string of a given length
generate_random() {
  local length=$1
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "$length" || true
}

# 📁 Define output file
output_file="./secrets/helm_credentials_planka.txt"
mkdir -p "$(dirname "$output_file")"
> "$output_file"

# 🧬 Generate Planka credentials
admin_username="planka_admin"
admin_password=$(generate_random 24)
secretkey=$(generate_random 64)

db_username="planka"
db_password=$(generate_random 24)
postgres_password=$(generate_random 24)
replication_password=$(generate_random 24)

# 🧾 Write all into one sealed secret definition
# Format: <app> <secret-name> key1=val1 key2=val2 ...
echo "planka planka-creds username=${admin_username} password=${admin_password} key=${secretkey} db-username=${db_username} db-password=${db_password} postgres-password=${postgres_password} replication-password=${replication_password}" >> "$output_file"

# 🔁 Generate the sealed secret
echo "🔐 Generating sealed secret for Planka..."
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash "$sealed_secret_script" $line
done < "$output_file"

echo
echo "✅ Planka sealed secret generated! Update your Helm values to reference:"
echo "  planka.existingAdminCredsSecret: planka-creds"
echo "  planka.existingSecretkeySecret: planka-creds"
echo "  planka.postgresql.auth.existingSecret: planka-creds"
echo "  planka.postgresql.auth.secretKeys:"
echo "    username: db-username"
echo "    password: db-password"
echo "    postgresPassword: postgres-password"
echo "    replicationPassword: replication-password"
