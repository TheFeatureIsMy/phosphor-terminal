"""Session cleanup service removes only old revoked/expired rows."""
from datetime import datetime, timedelta, timezone

from app.models.tenant import DeviceSession, Tenant
from app.models.user import User
from app.services.session_cleanup import SessionCleanupScheduler, SessionCleanupService


def test_cleanup_service(session):
    tenant = Tenant(name="sc", slug="sc")
    session.add(tenant)
    session.flush()
    user = User(username="scuser", email="sc@example.com", hashed_password="x",
                is_active=True, is_superuser=False)
    session.add(user)
    session.flush()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    old = now - timedelta(days=90)
    session.add_all([
        DeviceSession(id="r", user_id=user.id, tenant_id=tenant.id, revoked_at=old),
        DeviceSession(id="e", user_id=user.id, tenant_id=tenant.id, expires_at=old),
        DeviceSession(id="a", user_id=user.id, tenant_id=tenant.id,
                      expires_at=now + timedelta(days=30)),
    ])
    session.commit()

    assert SessionCleanupService().tick_once(db=session, retention_days=30) == 2
    assert {row.id for row in session.query(DeviceSession).all()} == {"a"}


def test_scheduler_disabled_by_default():
    assert SessionCleanupScheduler(interval_hours=0).enabled is False
