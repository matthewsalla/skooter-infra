#!/usr/bin/env bash
set -euo pipefail

# 🔍 Check for required tools
required_tools=("tr" "head" "bash" "htpasswd")
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

# 🧬 Generate OnlyOffice credentials
postgres_password=$(generate_random 22)
redis_password=$(generate_random 22)
rabbitmq_password=$(generate_random 22)
erlang_cookie=$(generate_random 20)
jwt_secret=$(generate_random 44)

amqp_uri="amqp://onlyoffice:${rabbitmq_password}@onlyoffice-backend-rabbitmq:5672/?frameMax=0"

# 🧾 Write credentials into one sealed secret definition
echo "nextcloud onlyoffice-creds postgres-password=${postgres_password} redis-password=${redis_password} erlang-cookie=${erlang_cookie} rabbitmq-password=${rabbitmq_password} amqp-uri=${amqp_uri} JWT_ENABLED=true JWT_HEADER=Authorization JWT_IN_BODY=false JWT_SECRET=${jwt_secret}" >> "$output_file"

# 🔁 Convert the generated secret into a SealedSecret
echo "🔐 Generating sealed secret for OnlyOffice..."
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  bash "$sealed_secret_script" $line
done < "$output_file"

echo
echo "✅ OnlyOffice sealed secrets generated! Update your Helm values to reference:"
echo "  postgres:  existingSecret: onlyoffice-creds  -> postgres-password"
echo "  redis:     existingSecret: onlyoffice-creds  -> redis-password"
echo "  rabbitmq:  existingPasswordSecret: onlyoffice-creds -> rabbitmq-password"
echo "             existingErlangSecret: onlyoffice-creds -> erlang-cookie"
echo "  onlyoffice.jwt: existingSecret: onlyoffice-creds -> JWT_SECRET"
echo "  onlyoffice.env: amqp-uri key via onlyoffice-creds"
