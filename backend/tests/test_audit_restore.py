"""Audit archive restore helper."""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "restore_audit_archive",
    Path(__file__).resolve().parents[2] / "scripts" / "restore-audit-archive.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_restore_is_idempotent(session):
    from app.models.tenant import Tenant

    tenant = Tenant(name="restore", slug="restore")
    session.add(tenant)
    session.commit()
    rows = [{
        "id": 9001, "tenant_id": tenant.id, "actor_user_id": None,
        "action": "restored", "detail": {"a": 1}, "created_at": "2026-01-01T00:00:00",
    }]
    inserted, skipped = module.restore_rows(session, rows)
    assert (inserted, skipped) == (1, 0)
    inserted, skipped = module.restore_rows(session, rows)
    assert (inserted, skipped) == (0, 1)
