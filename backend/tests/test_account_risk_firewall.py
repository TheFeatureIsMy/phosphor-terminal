import pytest
from app.domain.dsl import AccountRiskPolicy
from app.services.account_risk_firewall import AccountRiskFirewall, AccountRiskState
from app.services.runtime_redis_store import RuntimeRedisStore

@pytest.fixture
def policy():
    return AccountRiskPolicy(
        max_daily_loss=0.03, max_weekly_loss=0.08,
        max_consecutive_losses=4, kill_switch_enabled=True,
    )

@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)

@pytest.fixture
def firewall(policy, store):
    return AccountRiskFirewall(policy=policy, redis_store=store)

@pytest.mark.asyncio
async def test_fresh_account_allowed(firewall):
    state = await firewall.check("acc1")
    assert state.allowed is True
    assert state.reason_code == "account_risk_allowed"

@pytest.mark.asyncio
async def test_daily_loss_exceeded(firewall):
    await firewall.record_trade_result("acc1", pnl=-0.015, is_loss=True)
    await firewall.record_trade_result("acc1", pnl=-0.016, is_loss=True)
    state = await firewall.check("acc1")
    assert state.allowed is False
    assert state.reason_code == "daily_loss_limit_reached"

@pytest.mark.asyncio
async def test_weekly_loss_exceeded(firewall):
    for _ in range(6):
        await firewall.record_trade_result("acc1", pnl=-0.015, is_loss=True)
    state = await firewall.check("acc1")
    assert state.allowed is False
    assert "weekly_loss" in state.reason_code or "daily_loss" in state.reason_code

@pytest.mark.asyncio
async def test_consecutive_losses(firewall):
    for _ in range(4):
        await firewall.record_trade_result("acc1", pnl=-0.005, is_loss=True)
    state = await firewall.check("acc1")
    assert state.allowed is False
    assert state.reason_code == "consecutive_loss_limit_reached"

@pytest.mark.asyncio
async def test_consecutive_reset_on_win(firewall):
    for _ in range(3):
        await firewall.record_trade_result("acc1", pnl=-0.005, is_loss=True)
    await firewall.record_trade_result("acc1", pnl=0.01, is_loss=False)
    state = await firewall.check("acc1")
    assert state.allowed is True

@pytest.mark.asyncio
async def test_kill_switch(firewall):
    await firewall.activate_kill_switch("acc1")
    state = await firewall.check("acc1")
    assert state.allowed is False
    assert state.reason_code == "kill_switch_active"

@pytest.mark.asyncio
async def test_daily_reset(firewall):
    await firewall.record_trade_result("acc1", pnl=-0.031, is_loss=True)
    state = await firewall.check("acc1")
    assert state.allowed is False
    await firewall.reset_daily("acc1")
    state = await firewall.check("acc1")
    assert state.allowed is True
