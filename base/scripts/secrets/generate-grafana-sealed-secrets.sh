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
output_file="./secrets/helm_credentials.txt"
mkdir -p "$(dirname "$output_file")"
> "$output_file"

# 🧬 Generate Grafana admin credentials
admin_user="admin"
admin_password=$(generate_random 22)

# 🧾 Write credentials into one sealed secret definition
# Format: <app> <secret-name> key1=value1 key2=value2 …
echo "monitoring grafana-admin-credentials admin-user=${admin_user} admin-password=${admin_password}" \
  >> "$output_file"

# 🔁 Convert the generated secret into a SealedSecret
echo "🔐 Generating sealed secret for Grafana…"
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash "$sealed_secret_script" $line
done < "$output_file"

echo
echo "✅ Grafana sealed secret applied! Now update your Helm values to reference:"
echo "    admin.existingSecret:      grafana-admin-credentials"
echo "    admin.existingSecretKey:   admin-password"
