#!/usr/bin/env python3
"""Report tenant-column / RLS coverage for the current PostgreSQL database.

Usage: DATABASE_URL=... python scripts/audit-tenant-schema.py
"""
from __future__ import annotations

import os
import sys

from sqlalchemy import create_engine, text

LINK_COLUMNS = ("strategy_id", "strategy_version_id", "strategy_run_id")
# Platform-operational tables with tenant_id but intentionally no RLS.
RLS_ALLOWLIST = {
    "command_bus_commands",
    "memberships",
    # Accepted by token without a tenant GUC.
    "tenant_invites",
    # Public billing webhook writes before a tenant GUC is set.
    "billing_events",
    # Read by the auth middleware before a tenant GUC exists.
    "device_sessions",
}


def main() -> int:
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("DATABASE_URL is required", file=sys.stderr)
        return 2
    engine = create_engine(url)
    with engine.connect() as c:
        tenant_tables = set(c.execute(text(
            "select table_name from information_schema.columns "
            "where table_schema='public' and column_name='tenant_id'"
        )).scalars())
        rls = dict(c.execute(text(
            "select relname, relrowsecurity from pg_class "
            "where relkind='r' and relnamespace='public'::regnamespace"
        )).all())
        policies = dict(c.execute(text(
            "select tablename, count(*) from pg_policies "
            "where schemaname='public' group by tablename"
        )).all())
        linked = []
        for table, column in c.execute(text(
            "select table_name, column_name from information_schema.columns "
            "where table_schema='public' and column_name = any(:cols)"
        ), {"cols": list(LINK_COLUMNS)}).all():
            if table not in tenant_tables and table not in linked:
                linked.append(table)

    enabled = sorted(t for t in tenant_tables if rls.get(t))
    missing_rls = sorted(t for t in tenant_tables if not rls.get(t))
    missing_policy = sorted(t for t in enabled if not policies.get(t))
    unexpected = [t for t in missing_rls if t not in RLS_ALLOWLIST]

    print(f"tenant tables: {len(tenant_tables)}")
    print(f"RLS enabled:   {len(enabled)}")
    for table in enabled:
        print(f"  ok  {table} (policies={policies.get(table, 0)})")
    if missing_rls:
        print("RLS NOT enabled:")
        for table in missing_rls:
            tag = "allowlisted" if table in RLS_ALLOWLIST else "MISSING"
            print(f"  {tag}: {table}")
    if missing_policy:
        print("RLS enabled but no policy:")
        for table in missing_policy:
            print(f"  MISSING POLICY: {table}")
    if linked:
        print("strategy-linked tables without tenant_id:")
        for table in sorted(set(linked)):
            print(f"  {table}")

    return 1 if (unexpected or missing_policy) else 0


if __name__ == "__main__":
    raise SystemExit(main())
