#!/usr/bin/env bash
# Stop a tenant runtime. The data directory is kept unless --purge is passed
# together with CONFIRM_PURGE=1.
set -euo pipefail

TENANT_ID=""
PURGE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tenant-id) TENANT_ID="${2:-}"; shift 2 ;;
    --purge) PURGE=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$TENANT_ID" in
  ''|*[!0-9]*) echo "--tenant-id must be a positive integer" >&2; exit 2 ;;
esac

NAME="alphaloop-ft-${TENANT_ID}"
docker rm -f "$NAME" >/dev/null 2>&1 || true
echo "container ${NAME} removed"

if [ "$PURGE" -eq 1 ]; then
  if [ "${CONFIRM_PURGE:-0}" != "1" ]; then
    echo "refusing to purge without CONFIRM_PURGE=1" >&2
    exit 1
  fi
  DATA_ROOT="${DATA_ROOT:-/data/tenants}"
  DIR="${DATA_ROOT}/${TENANT_ID}"
  case "$DIR" in
    /data/tenants/*) rm -rf -- "$DIR" ;;
    *) echo "refusing unexpected data dir: $DIR" >&2; exit 1 ;;
  esac
  echo "data dir removed: ${DIR}"
fi
