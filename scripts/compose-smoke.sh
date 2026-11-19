#!/usr/bin/env bash
# Full-stack deployment smoke: build compose, wait for readiness, register,
# login, and hit the dashboard. Requires a working Docker daemon.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BASE_URL:-http://127.0.0.1:8000}"

cd "$ROOT"
bash scripts/gen-secrets.sh .env '["localhost","127.0.0.1"]'

cleanup() {
  if [[ "${KEEP_STACK:-0}" != "1" ]]; then
    docker compose logs --tail=120 || true
    docker compose down -v || true
  fi
}
trap cleanup EXIT

echo "== building and starting compose stack =="
docker compose up -d --build

echo "== waiting for readiness =="
ready=0
for _ in $(seq 1 90); do
  body="$(curl -fsS --max-time 3 "$BASE/readiness" 2>/dev/null || true)"
  if [[ "$body" == *'"status":"ready"'* ]]; then
    echo "$body"
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != "1" ]]; then
  echo "readiness did not become ready" >&2
  exit 1
fi

echo "== bootstrapping first user =="
curl -fsS -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d '{"username":"smoke","email":"smoke@example.com","password":"secret123"}' \
  >/dev/null || true

echo "== smoke =="
SMOKE_USERNAME=smoke SMOKE_PASSWORD=secret123 bash scripts/smoke.sh "$BASE"
echo "compose smoke passed"
