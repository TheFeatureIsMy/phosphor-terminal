"""StrategyBinding CRUD service with mode-pool consistency + in-use protection."""
from __future__ import annotations

import uuid

from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.risk import CapitalPool, RiskPolicyVersion, StrategyRiskPolicyBinding
from app.domain.strategy import StrategyVersion
from app.services.strategy_binding_errors import (
    BindingInUseError,
    DuplicateBindingError,
    PolicyArchivedError,
    PoolMismatchError,
)
from app.services.strategy_activity_service import StrategyActivityService

_LIVE_SMALL_POOLS = {"live_small"}
_NON_LIVE_POOLS = {"paper", "main", "high_risk_hunt"}


class StrategyBindingService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def list_for_strategy(self, strategy_id: uuid.UUID) -> list[StrategyRiskPolicyBinding]:
        stmt = (
            select(StrategyRiskPolicyBinding)
            .join(StrategyVersion, StrategyVersion.id == StrategyRiskPolicyBinding.strategy_version_id)
            .where(StrategyVersion.strategy_id == strategy_id)
        )
        return list(self._db.scalars(stmt).all())

    def create(
        self,
        *,
        strategy_id: uuid.UUID,
        strategy_version_id: uuid.UUID,
        risk_policy_version_id: uuid.UUID,
        capital_pool_id: uuid.UUID,
        mode: str,
        actor: str,
    ) -> StrategyRiskPolicyBinding:
        # validate policy
        rpv = self._db.get(RiskPolicyVersion, risk_policy_version_id)
        if not rpv:
            raise ValueError("risk_policy_version not found")
        if rpv.status == "archived":
            raise PolicyArchivedError(f"policy version {risk_policy_version_id} is archived")

        # validate pool/mode
        pool = self._db.get(CapitalPool, capital_pool_id)
        if not pool:
            raise ValueError("capital_pool not found")
        if mode == "live_small" and pool.pool_type not in _LIVE_SMALL_POOLS:
            raise PoolMismatchError(f"mode=live_small requires live_small pool; got {pool.pool_type}")
        if mode in {"backtest", "dry_run", "shadow"} and pool.pool_type not in _NON_LIVE_POOLS:
            raise PoolMismatchError(f"mode={mode} cannot use {pool.pool_type} pool")

        # duplicate check
        dup = self._db.scalar(
            select(StrategyRiskPolicyBinding).where(
                and_(
                    StrategyRiskPolicyBinding.strategy_version_id == strategy_version_id,
                    StrategyRiskPolicyBinding.mode == mode,
                )
            )
        )
        if dup is not None:
            raise DuplicateBindingError(f"binding (version={strategy_version_id}, mode={mode}) exists")

        b = StrategyRiskPolicyBinding(
            strategy_version_id=strategy_version_id,
            risk_policy_version_id=risk_policy_version_id,
            capital_pool_id=capital_pool_id,
            mode=mode,
        )
        self._db.add(b)
        self._db.flush()

        self._activity.record(
            strategy_id, "binding_added",
            f"bound to {rpv.risk_policy_id} / {pool.name} ({mode})",
            actor=actor, ref_kind="binding", ref_id=b.id,
            delta={"mode": mode, "policy_version_id": str(rpv.id), "pool_id": str(pool.id)},
        )
        return b

    def delete(self, binding_id: uuid.UUID, *, actor: str) -> None:
        b = self._db.get(StrategyRiskPolicyBinding, binding_id)
        if not b:
            raise ValueError(f"binding not found: {binding_id}")

        # in-use check: any active StrategyRun with same (version, mode)
        in_use = self._db.scalar(
            select(StrategyRun).where(
                and_(
                    StrategyRun.strategy_version_id == b.strategy_version_id,
                    StrategyRun.mode == b.mode,
                    StrategyRun.status.in_(["running", "starting", "stopping", "degraded"]),
                )
            )
        )
        if in_use is not None:
            raise BindingInUseError(f"binding {binding_id} has active run {in_use.id}")

        version = self._db.get(StrategyVersion, b.strategy_version_id)
        strategy_id = version.strategy_id if version else None

        self._db.delete(b)
        self._db.flush()

        if strategy_id:
            self._activity.record(
                strategy_id, "binding_removed", f"binding {binding_id} removed",
                actor=actor, ref_kind="binding", ref_id=binding_id,
            )
