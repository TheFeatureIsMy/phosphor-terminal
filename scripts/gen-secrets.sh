#!/usr/bin/env bash
# Ensure an env file has SECRET_KEY and PULSEDESK_ENCRYPTION_KEY.
# Usage: scripts/gen-secrets.sh [path-to-env] [allowed-hosts-json]
set -euo pipefail

ENV_FILE="${1:-.env}"
ALLOWED_HOSTS_VALUE="${2:-}"

command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }

mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE" 2>/dev/null || true

need() {
  local key="$1" value="$2"
  if ! grep -q "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    echo "generated ${key} in ${ENV_FILE}"
  fi
}

need SECRET_KEY "$(openssl rand -base64 48 | tr -d '\n')"
# Fernet key = urlsafe base64 of 32 random bytes.
need PULSEDESK_ENCRYPTION_KEY "$(openssl rand -base64 32 | tr '+/' '-_')"

if [[ -n "$ALLOWED_HOSTS_VALUE" ]] && ! grep -q '^ALLOWED_HOSTS=' "$ENV_FILE"; then
  printf 'ALLOWED_HOSTS=%s\n' "$ALLOWED_HOSTS_VALUE" >> "$ENV_FILE"
  echo "set ALLOWED_HOSTS in ${ENV_FILE}"
fi
