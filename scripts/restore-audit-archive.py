#!/usr/bin/env python3
"""Restore a JSONL.gz audit archive into tenant_audit_logs (idempotent by id)."""
from __future__ import annotations

import argparse
import gzip
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from sqlalchemy import create_engine, func, select  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from app.config import settings  # noqa: E402
from app.models.tenant import TenantAuditLog  # noqa: E402


def restore_rows(session, rows: list[dict], dry_run: bool = False) -> tuple[int, int]:
    inserted = skipped = 0
    for row in rows:
        if session.get(TenantAuditLog, row["id"]) is not None:
            skipped += 1
            continue
        inserted += 1
        if dry_run:
            continue
        session.add(TenantAuditLog(
            id=row["id"],
            tenant_id=row["tenant_id"],
            actor_user_id=row.get("actor_user_id"),
            action=row["action"],
            detail=row.get("detail") or {},
            created_at=(
                datetime.fromisoformat(row["created_at"]) if row.get("created_at") else None
            ),
        ))
    if not dry_run:
        session.commit()
        if session.bind.dialect.name == "postgresql":
            max_id = session.scalar(select(func.max(TenantAuditLog.id))) or 1
            session.execute(
                func.setval(func.pg_get_serial_sequence("tenant_audit_logs", "id"), max_id)
            )
            session.commit()
    return inserted, skipped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    with gzip.open(args.archive, "rt", encoding="utf-8") as fh:
        rows = [json.loads(line) for line in fh if line.strip()]
    engine = create_engine(settings.database_url)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        inserted, skipped = restore_rows(session, rows, args.dry_run)
    print(f"rows={len(rows)} inserted={inserted} skipped={skipped} dry_run={args.dry_run}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
