"""RunHistoryStatsRepository — queries DB to build RunHistoryStats for live_small preconditions."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select, func, and_
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.risk import StrategyRiskPolicyBinding, CapitalPool
from app.domain.strategy import StrategyVersion
from app.models.strategy import BacktestRun
from app.models.dryrun import DryRunRun
from app.schemas.live_small import RunHistoryStats


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class RunHistoryStatsRepository:
    def __init__(self, session: Session):
        self._s = session

    def build_stats(self, strategy_version_id: uuid.UUID) -> RunHistoryStats:
        version = self._s.get(StrategyVersion, strategy_version_id)
        if not version:
            return RunHistoryStats()

        vid_str = str(strategy_version_id)

        return RunHistoryStats(
            strategy_version_status=version.status,
            backtest_count=self._count_backtests(vid_str),
            dryrun_count=self._count_dryruns(vid_str),
            longest_dryrun_hours=self._longest_dryrun_hours(vid_str),
            dryrun_had_failure=self._dryrun_had_failure(vid_str),
            has_risk_policy_binding=self._has_risk_binding(strategy_version_id),
            capital_pool_requires_human_confirm=self._pool_requires_confirm(strategy_version_id),
            active_live_small_run_exists=self._has_active_live_small(strategy_version_id),
        )

    def _count_backtests(self, vid_str: str) -> int:
        stmt = select(func.count()).select_from(BacktestRun).where(
            BacktestRun.strategy_version_id == vid_str
        )
        return self._s.scalar(stmt) or 0

    def _count_dryruns(self, vid_str: str) -> int:
        stmt = select(func.count()).select_from(DryRunRun).where(
            DryRunRun.strategy_version_id == vid_str
        )
        return self._s.scalar(stmt) or 0

    def _longest_dryrun_hours(self, vid_str: str) -> float:
        stmt = (
            select(DryRunRun)
            .where(DryRunRun.strategy_version_id == vid_str)
            .where(DryRunRun.started_at.isnot(None))
        )
        runs = list(self._s.scalars(stmt).all())
        if not runs:
            return 0.0
        max_hours = 0.0
        now = _utcnow()
        for r in runs:
            start = r.started_at
            end = r.stopped_at or now
            hours = (end - start).total_seconds() / 3600
            max_hours = max(max_hours, hours)
        return round(max_hours, 1)

    def _dryrun_had_failure(self, vid_str: str) -> bool:
        stmt = select(func.count()).select_from(DryRunRun).where(
            and_(
                DryRunRun.strategy_version_id == vid_str,
                DryRunRun.status.in_(["failed"]),
            )
        )
        return (self._s.scalar(stmt) or 0) > 0

    def _has_risk_binding(self, version_id: uuid.UUID) -> bool:
        stmt = select(func.count()).select_from(StrategyRiskPolicyBinding).where(
            and_(
                StrategyRiskPolicyBinding.strategy_version_id == version_id,
                StrategyRiskPolicyBinding.mode == "live_small",
            )
        )
        return (self._s.scalar(stmt) or 0) > 0

    def _pool_requires_confirm(self, version_id: uuid.UUID) -> bool:
        stmt = (
            select(CapitalPool.requires_human_confirm)
            .join(
                StrategyRiskPolicyBinding,
                StrategyRiskPolicyBinding.capital_pool_id == CapitalPool.id,
            )
            .where(
                and_(
                    StrategyRiskPolicyBinding.strategy_version_id == version_id,
                    StrategyRiskPolicyBinding.mode == "live_small",
                )
            )
            .limit(1)
        )
        result = self._s.scalar(stmt)
        return bool(result) if result is not None else False

    def _has_active_live_small(self, version_id: uuid.UUID) -> bool:
        stmt = select(func.count()).select_from(StrategyRun).where(
            and_(
                StrategyRun.strategy_version_id == version_id,
                StrategyRun.mode == "live_small",
                StrategyRun.status.in_(["created", "starting", "running"]),
            )
        )
        return (self._s.scalar(stmt) or 0) > 0
