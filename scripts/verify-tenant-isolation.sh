#!/usr/bin/env bash
# End-to-end tenant isolation check on a disposable PostgreSQL cluster.
# Migrations -> role creation -> API as alphaloop_app -> workers as alphaloop_worker.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-55456}"
DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alphaloop-tenant.XXXXXX")"
DB_NAME="alphaloop_tenant_check"
APP_PASSWORD="tenant_app_pw"
WORKER_PASSWORD="tenant_worker_pw"
PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"
ALEMBIC="${ALEMBIC:-$ROOT/.venv/bin/alembic}"
[ -x "$PYTHON" ] || PYTHON="python3"
[ -x "$ALEMBIC" ] || ALEMBIC="alembic"

cleanup() {
  if [ -f "$DATA_DIR/postmaster.pid" ]; then
    pg_ctl -D "$DATA_DIR" stop -m fast >/dev/null 2>&1 || true
  fi
  rm -rf "$DATA_DIR"
}
trap cleanup EXIT

for bin in initdb pg_ctl createdb psql; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing $bin" >&2; exit 2; }
done

initdb -D "$DATA_DIR" -A trust -U postgres >/dev/null
pg_ctl -D "$DATA_DIR" -o "-p $PORT -k ${TMPDIR:-/tmp}" -l "$DATA_DIR/postgres.log" start >/dev/null
for _ in $(seq 1 30); do
  pg_isready -h 127.0.0.1 -p "$PORT" >/dev/null 2>&1 && break
  sleep 0.5
done
createdb -h 127.0.0.1 -p "$PORT" -U postgres "$DB_NAME"

cd "$ROOT/backend"
DATABASE_URL="postgresql://postgres@127.0.0.1:$PORT/$DB_NAME" \
  "$ALEMBIC" upgrade head >/dev/null

cd "$ROOT"
PGHOST=127.0.0.1 PGPORT="$PORT" POSTGRES_USER=postgres POSTGRES_DB="$DB_NAME" \
  APP_DB_PASSWORD="$APP_PASSWORD" WORKER_DB_PASSWORD="$WORKER_PASSWORD" \
  ./deploy/postgres/init-tenant-roles.sh >/dev/null

export DATABASE_URL="postgresql://alphaloop_app:$APP_PASSWORD@127.0.0.1:$PORT/$DB_NAME"
export DATABASE_URL_WORKER="postgresql://alphaloop_worker:$WORKER_PASSWORD@127.0.0.1:$PORT/$DB_NAME"
export AUTH_REQUIRED=1
export SECRET_KEY="tenant-isolation-check"
export PULSEDESK_ENCRYPTION_KEY="b2BPUaboInk_FQ-v5cTmO0SJ0uH9jXeMzfGzpsCzM18="
export ALLOWED_HOSTS='["testserver","localhost","127.0.0.1","test"]'

cd "$ROOT/backend"
"$PYTHON" - <<'PY'
import app.models.strategy, app.models.user, app.models.tenant, app.models.agent_signal
import app.models.ai_provider, app.models.ai, app.models.research, app.models.research_v2
import app.models.provider_config, app.models.dryrun
import app.domain.ledger, app.domain.command, app.domain.strategy, app.domain.provider
import app.domain.risk, app.domain.execution, app.domain.order, app.domain.growth
import app.domain.manipulation, app.domain.inference, app.domain.mcp
import app.domain.reconciliation, app.domain.archive

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from app.main import app
from app.services.auth import create_access_token

client = TestClient(app, base_url="http://testserver")
r = client.post("/auth/register", json={
    "username": "isolation_a", "email": "a@example.com", "password": "secret123",
})
assert r.status_code == 201, r.text
r = client.post("/auth/login", data={"username": "a@example.com", "password": "secret123"})
assert r.status_code == 200, r.text
ha = {"Authorization": f"Bearer {r.json()['access_token']}"}
tenant_a = client.get("/auth/tenant", headers=ha).json()["id"]

r = client.post("/api/v2/strategies", json={
    "name": "a-only", "strategy_type": "rule_dsl", "source_type": "manual",
}, headers=ha)
assert r.status_code == 201, r.text
strategy_a = r.json()["id"]

worker = create_engine(__import__("os").environ["DATABASE_URL_WORKER"])
with worker.begin() as c:
    tenant_b = c.execute(text(
        "insert into tenants (name, slug, status, created_at) "
        "values ('B','isolation-b','active',now()) returning id"
    )).scalar()
token_b = create_access_token({"sub": "999", "tid": str(tenant_b), "role": "owner"})
hb = {"Authorization": f"Bearer {token_b}"}

assert client.get("/api/v2/strategies", headers=hb).json() == []
assert client.get(f"/api/v2/strategies/{strategy_a}", headers=hb).status_code == 404
assert len(client.get("/api/v2/strategies", headers=ha).json()) == 1

app_engine = create_engine(__import__("os").environ["DATABASE_URL"])
with app_engine.connect() as c:
    assert c.execute(text("select count(*) from strategies_v2")).scalar() == 0
    c.execute(text("select set_config('app.tenant_id', :t, true)"), {"t": str(tenant_a)})
    assert c.execute(text("select count(*) from strategies_v2")).scalar() == 1
with worker.connect() as c:
    assert c.execute(text("select count(*) from strategies_v2")).scalar() == 1

print("tenant isolation: PASS (API + RLS + worker bypass)")
PY

echo "OK: tenant isolation verified on PostgreSQL"
