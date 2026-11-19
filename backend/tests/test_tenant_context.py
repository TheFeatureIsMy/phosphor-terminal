"""The DB hook exposes the request tenant as a transaction-local GUC."""
import pytest
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.security.tenant_context import reset_current_tenant, set_current_tenant


def test_session_sets_app_tenant_id(session):
    if session.bind.dialect.name != "postgresql":
        pytest.skip("PostgreSQL-specific GUC")

    factory = sessionmaker(bind=session.bind)
    token = set_current_tenant(42)
    db = factory()
    try:
        value = db.execute(
            text("SELECT current_setting('app.tenant_id', true)")
        ).scalar()
        assert value == "42"
    finally:
        db.close()
        reset_current_tenant(token)


def test_no_context_leaves_guc_unset(session):
    if session.bind.dialect.name != "postgresql":
        pytest.skip("PostgreSQL-specific GUC")

    factory = sessionmaker(bind=session.bind)
    db = factory()
    try:
        value = db.execute(
            text("SELECT current_setting('app.tenant_id', true)")
        ).scalar()
        assert value in (None, "")
    finally:
        db.close()
