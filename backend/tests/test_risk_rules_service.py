"""Tests for RiskRulesService"""
from app.services.risk_rules_service import RiskRulesService


def test_get_effective_returns_all_fields():
    svc = RiskRulesService()
    rules = svc.get_effective()
    assert rules.daily_loss_limit > 0
    assert rules.weekly_loss_limit > 0
    assert rules.consecutive_losses_limit > 0
    assert rules.max_drawdown > 0
    assert rules.correlation_threshold > 0
    assert rules.kill_switch_threshold > 0
    assert isinstance(rules.kill_switch_active, bool)


def test_get_effective_returns_dataclass():
    svc = RiskRulesService()
    rules = svc.get_effective()
    assert hasattr(rules, "daily_loss_limit")
    assert hasattr(rules, "weekly_loss_limit")
    assert hasattr(rules, "consecutive_losses_limit")
    assert hasattr(rules, "max_drawdown")
    assert hasattr(rules, "correlation_threshold")
    assert hasattr(rules, "kill_switch_threshold")
    assert hasattr(rules, "kill_switch_active")
