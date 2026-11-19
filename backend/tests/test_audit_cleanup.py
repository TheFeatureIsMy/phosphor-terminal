"""Audit retention cleanup deletes only rows older than the window."""
from datetime import datetime, timedelta, timezone

from app.models.tenant import Tenant, TenantAuditLog
from app.services.audit_cleanup import AuditCleanupScheduler, AuditCleanupService


def test_cleanup_removes_only_old_rows(session):
    tenant = Tenant(name="audit-clean", slug="audit-clean")
    session.add(tenant)
    session.flush()
    old = TenantAuditLog(
        tenant_id=tenant.id, action="old",
        created_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=40),
    )
    new = TenantAuditLog(tenant_id=tenant.id, action="new")
    session.add_all([old, new])
    session.commit()

    deleted = AuditCleanupService(session_factory=lambda: session).tick_once(
        db=session, retention_days=30
    )
    assert deleted == 1
    actions = [row.action for row in session.query(TenantAuditLog).all()]
    assert actions == ["new"]


def test_cleanup_disabled_for_non_positive_days(session):
    service = AuditCleanupService(session_factory=lambda: session)
    assert service.tick_once(db=session, retention_days=0) == 0


def test_scheduler_disabled_when_interval_zero(session):
    scheduler = AuditCleanupScheduler(
        interval_hours=0, service=AuditCleanupService(session_factory=lambda: session)
    )
    assert scheduler.enabled is False


def test_cleanup_uses_plan_retention(session):
    from app.models.tenant import Tenant, TenantAuditLog
    from datetime import datetime, timedelta, timezone

    free = Tenant(name="free-plan", slug="free-plan", plan="free")
    pro = Tenant(name="pro-plan", slug="pro-plan", plan="pro")
    session.add_all([free, pro])
    session.flush()
    old = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=200)
    session.add_all([
        TenantAuditLog(tenant_id=free.id, action="free-old", created_at=old),
        TenantAuditLog(tenant_id=pro.id, action="pro-old", created_at=old),
    ])
    session.commit()
    deleted = AuditCleanupService(session_factory=lambda: session).tick_once(db=session)
    assert deleted == 1
    remaining = [row.action for row in session.query(TenantAuditLog).all()]
    assert remaining == ["pro-old"]


def test_cleanup_archives_before_delete(session, monkeypatch, tmp_path):
    import gzip
    import json

    from app.config import settings
    from app.models.tenant import Tenant, TenantAuditLog
    from datetime import datetime, timedelta, timezone

    monkeypatch.setattr(settings, "tenant_audit_archive_dir", str(tmp_path))
    tenant = Tenant(name="archive", slug="archive", plan="free")
    session.add(tenant)
    session.flush()
    session.add(TenantAuditLog(
        tenant_id=tenant.id, action="archived",
        created_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=200),
    ))
    session.commit()
    deleted = AuditCleanupService(session_factory=lambda: session).tick_once(db=session)
    assert deleted == 1
    files = list(tmp_path.glob("*.jsonl.gz"))
    assert len(files) == 1
    with gzip.open(files[0], "rt", encoding="utf-8") as fh:
        payload = [json.loads(line) for line in fh]
    assert payload[0]["action"] == "archived"


def test_cleanup_uploads_archive_to_s3(session, monkeypatch, tmp_path):
    import sys
    import types

    from app.config import settings
    from app.models.tenant import Tenant, TenantAuditLog
    from datetime import datetime, timedelta, timezone

    uploads = []

    class FakeClient:
        def upload_file(self, path, bucket, key):
            uploads.append((path, bucket, key))

    fake = types.ModuleType("boto3")
    fake.client = lambda *args, **kwargs: FakeClient()
    monkeypatch.setitem(sys.modules, "boto3", fake)
    monkeypatch.setattr(settings, "tenant_audit_archive_dir", str(tmp_path))
    monkeypatch.setattr(settings, "tenant_audit_archive_s3_bucket", "audit-bucket")
    monkeypatch.setattr(settings, "tenant_audit_archive_s3_prefix", "tenant-audit")

    tenant = Tenant(name="s3", slug="s3", plan="free")
    session.add(tenant)
    session.flush()
    session.add(TenantAuditLog(
        tenant_id=tenant.id, action="uploaded",
        created_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=200),
    ))
    session.commit()
    assert AuditCleanupService(session_factory=lambda: session).tick_once(db=session) == 1
    assert len(uploads) == 1
    assert uploads[0][1] == "audit-bucket"
    assert uploads[0][2].startswith("tenant-audit/tenant-")


def test_archive_list_and_download(client, monkeypatch, tmp_path):
    import gzip
    from app.config import settings

    monkeypatch.setattr(settings, "tenant_audit_archive_dir", str(tmp_path))
    with gzip.open(tmp_path / "tenant-1-test.jsonl.gz", "wt", encoding="utf-8") as fh:
        fh.write('{"action":"x"}\n')
    listing = client.get("/api/admin/tenant-audit/archives")
    assert listing.status_code == 200
    assert listing.json()[0]["name"] == "tenant-1-test.jsonl.gz"

    download = client.get("/api/admin/tenant-audit/archives/tenant-1-test.jsonl.gz")
    assert download.status_code == 200
    assert download.headers["content-type"] == "application/gzip"

    blocked = client.get("/api/admin/tenant-audit/archives/..%2Fsecret.jsonl.gz")
    assert blocked.status_code in (400, 404)
