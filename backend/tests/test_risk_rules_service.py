"""Tests for RiskRulesService"""
from app.services.risk_rules_service import RiskRulesService
from app.domain.risk import RiskPolicy, RiskPolicyVersion


def test_get_effective_returns_all_fields():
    svc = RiskRulesService()
    rules = svc.get_effective()  # no DB → fallback to defaults
    assert rules.daily_loss_limit > 0
    assert rules.weekly_loss_limit > 0
    assert rules.consecutive_losses_limit > 0
    assert rules.max_drawdown > 0
    assert rules.correlation_threshold > 0
    assert rules.kill_switch_threshold > 0
    assert isinstance(rules.kill_switch_active, bool)


def test_get_effective_returns_dataclass():
    svc = RiskRulesService()
    rules = svc.get_effective()  # no DB → fallback to defaults
    assert hasattr(rules, "daily_loss_limit")
    assert hasattr(rules, "weekly_loss_limit")
    assert hasattr(rules, "consecutive_losses_limit")
    assert hasattr(rules, "max_drawdown")
    assert hasattr(rules, "correlation_threshold")
    assert hasattr(rules, "kill_switch_threshold")
    assert hasattr(rules, "kill_switch_active")


def test_get_effective_reads_active_policy_from_db(session):
    """Seed an active RiskPolicyVersion and verify the service reads its values."""
    # Arrange: create a RiskPolicy + active version with known thresholds
    rp = RiskPolicy(name="test-policy", policy_type="conservative", status="active")
    session.add(rp)
    session.flush()

    rpv = RiskPolicyVersion(
        risk_policy_id=rp.id,
        version_no=1,
        policy_json={
            "max_daily_loss_pct": 0.02,        # 2%
            "max_weekly_loss_pct": 0.05,        # 5%
            "max_consecutive_losses": 5,
            "max_drawdown_pct": 0.10,           # 10%
            "correlation_threshold": 0.85,
            "kill_switch_threshold": 0.15,      # 15%
            "kill_switch_active": True,
        },
        policy_hash="abc123",
        status="active",
        created_by="test",
    )
    session.add(rpv)
    session.commit()

    # Act
    svc = RiskRulesService()
    rules = svc.get_effective(session)

    # Assert: decimal fractions are converted to percentages
    assert rules.daily_loss_limit == 2.0
    assert rules.weekly_loss_limit == 5.0
    assert rules.consecutive_losses_limit == 5
    assert rules.max_drawdown == 10.0
    assert rules.correlation_threshold == 0.85
    assert rules.kill_switch_threshold == 15.0
    assert rules.kill_switch_active is True


def test_get_effective_falls_back_to_defaults_when_no_active_policy(session):
    """When only a draft (not active) policy exists, fall back to defaults."""
    rp = RiskPolicy(name="draft-policy", policy_type="conservative", status="draft")
    session.add(rp)
    session.flush()

    rpv = RiskPolicyVersion(
        risk_policy_id=rp.id,
        version_no=1,
        policy_json={"max_daily_loss_pct": 0.01},
        policy_hash="abc",
        status="draft",
        created_by="test",
    )
    session.add(rpv)
    session.commit()

    svc = RiskRulesService()
    rules = svc.get_effective(session)

    # Should use defaults, not the draft values
    assert rules.daily_loss_limit == 5.0
    assert rules.weekly_loss_limit == 10.0
    assert rules.consecutive_losses_limit == 3
    assert rules.kill_switch_active is False