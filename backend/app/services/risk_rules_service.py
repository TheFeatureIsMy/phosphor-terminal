"""Read effective risk rule thresholds."""
from __future__ import annotations
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from sqlalchemy.orm import Session


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

    Reads from the `risk_policy_versions` DB table (first active version
    ordered by creation date).  Falls back to hardcoded defaults when no
    active policy exists in the database.
    """

    # Default thresholds aligned with typical crypto quant trading policies
    DEFAULT_DAILY_LOSS_LIMIT_PCT = 5.0
    DEFAULT_WEEKLY_LOSS_LIMIT_PCT = 10.0
    DEFAULT_CONSECUTIVE_LOSSES_LIMIT = 3
    DEFAULT_MAX_DRAWDOWN_PCT = 15.0
    DEFAULT_CORRELATION_THRESHOLD = 0.9
    DEFAULT_KILL_SWITCH_THRESHOLD = 20.0

    # Policy JSON key names (policy_json stores decimal fractions, e.g. 0.05 = 5%)
    _KEY_DAILY_LOSS = "max_daily_loss_pct"
    _KEY_WEEKLY_LOSS = "max_weekly_loss_pct"
    _KEY_CONSECUTIVE_LOSSES = "max_consecutive_losses"
    _KEY_MAX_DRAWDOWN = "max_drawdown_pct"
    _KEY_CORRELATION = "correlation_threshold"
    _KEY_KILL_SWITCH_THRESHOLD = "kill_switch_threshold"
    _KEY_KILL_SWITCH_ACTIVE = "kill_switch_active"

    @staticmethod
    def _to_pct(value: float | int) -> float:
        """Convert a decimal fraction (0.05) to percentage (5.0)."""
        if isinstance(value, float) and 0 < value < 1:
            return round(value * 100, 4)
        return float(value)

    def get_effective(self, db: Session | None = None) -> RiskRules:
        """Return the effective risk rule thresholds.

        When *db* is provided, queries the most recently created active
        ``RiskPolicyVersion`` and reads thresholds from its *policy_json*.
        Any field missing from the JSON falls back to the class default.
        When *db* is None (or no active policy exists), returns defaults.
        """
        if db is not None:
            from app.domain.risk import RiskPolicyVersion

            active = (
                db.query(RiskPolicyVersion)
                .filter(RiskPolicyVersion.status == "active")
                .order_by(RiskPolicyVersion.created_at.desc())
                .first()
            )
            if active is not None:
                pj = active.policy_json
                return RiskRules(
                    daily_loss_limit=self._to_pct(
                        pj.get(self._KEY_DAILY_LOSS, self.DEFAULT_DAILY_LOSS_LIMIT_PCT)
                    ),
                    weekly_loss_limit=self._to_pct(
                        pj.get(self._KEY_WEEKLY_LOSS, self.DEFAULT_WEEKLY_LOSS_LIMIT_PCT)
                    ),
                    consecutive_losses_limit=int(
                        pj.get(self._KEY_CONSECUTIVE_LOSSES, self.DEFAULT_CONSECUTIVE_LOSSES_LIMIT)
                    ),
                    max_drawdown=self._to_pct(
                        pj.get(self._KEY_MAX_DRAWDOWN, self.DEFAULT_MAX_DRAWDOWN_PCT)
                    ),
                    correlation_threshold=float(
                        pj.get(self._KEY_CORRELATION, self.DEFAULT_CORRELATION_THRESHOLD)
                    ),
                    kill_switch_threshold=self._to_pct(
                        pj.get(self._KEY_KILL_SWITCH_THRESHOLD, self.DEFAULT_KILL_SWITCH_THRESHOLD)
                    ),
                    kill_switch_active=bool(
                        pj.get(self._KEY_KILL_SWITCH_ACTIVE, False)
                    ),
                )

        return RiskRules(
            daily_loss_limit=self.DEFAULT_DAILY_LOSS_LIMIT_PCT,
            weekly_loss_limit=self.DEFAULT_WEEKLY_LOSS_LIMIT_PCT,
            consecutive_losses_limit=self.DEFAULT_CONSECUTIVE_LOSSES_LIMIT,
            max_drawdown=self.DEFAULT_MAX_DRAWDOWN_PCT,
            correlation_threshold=self.DEFAULT_CORRELATION_THRESHOLD,
            kill_switch_threshold=self.DEFAULT_KILL_SWITCH_THRESHOLD,
            kill_switch_active=False,
        )
