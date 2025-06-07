#!/usr/bin/env bash
set -euo pipefail

# 🔍 Check for required tools
required_tools=("tr" "head" "openssl" "bash")
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
output_file="./secrets/longhorn_auth_credentials.txt"
mkdir -p "$(dirname "$output_file")"
> "$output_file"

# 🧬 Generate Longhorn HTTP Basic Auth credentials
username="longhorn"
password=$(generate_random 24)
htpasswd_entry=$(echo "$password" | openssl passwd -apr1 -stdin)
auth_string="${username}:${htpasswd_entry}"

# 🧾 Write credential string for sealed secret generation
echo "longhorn-system longhorn-auth users=${auth_string}" >> "$output_file"

# 🔁 Convert the generated secret into a SealedSecret
echo "🔐 Generating sealed secret for Longhorn..."
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash "$sealed_secret_script" $line
done < "$output_file"

echo
echo "✅ Longhorn htpasswd sealed secret generated!"
echo
echo "🌐 Use the following login credentials to access Longhorn via browser:"
echo
echo "   🔑 Username: $username"
echo "   🔒 Password: $password"
echo
echo "📌 Update your Ingress middleware to reference the sealed secret:"
echo "   name: longhorn-auth"
echo "   namespace: longhorn-system"
