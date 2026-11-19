#!/usr/bin/env bash
# Provision one Freqtrade runtime per tenant (contract:
# docs/architecture/20_tenant_runtime_provisioning.md).
#
# Usage:
#   scripts/provision-tenant-runtime.sh --tenant-id 42 [--dry-run]
#
# Environment:
#   DATA_ROOT   default /data/tenants
#   FT_IMAGE    default freqtradeorg/freqtrade:stable
#   FT_NETWORK  default phosphor-terminal_default
#   FT_CPUS     default 1.0
#   FT_MEMORY   default 1g
set -euo pipefail
umask 077

TENANT_ID=""
CONFIG_FILE=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tenant-id) TENANT_ID="${2:-}"; shift 2 ;;
    --config) CONFIG_FILE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$TENANT_ID" in
  ''|*[!0-9]*) echo "--tenant-id must be a positive integer" >&2; exit 2 ;;
esac
if [ "$TENANT_ID" -lt 1 ]; then
  echo "--tenant-id must be >= 1" >&2
  exit 2
fi

DATA_ROOT="${DATA_ROOT:-/data/tenants}"
FT_IMAGE="${FT_IMAGE:-freqtradeorg/freqtrade:stable}"
FT_NETWORK="${FT_NETWORK:-phosphor-terminal_default}"
FT_CPUS="${FT_CPUS:-1.0}"
FT_MEMORY="${FT_MEMORY:-1g}"
PORT=$((19000 + TENANT_ID))
NAME="alphaloop-ft-${TENANT_ID}"
DIR="${DATA_ROOT}/${TENANT_ID}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-$REPO_ROOT/freqtrade/user_data/config.json}"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  %s\n' "$*"
  else
    "$@"
  fi
}

echo "tenant=${TENANT_ID} container=${NAME} port=${PORT}"
echo "data_dir=${DIR}"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$DIR/strategies" "$DIR/logs"
  chmod 700 "$DIR" "$DIR/strategies" "$DIR/logs"
  if [ -n "$CONFIG_FILE" ]; then
    [ -f "$CONFIG_FILE" ] || { echo "missing config: $CONFIG_FILE" >&2; exit 2; }
    cp "$CONFIG_FILE" "$DIR/config.json"
    chmod 600 "$DIR/config.json"
    echo "installed generated config"
  elif [ ! -f "$DIR/config.json" ]; then
    [ -f "$CONFIG_TEMPLATE" ] || { echo "missing template: $CONFIG_TEMPLATE" >&2; exit 2; }
    cp "$CONFIG_TEMPLATE" "$DIR/config.json"
    echo "copied config template"
  fi
  [ -f "$DIR/config.json" ] && chmod 600 "$DIR/config.json"
fi

run docker rm -f "$NAME" >/dev/null 2>&1 || true
run docker run -d \
  --name "$NAME" \
  --network "$FT_NETWORK" \
  --restart unless-stopped \
  --cpus "$FT_CPUS" \
  --memory "$FT_MEMORY" \
  --pids-limit 256 \
  -v "${DIR}:/freqtrade/user_data" \
  -e "FREQTRADE__API_SERVER__LISTEN_IP=0.0.0.0" \
  -e "FREQTRADE__API_SERVER__LISTEN_PORT=8080" \
  "$FT_IMAGE" \
  trade --config /freqtrade/user_data/config.json

if [ "$DRY_RUN" -eq 0 ]; then
  echo "waiting for runtime API..."
  for _ in $(seq 1 30); do
    if docker exec "$NAME" curl -fsS http://127.0.0.1:8080/api/v1/ping >/dev/null 2>&1; then
      echo "runtime ready"
      break
    fi
    sleep 2
  done
fi

cat <<EOF
profile:
  freqtrade_url: http://${NAME}:8080
  suggested_port: ${PORT}
  max_open_trades: 2

next:
  PUT /api/admin/execution-profile with the URL and credentials
EOF
