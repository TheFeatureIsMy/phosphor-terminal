"""Tenant runtime health tick updates profile state."""
import pytest

from app.models.tenant import Tenant, TenantExecutionProfile
from app.services.tenant_runtime_health import (
    TenantRuntimeHealthScheduler,
    TenantRuntimeHealthService,
)


class _Client:
    def __init__(self, base_url):
        self.base_url = base_url

    async def ping(self):
        return True


class _DeadClient(_Client):
    async def ping(self):
        return False


@pytest.mark.asyncio
async def test_tick_marks_healthy(session):
    tenant = Tenant(name="rt", slug="rt")
    session.add(tenant)
    session.flush()
    session.add(TenantExecutionProfile(
        tenant_id=tenant.id, mode="dedicated", freqtrade_url="http://rt:8080",
        enabled=True, max_open_trades=2,
    ))
    session.commit()

    tested = await TenantRuntimeHealthService().tick_once(
        db=session, client_factory=_Client,
    )
    assert tested == 1
    row = session.query(TenantExecutionProfile).one()
    assert row.runtime_status == "healthy"
    assert row.last_health_at is not None


@pytest.mark.asyncio
async def test_tick_marks_unreachable(session):
    tenant = Tenant(name="rt2", slug="rt2")
    session.add(tenant)
    session.flush()
    session.add(TenantExecutionProfile(
        tenant_id=tenant.id, mode="dedicated", freqtrade_url="http://rt2:8080",
        enabled=True, max_open_trades=2,
    ))
    session.commit()

    tested = await TenantRuntimeHealthService().tick_once(
        db=session, client_factory=_DeadClient,
    )
    assert tested == 1
    row = session.query(TenantExecutionProfile).one()
    assert row.runtime_status == "unreachable"
    assert row.last_error == "ping failed"


def test_scheduler_disabled_by_default():
    assert TenantRuntimeHealthScheduler(interval_s=0).enabled is False
