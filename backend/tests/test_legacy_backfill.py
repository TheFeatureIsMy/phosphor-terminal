"""Legacy null-tenant backfill helper."""
import importlib.util
from pathlib import Path

from sqlalchemy import create_engine, text

spec = importlib.util.spec_from_file_location(
    "backfill_legacy_tenant",
    Path(__file__).resolve().parents[2] / "scripts" / "backfill-legacy-tenant.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_backfill_assigns_only_null_rows():
    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE tenants (id INTEGER PRIMARY KEY)"))
        conn.execute(text("INSERT INTO tenants (id) VALUES (1)"))
        conn.execute(text(
            "CREATE TABLE risk_events (id INTEGER PRIMARY KEY, tenant_id INTEGER)"
        ))
        conn.execute(text(
            "CREATE TABLE ai_research_links (id INTEGER PRIMARY KEY, tenant_id INTEGER)"
        ))
        for table in ("attribution_reports", "canvas_workflows", "freqai_runs"):
            conn.execute(text(f"CREATE TABLE {table} (id INTEGER PRIMARY KEY, tenant_id INTEGER)"))
        conn.execute(text("INSERT INTO risk_events (id, tenant_id) VALUES (1, NULL), (2, 99)"))
        counts = module.backfill(conn, 1, dry_run=False)
        assert counts["risk_events"] == 1
        rows = conn.execute(text("SELECT id, tenant_id FROM risk_events ORDER BY id")).all()
        assert rows == [(1, 1), (2, 99)]
