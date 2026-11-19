#!/usr/bin/env python3
"""Assign historical null-tenant rows to one tenant (single-tenant upgrades).

The legacy tables have no ownership column, so this is only safe when the
installation has exactly one tenant. Refuses to run with multiple tenants
unless --force is passed.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from sqlalchemy import create_engine, text  # noqa: E402

from app.config import settings  # noqa: E402

TABLES = [
    "ai_research_links",
    "attribution_reports",
    "canvas_workflows",
    "freqai_runs",
    "risk_events",
]


def backfill(conn, tenant_id: int, dry_run: bool) -> dict[str, int]:
    if conn.execute(
        text("SELECT 1 FROM tenants WHERE id = :tid"), {"tid": tenant_id}
    ).scalar() is None:
        raise SystemExit(f"tenant {tenant_id} does not exist")
    counts = {}
    for table in TABLES:
        count = conn.execute(
            text(f"SELECT count(*) FROM {table} WHERE tenant_id IS NULL")
        ).scalar_one()
        counts[table] = count
        if not dry_run and count:
            conn.execute(
                text(f"UPDATE {table} SET tenant_id = :tid WHERE tenant_id IS NULL"),
                {"tid": tenant_id},
            )
    return counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tenant-id", type=int, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    engine = create_engine(settings.database_url)
    with engine.begin() as conn:
        tenant_count = conn.execute(text("SELECT count(*) FROM tenants")).scalar_one()
        if tenant_count > 1 and not args.force:
            raise SystemExit(
                f"refusing to backfill {tenant_count} tenants without --force"
            )
        counts = backfill(conn, args.tenant_id, args.dry_run)
    mode = "would update" if args.dry_run else "updated"
    for table, count in counts.items():
        print(f"{mode} {count:6d} rows in {table}")
    print("dry run" if args.dry_run else "backfill: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
