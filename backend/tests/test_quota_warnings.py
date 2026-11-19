"""Quota warnings are audited once per resource per day."""
from app.models.tenant import Membership, Tenant, TenantAuditLog
from app.models.user import User
from app.services.quota_warnings import QuotaWarningService


def test_quota_warning_created_once(session):
    tenant = Tenant(name="warn", slug="warn", plan="free")
    session.add(tenant)
    session.flush()
    for index in range(4):
        user = User(username=f"warn{index}", email=f"warn{index}@example.com", hashed_password="x")
        session.add(user)
        session.flush()
        session.add(Membership(user_id=user.id, tenant_id=tenant.id, role="viewer"))
    session.commit()

    service = QuotaWarningService(session_factory=lambda: session)
    assert service.tick_once(db=session) == 1
    assert service.tick_once(db=session) == 0
    rows = session.query(TenantAuditLog).filter(TenantAuditLog.action == "quota.warning").all()
    assert len(rows) == 1
    assert rows[0].detail["resource"] == "members"


def test_quota_warning_emails_owner(session, monkeypatch):
    from app.services.email_service import EmailService

    sent = []
    monkeypatch.setattr(EmailService, "configured", property(lambda self: True))
    monkeypatch.setattr(
        EmailService, "send_quota_warning",
        lambda self, **kwargs: sent.append(kwargs) or True,
    )
    tenant = Tenant(name="warn-mail", slug="warn-mail", plan="free")
    session.add(tenant)
    session.flush()
    for index in range(4):
        user = User(
            username=f"mail{index}", email=f"mail{index}@example.com",
            hashed_password="x",
        )
        session.add(user)
        session.flush()
        session.add(Membership(
            user_id=user.id, tenant_id=tenant.id,
            role="owner" if index == 0 else "viewer",
        ))
    session.commit()
    QuotaWarningService(session_factory=lambda: session).tick_once(db=session)
    assert sent and sent[0]["to"] == "mail0@example.com"
    assert sent[0]["resource"] == "members"
