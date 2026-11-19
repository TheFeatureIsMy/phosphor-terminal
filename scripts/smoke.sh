#!/usr/bin/env bash
# Deployment smoke test. Usage:
#   scripts/smoke.sh [base_url]
#   SMOKE_USERNAME=... SMOKE_PASSWORD=... scripts/smoke.sh https://api.example.com
set -euo pipefail

BASE="${1:-http://127.0.0.1:8000}"
BASE="${BASE%/}"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== health =="
curl -fsS --max-time 5 "$BASE/health" || fail "health"
echo

echo "== readiness =="
READY="$(curl -fsS --max-time 5 "$BASE/readiness")" || fail "readiness"
echo "$READY"
python3 - "$READY" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
if data.get("status") != "ready":
    raise SystemExit(f"readiness not ready: {data}")
PY

if [[ -n "${SMOKE_USERNAME:-}" && -n "${SMOKE_PASSWORD:-}" ]]; then
  echo "== login =="
  TOKEN="$(curl -fsS --max-time 10 -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "username=$SMOKE_USERNAME" \
    --data-urlencode "password=$SMOKE_PASSWORD" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')" \
    || fail "login"
  echo "token acquired"

  echo "== dashboard =="
  curl -fsS --max-time 10 "$BASE/api/overview/dashboard" \
    -H "Authorization: Bearer $TOKEN" >/dev/null || fail "dashboard"
  echo "ok"
else
  echo "skip authenticated checks (set SMOKE_USERNAME/SMOKE_PASSWORD)"
fi
