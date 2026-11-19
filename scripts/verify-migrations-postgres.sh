#!/usr/bin/env bash
# Verify the full Alembic chain against a disposable local Postgres cluster.
# Usage: scripts/verify-migrations-postgres.sh [port]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-55439}"
DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alphaloop-pg.XXXXXX")"
LOG_FILE="$DATA_DIR/postgres.log"
DB_NAME="alphaloop_migration_check"

cleanup() {
  if [ -f "$DATA_DIR/postmaster.pid" ]; then
    pg_ctl -D "$DATA_DIR" stop -m fast >/dev/null 2>&1 || true
  fi
  rm -rf "$DATA_DIR"
}
trap cleanup EXIT

for bin in initdb pg_ctl createdb psql; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "missing $bin (install PostgreSQL first)" >&2
    exit 2
  }
done

initdb -D "$DATA_DIR" -A trust -U postgres >/dev/null
pg_ctl -D "$DATA_DIR" -o "-p $PORT -k ${TMPDIR:-/tmp}" -l "$LOG_FILE" start >/dev/null
for _ in $(seq 1 30); do
  pg_isready -h 127.0.0.1 -p "$PORT" >/dev/null 2>&1 && break
  sleep 0.5
done
pg_isready -h 127.0.0.1 -p "$PORT" >/dev/null

createdb -h 127.0.0.1 -p "$PORT" -U postgres "$DB_NAME"

cd "$ROOT/backend"
DATABASE_URL="postgresql://postgres@127.0.0.1:$PORT/$DB_NAME" \
  ../.venv/bin/alembic upgrade head

echo "--- current revision ---"
DATABASE_URL="postgresql://postgres@127.0.0.1:$PORT/$DB_NAME" \
  ../.venv/bin/alembic current

echo "--- tenant tables ---"
psql -h 127.0.0.1 -p "$PORT" -U postgres -d "$DB_NAME" -Atc \
  "select table_name from information_schema.tables
   where table_schema='public'
     and table_name in ('tenants','memberships','provider_configs','knowledge_documents')
   order by table_name;"

echo "OK: migrations applied on PostgreSQL"
