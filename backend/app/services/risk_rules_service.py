"""Read effective risk rule thresholds."""
from __future__ import annotations
from dataclasses import dataclass


@dataclass
class RiskRules:
    daily_loss_limit: float
    weekly_loss_limit: float
    consecutive_losses_limit: int
    max_drawdown: float
    correlation_threshold: float
    kill_switch_threshold: float
    kill_switch_active: bool


class RiskRulesService:
    """Provides effective risk rule thresholds.

    In the current implementation, reads sensible defaults matching common
    trading risk policy values. These could be sourced from the
    `risk_policy_versions` DB table in a future iteration.
    """

    # Default thresholds aligned with typical crypto quant trading policies
    DEFAULT_DAILY_LOSS_LIMIT_PCT = 5.0
    DEFAULT_WEEKLY_LOSS_LIMIT_PCT = 10.0
    DEFAULT_CONSECUTIVE_LOSSES_LIMIT = 3
    DEFAULT_MAX_DRAWDOWN_PCT = 15.0
    DEFAULT_CORRELATION_THRESHOLD = 0.9
    DEFAULT_KILL_SWITCH_THRESHOLD = 20.0

    def get_effective(self) -> RiskRules:
        """Return the effective risk rule thresholds.

        Future: read from `risk_policy_versions` DB table via
        `sqlalchemy.select(RiskPolicyVersion).where(...)`.
        """
        return RiskRules(
            daily_loss_limit=self.DEFAULT_DAILY_LOSS_LIMIT_PCT,
            weekly_loss_limit=self.DEFAULT_WEEKLY_LOSS_LIMIT_PCT,
            consecutive_losses_limit=self.DEFAULT_CONSECUTIVE_LOSSES_LIMIT,
            max_drawdown=self.DEFAULT_MAX_DRAWDOWN_PCT,
            correlation_threshold=self.DEFAULT_CORRELATION_THRESHOLD,
            kill_switch_threshold=self.DEFAULT_KILL_SWITCH_THRESHOLD,
            kill_switch_active=False,
        )
