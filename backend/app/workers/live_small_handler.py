"""RequestLiveSmallHandler — validate preconditions and create pending live_small run."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.execution import StrategyRun
from app.domain.risk import CapitalPool
from app.domain.strategy import StrategyVersion
from app.domain.enums import StrategyVersionStatus, StrategyRunMode
from app.schemas.live_small import CapitalPoolParams
from app.services.live_small.launcher import LIVE_SMALL_API_PORT, LiveSmallLauncher, build_live_small_config
from app.services.strategy_transition import validate_transition, InvalidTransitionError
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _to_uuid(val: Any) -> uuid.UUID:
    return val if isinstance(val, uuid.UUID) else uuid.UUID(str(val))


class RequestLiveSmallHandler(CommandHandler):
    def __init__(self, launcher: LiveSmallLauncher | None = None) -> None:
        self._launcher = launcher or LiveSmallLauncher()

    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        strategy_version_id = _to_uuid(payload["strategy_version_id"])
        capital_pool_id = payload.get("capital_pool_id")
        if not capital_pool_id:
            raise RuntimeError("capital pool required for live_small")

        version = session.get(StrategyVersion, strategy_version_id)
        if version is None:
            raise RuntimeError(f"StrategyVersion {strategy_version_id} not found")

        from_status = StrategyVersionStatus(version.status)
        if from_status != StrategyVersionStatus.LIVE_PENDING:
            raise RuntimeError(
                f"Version must be in live_pending to request live_small, got {from_status.value}"
            )

        try:
            validate_transition(from_status, StrategyVersionStatus.LIVE_SMALL)
        except InvalidTransitionError as e:
            raise RuntimeError(str(e))

        pool = session.get(CapitalPool, _to_uuid(capital_pool_id))
        if pool is None:
            raise RuntimeError(f"CapitalPool {capital_pool_id} not found")
        if pool.allow_leverage or pool.allow_auto_trade or not pool.requires_human_confirm:
            raise RuntimeError("capital pool is not safe for live_small")

        pool_params = CapitalPoolParams(
            total_budget=float(pool.total_budget),
            max_position_pct_per_trade=float(pool.max_position_pct_per_trade),
            max_total_exposure_pct=float(pool.max_total_exposure_pct),
            max_daily_loss_pct=float(pool.max_daily_loss_pct),
            max_drawdown_pct=float(pool.max_drawdown_pct),
            allow_leverage=False,
            allow_auto_trade=False,
            requires_human_confirm=True,
            currency=pool.currency or "USDT",
        )
        run_id = str(command.id).replace("-", "")[:16]
        config = build_live_small_config(
            version.rule_dsl or {},
            pool_params,
            exchange_name=str(payload.get("exchange_name") or "binance"),
            api_port=int(payload.get("api_port") or LIVE_SMALL_API_PORT),
            run_id=run_id,
            max_open_trades_cap=payload.get("max_open_trades_cap"),
        )
        launched = self._launcher.start(config, run_id=run_id)

        run = StrategyRun(
            strategy_version_id=version.id,
            capital_pool_id=pool.id,
            tenant_id=payload.get("tenant_id"),
            mode=StrategyRunMode.LIVE_SMALL.value,
            status="running",
        )
        session.add(run)
        session.flush()

        version.status = StrategyVersionStatus.LIVE_SMALL.value
        session.flush()

        return {
            "strategy_run_id": str(run.id),
            "strategy_version_id": str(version.id),
            "mode": "live_small",
            "status": "running",
            "dry_run": False,
            "pid": launched.get("pid"),
            "api_port": launched.get("api_port"),
            "exchange_urls": launched.get("exchange_urls"),
        }
