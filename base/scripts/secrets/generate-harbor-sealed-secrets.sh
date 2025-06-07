#!/bin/bash

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

# 🧬 Generate credentials
admin_password=$(generate_random 16)
encryption_secret=$(generate_random 16)
registry_password=$(generate_random 16)

# 🧾 Write credentials into one sealed secret definition
echo "harbor harbor-master-secret HARBOR_ADMIN_PASSWORD=${admin_password} secretKey=${encryption_secret} REGISTRY_PASSWD=${registry_password} REGISTRY_HTPASSWD=$(htpasswd -nbB harbor_registry_user ${registry_password} | sed 's/\\$/\\\\$/g')" >> "$output_file"

# 🔁 Convert the generated secret into a SealedSecret
echo "🔐 Generating sealed secret for Harbor..."
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash "$sealed_secret_script" $line
done < "$output_file"

echo "✅ Harbor sealed secrets applied! Now update your Helm values to reference:"
echo "  existingSecretAdminPassword: harbor-master-secret"
echo "  existingSecretSecretKey: harbor-master-secret"
echo "  registry.credentials.existingSecret: harbor-master-secret"
