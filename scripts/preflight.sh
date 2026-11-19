#!/usr/bin/env bash
# Production preflight: secrets, DB connectivity, migration head, tenant roles,
# and RLS coverage. Exits non-zero on a fatal problem.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/backend"

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || PY="python3"
FAIL=0

echo "== settings =="
"$PY" - <<'PY' || FAIL=1
from app.config import settings
problems = settings.security_problems()
if problems:
    print("FATAL:", "; ".join(problems))
    raise SystemExit(1)
print("ok: app_env=%s auth_required=%s" % (settings.app_env, settings.auth_required))
PY

echo "== database =="
"$PY" - <<'PY' || FAIL=1
from sqlalchemy import text
from app.database import engine
from app.config import settings

with engine.connect() as c:
    row = c.execute(text(
        "select current_user, r.rolsuper, r.rolbypassrls "
        "from pg_roles r where r.rolname=current_user"
    )).one()
    print("connected as %s (superuser=%s bypassrls=%s)" % tuple(row))
    if row.rolsuper or row.rolbypassrls:
        print("WARN: API role bypasses RLS; use alphaloop_app in production")
    roles = dict(c.execute(text(
        "select rolname, rolbypassrls from pg_roles where rolname like 'alphaloop_%'"
    )).all())
    for name in ("alphaloop_app", "alphaloop_worker"):
        if name not in roles:
            print("WARN: role %s missing (run deploy/postgres/init-tenant-roles.sh)" % name)
    if roles.get("alphaloop_worker") is not True:
        print("WARN: alphaloop_worker does not have BYPASSRLS")
    for table in ("strategies_v2", "backtest_runs"):
        enabled = c.execute(text(
            "select relrowsecurity from pg_class where relname=:t"
        ), {"t": table}).scalar()
        if not enabled:
            print("WARN: RLS not enabled on %s" % table)
        else:
            print("ok: RLS enabled on %s" % table)
PY

echo "== migrations =="
CURRENT="$("$PY" -m alembic current 2>/dev/null | awk '{print $1}' | head -1)"
HEAD="$("$PY" -m alembic heads 2>/dev/null | awk '{print $1}' | head -1)"
echo "current=${CURRENT:-none} head=${HEAD:-unknown}"
if [ -z "$CURRENT" ] || [ "$CURRENT" != "$HEAD" ]; then
  echo "FATAL: database is not at Alembic head"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "preflight: FAILED"
  exit 1
fi
echo "preflight: OK"
