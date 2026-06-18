"""StrategyWorkspaceAggregator — BFF service producing a single WorkspaceSnapshotResponse.

Aggregates 11 data sources for the strategy workbench. Redis-cached (5s TTL).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.activity_log import StrategyActivityLog
from app.domain.execution import StrategyRun
from app.domain.strategy import StrategyV2, StrategyVersion
from app.models.strategy import BacktestRun
from app.repositories.strategy_repository import StrategyRepository
from app.schemas.per_strategy_readiness import PerStrategyReadinessResponse
from app.schemas.strategy_binding import StrategyBindingResponse
from app.schemas.strategy_v2 import StrategyV2Response, StrategyVersionResponse
from app.schemas.strategy_workspace import (
    ActivityEntry,
    BacktestRunSummary,
    DataDependencies,
    SignalLogicSummary,
    StrategyRunSummary,
    WorkspaceSnapshotResponse,
)
from app.services.live_readiness_service import LiveReadinessService
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_binding_service import StrategyBindingService

logger = logging.getLogger(__name__)

CACHE_PREFIX = "pulsedesk:workspace:"
CACHE_TTL = 5


# ── Pure helper functions ─────────────────────────────────────────────


def summarize_dsl(rule_dsl: dict) -> SignalLogicSummary:
    """Translate rule_dsl entry/exit rules into human-readable text summary."""
    entry = rule_dsl.get("entry", {}) or {}
    rules = entry.get("rules", []) or []
    logic = entry.get("logic", "AND")
    fragments = []
    for r in rules:
        ind = r.get("indicator") or "?"
        op = r.get("operator") or "?"
        val = r.get("value")
        val_s = "?" if val is None else str(val)
        fragments.append(f"{ind}{op}{val_s}")
    entry_text = f" {logic} ".join(fragments) if fragments else "(empty)"

    exit_block = rule_dsl.get("exit", {}) or {}
    exit_rules = exit_block.get("rules", []) or []
    exit_text = " OR ".join(
        f"{(r.get('indicator') or '?')}"
        f"{(r.get('operator') or '?')}"
        f"{('?' if r.get('value') is None else str(r.get('value')))}"
        for r in exit_rules
    ) or "(empty)"

    filters = rule_dsl.get("filters") or []
    return SignalLogicSummary(
        entry_text=entry_text,
        exit_text=exit_text,
        filter_count=len(filters),
    )


def extract_data_dependencies(rule_dsl: dict) -> DataDependencies:
    """Extract symbols, timeframes, indicators, and signal_sources from rule_dsl."""
    symbols = rule_dsl.get("symbols") or []
    timeframe = rule_dsl.get("timeframe")
    timeframes = [timeframe] if timeframe else []

    indicators: list[str] = []
    # Collect from entry rules
    entry = rule_dsl.get("entry", {}) or {}
    for r in (entry.get("rules", []) or []):
        ind = r.get("indicator")
        if ind and ind not in indicators:
            indicators.append(ind)
    # Collect from filters
    for f in (rule_dsl.get("filters", []) or []):
        ind = f.get("indicator")
        if ind and ind not in indicators:
            indicators.append(ind)

    # Best-effort signal sources
    signal_sources: list[str] = []
    # Check nodes in the DSL that might have a "source" field
    nodes = rule_dsl.get("nodes") or []
    for node in nodes:
        source = node.get("source")
        if source and source not in signal_sources:
            signal_sources.append(source)

    return DataDependencies(
        symbols=symbols,
        timeframes=timeframes,
        indicators=indicators,
        signal_sources=signal_sources,
    )


# ── Aggregator ────────────────────────────────────────────────────────


class StrategyWorkspaceAggregator:
    """BFF aggregator that produces a single WorkspaceSnapshotResponse.

    Parallelises 6 sub-queries: strategy, versions, bindings, backtests,
    dryruns, activity. Redis cache (5s TTL) to absorb page-refresh bursts.
    """

    def __init__(
        self,
        db: Session,
        redis_store: RuntimeRedisStore | None = None,
        readiness_svc: LiveReadinessService | None = None,
        binding_svc: StrategyBindingService | None = None,
        activity_svc: StrategyActivityService | None = None,
    ):
        self._db = db
        self._redis = redis_store
        self._readiness_svc = readiness_svc or LiveReadinessService()
        self._binding_svc = binding_svc or StrategyBindingService(
            db, StrategyActivityService(db),
        )
        self._activity_svc = activity_svc or StrategyActivityService(db)
        self._repo = StrategyRepository(db)

    async def get_snapshot(
        self,
        strategy_id: uuid.UUID,
        *,
        force_fresh: bool = False,
    ) -> WorkspaceSnapshotResponse:
        """Return a fully assembled WorkspaceSnapshotResponse.

        Cache key: pulsedesk:workspace:{strategy_id}, TTL 5s.
        Cache write failures are logged and do not fail the request.
        """
        # ── Check cache ────────────────────────────────────────────
        if not force_fresh and self._redis is not None:
            try:
                cached = await self._redis._get(f"{CACHE_PREFIX}{strategy_id}")
                if cached is not None:
                    return WorkspaceSnapshotResponse.model_validate(cached)
            except Exception:
                logger.warning("cache read failed for workspace %s", strategy_id)

        # ── Build from DB ──────────────────────────────────────────
        snapshot = self._build_from_db(strategy_id)

        # ── Write cache (best-effort) ──────────────────────────────
        if self._redis is not None:
            try:
                await self._redis._set(
                    f"{CACHE_PREFIX}{strategy_id}",
                    snapshot.model_dump(mode="json"),
                    ttl=CACHE_TTL,
                )
            except Exception:
                logger.warning("cache write failed for workspace %s", strategy_id)

        return snapshot

    def _build_from_db(self, strategy_id: uuid.UUID) -> WorkspaceSnapshotResponse:
        """Build the full snapshot from 6 sub-queries."""
        # 1. Strategy identity
        strategy = self._repo.get_strategy_by_id(strategy_id)
        if strategy is None:
            raise ValueError(f"strategy not found: {strategy_id}")

        # 2. Versions (max 10, desc by version_no)
        versions = self._repo.list_versions(strategy_id, limit=10)
        latest_version = versions[0] if versions else None

        # 3. Bindings (all versions) — eagerly load related data for response
        raw_bindings = self._binding_svc.list_for_strategy(strategy_id)
        bindings = self._build_binding_responses(raw_bindings)

        # 4. Recent backtests (max 5, desc by completed_at)
        recent_backtests = self._query_recent_backtests(strategy_id)

        # 5. Recent dryruns (max 5, desc by created_at)
        recent_dryruns = self._query_recent_dryruns(strategy_id)

        # 6. Activity (max 10)
        activity_rows = self._activity_svc.list_recent(strategy_id, limit=10)

        # ── Derived fields ─────────────────────────────────────────
        # Readiness
        readiness = self._readiness_svc.compute_for_strategy(
            strategy_id=strategy_id,
            db=self._db,
        )

        # Signal logic summary + data dependencies from latest version
        if latest_version and latest_version.rule_dsl:
            signal_logic_summary = summarize_dsl(latest_version.rule_dsl)
            data_dependencies = extract_data_dependencies(latest_version.rule_dsl)
        else:
            signal_logic_summary = SignalLogicSummary()
            data_dependencies = DataDependencies()

        # ── Assemble response ──────────────────────────────────────
        return WorkspaceSnapshotResponse(
            strategy=StrategyV2Response.model_validate(strategy),
            versions=[StrategyVersionResponse.model_validate(v) for v in versions],
            latest_version_id=latest_version.id if latest_version else None,
            bindings=[StrategyBindingResponse.model_validate(b) for b in bindings],
            recent_backtests=recent_backtests,
            recent_dryruns=recent_dryruns,
            readiness=readiness,
            activity=[ActivityEntry.model_validate(a) for a in activity_rows],
            signal_logic_summary=signal_logic_summary,
            data_dependencies=data_dependencies,
        )

    def _build_binding_responses(
        self,
        raw_bindings: list,
    ) -> list[StrategyBindingResponse]:
        """Build StrategyBindingResponse from raw ORM rows, loading joined data."""
        from app.domain.risk import CapitalPool, RiskPolicyVersion, RiskPolicy
        from app.domain.strategy import StrategyVersion

        results: list[StrategyBindingResponse] = []
        for b in raw_bindings:
            version = (
                self._db.query(StrategyVersion)
                .filter(StrategyVersion.id == b.strategy_version_id)
                .first()
            )
            rpv = (
                self._db.query(RiskPolicyVersion)
                .filter(RiskPolicyVersion.id == b.risk_policy_version_id)
                .first()
            )
            rp_name = ""
            rp_policy_json = {}
            if rpv:
                rp = (
                    self._db.query(RiskPolicy)
                    .filter(RiskPolicy.id == rpv.risk_policy_id)
                    .first()
                )
                if rp:
                    rp_name = rp.name
                rp_policy_json = rpv.policy_json

            pool = (
                self._db.query(CapitalPool)
                .filter(CapitalPool.id == b.capital_pool_id)
                .first()
            )

            results.append(
                StrategyBindingResponse(
                    id=b.id,
                    strategy_version_id=b.strategy_version_id,
                    version_no=version.version_no if version else 0,
                    risk_policy={
                        "id": rpv.id if rpv else uuid.uuid4(),
                        "name": rp_name,
                        "version_no": rpv.version_no if rpv else 0,
                        "policy_json_summary": rp_policy_json,
                    },
                    capital_pool={
                        "id": pool.id if pool else uuid.uuid4(),
                        "name": pool.name if pool else "",
                        "pool_type": pool.pool_type if pool else "",
                        "total_budget": float(pool.total_budget) if pool else 0.0,
                        "currency": pool.currency if pool else "",
                        "remaining_budget": float(pool.total_budget) if pool else 0.0,
                    },
                    mode=b.mode,
                    created_at=b.created_at,
                )
            )
        return results

    def _query_recent_backtests(self, strategy_id: uuid.UUID) -> list[BacktestRunSummary]:
        """Fetch max 5 backtest runs for this strategy, desc by completed_at."""
        rows = (
            self._db.query(BacktestRun)
            .filter(BacktestRun.strategy_uuid == strategy_id)
            .order_by(BacktestRun.completed_at.desc().nullslast())
            .limit(5)
            .all()
        )
        result: list[BacktestRunSummary] = []
        for r in rows:
            # BacktestRun.id is an int, started_at is not a column on this model
            # but we map what exists
            result.append(
                BacktestRunSummary(
                    id=r.id,
                    started_at=None,  # BacktestRun doesn't have started_at
                    completed_at=r.completed_at,
                    status=r.status,
                    total_return=r.total_return,
                    win_rate=r.win_rate,
                    max_drawdown=r.max_drawdown,
                    sharpe_ratio=r.sharpe_ratio,
                )
            )
        return result

    def _query_recent_dryruns(self, strategy_id: uuid.UUID) -> list[StrategyRunSummary]:
        """Fetch max 5 StrategyRun rows for this strategy, mode in (dry_run, paper)."""
        # Join through StrategyVersion to filter by strategy_id
        version_ids_subq = (
            self._db.query(StrategyVersion.id)
            .filter(StrategyVersion.strategy_id == strategy_id)
            .scalar_subquery()
        )
        rows = (
            self._db.query(StrategyRun)
            .filter(
                StrategyRun.strategy_version_id.in_(version_ids_subq),
                StrategyRun.mode.in_(["dry_run", "paper"]),
            )
            .order_by(StrategyRun.created_at.desc())
            .limit(5)
            .all()
        )
        return [StrategyRunSummary.model_validate(r) for r in rows]
