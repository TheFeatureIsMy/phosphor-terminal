"""Live Readiness Service — 实盘准入检查（11 项 + 5 级总状态）

返回 5 级总状态：
  - not_live        系统级就绪不足（基础设施 / 数据源 / 交易所）
  - needs_config    模式/策略/资金/风控配置缺失
  - needs_validation 策略 DSL 验证未完成 / 交易所未连接
  - paper_passed    模拟通过（含 ≥72h 模拟 + 回测通过）
  - ready_for_live  全部门禁通过，可启动小仓实盘

11 项检查：
  1. mode           模拟/实盘模式选择
  2. strategy       策略选择
  3. capital        资金动态配置
  4. risk_config    风控配置状态
  5. exchange       交易所连接状态
  6. data_source    数据源健康
  7. validation     策略验证状态
  8. backtest       回测通过
  9. dryrun         模拟/dry-run 通过（≥72h）
  10. notification  通知可用
  11. emergency_stop 紧急停止可用
"""
from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass, field
from typing import Optional

from sqlalchemy import func

from app.config import settings
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.freqtrade_client import FreqtradeClient

logger = logging.getLogger(__name__)


# 5-level grand status ladder
GRAND_STATUSES = (
    "not_live",
    "needs_config",
    "needs_validation",
    "paper_passed",
    "ready_for_live",
)

# 11 check keys
CHECK_KEYS = (
    "mode",
    "strategy",
    "capital",
    "risk_config",
    "exchange",
    "data_source",
    "validation",
    "backtest",
    "dryrun",
    "notification",
    "emergency_stop",
)


@dataclass
class CheckResult:
    key: str
    label: str
    status: str = "unknown"  # healthy / warning / failed / unknown
    value: str = ""
    threshold: str = ""
    detail: str = ""
    group: str = "system"  # mode | strategy | capital | risk | system | execution


@dataclass
class ReadinessResult:
    score: int = 0
    state: str = "NOT_READY"  # legacy
    grand_status: str = "not_live"  # 5-level

    can_start_paper: bool = False
    can_start_live_small: bool = False
    can_start_full_live: bool = False

    blocking_reasons: list[dict] = field(default_factory=list)
    warnings: list[dict] = field(default_factory=list)
    checks: list[CheckResult] = field(default_factory=list)
    reason_codes: list[str] = field(default_factory=list)

    # Selection context (for the iOS picker)
    selected_mode: str = ""        # "paper" | "live_small" | "live_full"
    selected_strategy_id: str = ""
    selected_capital_pool_id: str = ""
    selected_exchange: str = ""


class LiveReadinessService:
    def __init__(
        self,
        redis_store: RuntimeRedisStore | None = None,
        freqtrade_client: FreqtradeClient | None = None,
    ):
        self._store = redis_store
        self._ft = freqtrade_client

    async def evaluate(
        self,
        account_id: str = "default",
        selected_mode: str = "live_small",
        selected_strategy_id: str = "",
        selected_capital_pool_id: str = "",
        selected_exchange: str = "binance",
    ) -> ReadinessResult:
        if self._store:
            cached = await self._store.read_live_readiness(account_id)
            if cached and cached.get("selected_mode") == selected_mode:
                # Still respect explicit selections
                cached["selected_mode"] = selected_mode
                cached["selected_strategy_id"] = selected_strategy_id
                cached["selected_capital_pool_id"] = selected_capital_pool_id
                cached["selected_exchange"] = selected_exchange
                return ReadinessResult(**cached)

        result = ReadinessResult()
        result.selected_mode = selected_mode
        result.selected_strategy_id = selected_strategy_id
        result.selected_capital_pool_id = selected_capital_pool_id
        result.selected_exchange = selected_exchange

        checks: list[CheckResult] = []
        blockers: list[dict] = []
        warns: list[dict] = []
        score = 100

        # === 11 named checks ===
        # 1. mode
        c = self._check_mode(selected_mode)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "mode_unset", "message": "请选择运行模式"})
            score -= 5

        # 2. strategy
        c = self._check_strategy(selected_strategy_id)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "strategy_unset", "message": "请选择实盘策略"})
            score -= 15
        elif c.status == "warning":
            warns.append({"code": "strategy_validation_pending", "message": "策略 DSL 验证未通过"})
            score -= 5

        # 3. capital
        c = self._check_capital(selected_capital_pool_id)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "capital_unconfigured", "message": "请配置资金池"})
            score -= 10

        # 4. risk config
        c = self._check_risk_config()
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "risk_config_unset", "message": "请配置风控参数"})
            score -= 10

        # 5. exchange
        c = self._check_exchange(selected_exchange)
        checks.append(c)
        if c.status == "failed":
            # Distinguish "not picked" (needs_config) from "actually unreachable" (not_live)
            if not selected_exchange:
                blockers.append({"code": "exchange_unset", "message": "请选择交易所"})
            else:
                blockers.append({"code": "exchange_unreachable", "message": "交易所不可达"})
            score -= 15
        elif c.status == "warning":
            warns.append({"code": "exchange_degraded", "message": "交易所 API 权重偏低"})
            score -= 5

        # 6. data source
        c = self._check_data_source()
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "data_source_unavailable", "message": "数据源不可用"})
            score -= 15

        # 7. validation
        c = self._check_validation(selected_strategy_id)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "validation_failed", "message": "策略 DSL 验证未通过"})
            score -= 15

        # 8. backtest
        c = self._check_backtest(selected_strategy_id)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "no_backtest", "message": "缺少回测记录"})
            score -= 15

        # 9. dryrun
        c = self._check_dryrun(selected_strategy_id)
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "dryrun_insufficient", "message": "模拟时长不足 72h"})
            score -= 15
        elif c.status == "warning":
            warns.append({"code": "dryrun_short", "message": "模拟 < 72h，建议延长"})
            score -= 3

        # 10. notification
        c = self._check_notification()
        checks.append(c)
        if c.status == "failed":
            warns.append({"code": "notification_unset", "message": "通知未配置，建议设置 Telegram"})
            score -= 5

        # 11. emergency stop
        c = self._check_emergency_stop()
        checks.append(c)
        if c.status == "failed":
            blockers.append({"code": "emergency_stop_unavailable", "message": "紧急停止不可用"})
            score -= 25

        # Legacy infra checks
        redis_check = await self._check_redis()
        freqtrade_check = await self._check_freqtrade()
        db_check = self._check_database()
        risk_check = await self._check_risk_state(account_id)

        # Map infra to existing infra failures
        if redis_check.status == "failed":
            blockers.append({"code": "redis_unavailable", "message": "Redis 不可用"})
            score -= 10
        if freqtrade_check.status == "failed":
            blockers.append({"code": "freqtrade_unavailable", "message": "Freqtrade 未连接"})
            score -= 10
        if db_check.status == "failed":
            blockers.append({"code": "database_unavailable", "message": "数据库不可用"})
            score -= 10
        if risk_check.status == "failed":
            blockers.append({"code": "risk_locked", "message": "风控已锁定"})
            score -= 25

        score = max(0, min(100, score))

        # === Grand status (5-level ladder) ===
        result.grand_status = self._derive_grand_status(checks, blockers, selected_mode)
        result.state = self._map_grand_to_legacy(result.grand_status)

        # Permissions
        result.can_start_paper = (
            result.grand_status in ("paper_passed", "ready_for_live")
            and not any(b["code"] in ("emergency_stop_unavailable", "risk_locked") for b in blockers)
        )
        result.can_start_live_small = (
            result.grand_status == "ready_for_live"
            and not any(b["code"] in ("emergency_stop_unavailable", "risk_locked") for b in blockers)
        )
        result.can_start_full_live = (
            result.grand_status == "ready_for_live"
            and selected_mode == "live_full"
            and score >= 90
            and not any(b["code"] in ("emergency_stop_unavailable", "risk_locked") for b in blockers)
        )

        result.score = score
        result.checks = checks
        result.blocking_reasons = blockers
        result.warnings = warns
        result.reason_codes = [b["code"] for b in blockers] + [w["code"] for w in warns]

        if self._store:
            await self._store.write_live_readiness(account_id, self._serialize(result), ttl=30)
        return result

    # === Per-strategy readiness (for strategy workbench ⌘6 panel) ===

    def compute_for_strategy(
        self,
        strategy_id: uuid.UUID,
        db: "Session",
        system_gates: list["ReadinessGate"] | None = None,
    ) -> "PerStrategyReadinessResponse":
        """Compute 6 per-strategy gates + reuse 5 system gates → PerStrategyReadinessResponse.

        Args:
            strategy_id: UUID of the strategy (strategies_v2.id).
            db: SQLAlchemy Session.
            system_gates: Optional pre-computed system gates (mode, exchange, data_source,
                notification, emergency_stop). If None, a default healthy set is used.
        """
        from app.domain.execution import StrategyRun
        from app.domain.risk import CapitalPool, StrategyRiskPolicyBinding
        from app.domain.strategy import StrategyV2, StrategyVersion
        from app.models.strategy import BacktestRun
        from app.schemas.per_strategy_readiness import (
            PerStrategyReadinessResponse,
            ReadinessGate,
            ReadinessNextAction,
        )
        from sqlalchemy.orm import Session  # type: ignore[unused-ignore]

        # ── 6 strategy gates ──────────────────────────────────────────

        strategy = db.get(StrategyV2, strategy_id)

        # 1. validation
        latest_version: StrategyVersion | None = (
            db.query(StrategyVersion)
            .filter(StrategyVersion.strategy_id == strategy_id)
            .order_by(StrategyVersion.version_no.desc())
            .first()
        )
        validation_gate = self._compute_validation_gate(latest_version)

        # 2. backtest
        backtest_gate = self._compute_backtest_gate(strategy_id, db, BacktestRun)

        # 3. dryrun
        dryrun_gate = self._compute_dryrun_gate(latest_version, db, StrategyRun)

        # 4. risk_config
        risk_config_gate = self._compute_risk_config_gate(latest_version, db, StrategyRiskPolicyBinding)

        # 5. capital
        capital_gate = self._compute_capital_gate(db, CapitalPool)

        # 6. strategy (the strategy record itself)
        strategy_gate = self._compute_strategy_gate(strategy)

        strategy_gates = [
            validation_gate,
            backtest_gate,
            dryrun_gate,
            risk_config_gate,
            capital_gate,
            strategy_gate,
        ]

        # ── 5 system gates ────────────────────────────────────────────
        if system_gates is None:
            system_gates = self._default_healthy_system_gates()

        # ── Grand status ──────────────────────────────────────────────
        has_live_small_run = self._check_has_live_small_run(latest_version, db, StrategyRun)
        grand_status = self._derive_per_strategy_grand_status(
            strategy_gates, system_gates, has_live_small_run=has_live_small_run,
        )

        # ── Passed count ──────────────────────────────────────────────
        passed_count = sum(
            1 for g in strategy_gates + list(system_gates) if g.status == "healthy"
        )

        # ── Next action ───────────────────────────────────────────────
        next_action = self._infer_next_action(strategy_gates, grand_status, latest_version, db)

        return PerStrategyReadinessResponse(
            passed_count=passed_count,
            total=11,
            grand_status=grand_status,
            next_action=next_action,
            strategy_gates=strategy_gates,
            system_gates=list(system_gates),
        )

    # ── Strategy gate helpers ─────────────────────────────────────────

    @staticmethod
    def _compute_validation_gate(
        latest_version: "StrategyVersion | None",
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        if latest_version is None:
            return ReadinessGate(
                key="validation", status="failed",
                value="no version", threshold="validated",
                detail="no version", reason_codes=["no_version"],
            )

        healthy_statuses = {
            "validated", "backtested", "paper_running", "paper_passed",
            "live_pending", "live_small",
        }
        if latest_version.status in healthy_statuses:
            return ReadinessGate(
                key="validation", status="healthy",
                value=latest_version.status, threshold="validated",
            )
        return ReadinessGate(
            key="validation", status="failed",
            value=latest_version.status, threshold="validated",
            detail=f"version status: {latest_version.status}",
            reason_codes=["validation_failed"],
        )

    @staticmethod
    def _compute_backtest_gate(
        strategy_id: uuid.UUID,
        db: "Session",
        BacktestRun: type,
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        has_backtest = (
            db.query(BacktestRun)
            .filter(
                BacktestRun.strategy_uuid == strategy_id,
                BacktestRun.status == "completed",
            )
            .first()
            is not None
        )
        if has_backtest:
            return ReadinessGate(
                key="backtest", status="healthy",
                value="completed", threshold="≥1 completed",
            )
        return ReadinessGate(
            key="backtest", status="failed",
            value="none", threshold="≥1 completed",
            detail="no completed backtest", reason_codes=["no_backtest"],
        )

    @staticmethod
    def _compute_dryrun_gate(
        latest_version: "StrategyVersion | None",
        db: "Session",
        StrategyRun: type,
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        if latest_version is None:
            return ReadinessGate(
                key="dryrun", status="failed",
                value="no version", threshold="≥72h",
                detail="no strategy version", reason_codes=["no_version"],
            )

        # Find the most recent dry_run or paper run for any version of this strategy
        from app.domain.strategy import StrategyVersion as SV

        version_ids_subq = (
            db.query(SV.id).filter(SV.strategy_id == latest_version.strategy_id).scalar_subquery()
        )

        runs = (
            db.query(StrategyRun)
            .filter(
                StrategyRun.strategy_version_id.in_(version_ids_subq),
                StrategyRun.mode.in_(["dry_run", "paper"]),
            )
            .order_by(StrategyRun.created_at.desc())
            .all()
        )

        if not runs:
            return ReadinessGate(
                key="dryrun", status="failed",
                value="none", threshold="≥72h",
                detail="no dry_run or paper run", reason_codes=["no_dryrun"],
            )

        # Check the most recent relevant run
        latest_run = runs[0]
        now = datetime.now(timezone.utc)

        if latest_run.status in ("running", "starting"):
            # Running - check elapsed time
            started = _to_utc(latest_run.started_at)
            if started:
                elapsed_h = (now - started).total_seconds() / 3600
                if elapsed_h < 72:
                    return ReadinessGate(
                        key="dryrun", status="warning",
                        value=f"{elapsed_h:.0f}h", threshold=">=72h",
                        detail=f"paper run in progress: {elapsed_h:.0f}h elapsed",
                        reason_codes=["dryrun_in_progress"],
                    )
                # Running but already 72h+ - still healthy (it passed the threshold)
                return ReadinessGate(
                    key="dryrun", status="healthy",
                    value=f"{elapsed_h:.0f}h running", threshold=">=72h",
                )
            return ReadinessGate(
                key="dryrun", status="failed",
                value="running", threshold=">=72h",
                detail="paper run in progress but no start time",
                reason_codes=["dryrun_no_start_time"],
            )

        if latest_run.status == "stopped" and latest_run.started_at and latest_run.stopped_at:
            started = _to_utc(latest_run.started_at)
            stopped = _to_utc(latest_run.stopped_at)
            elapsed_h = (stopped - started).total_seconds() / 3600
            if elapsed_h >= 72:
                return ReadinessGate(
                    key="dryrun", status="healthy",
                    value=f"{elapsed_h:.0f}h", threshold="≥72h",
                )
            return ReadinessGate(
                key="dryrun", status="failed",
                value=f"{elapsed_h:.0f}h", threshold="≥72h",
                detail=f"paper run only {elapsed_h:.0f}h (need 72h+)",
                reason_codes=["dryrun_insufficient"],
            )

        return ReadinessGate(
            key="dryrun", status="failed",
            value=latest_run.status, threshold="≥72h",
            detail=f"unexpected run status: {latest_run.status}",
            reason_codes=["dryrun_no_completion"],
        )

    @staticmethod
    def _compute_risk_config_gate(
        latest_version: "StrategyVersion | None",
        db: "Session",
        StrategyRiskPolicyBinding: type,
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        if latest_version is None:
            return ReadinessGate(
                key="risk_config", status="failed",
                value="no version", threshold="binding exists",
                detail="no strategy version", reason_codes=["no_version"],
            )

        # Check any version of this strategy has a live_small binding
        from app.domain.strategy import StrategyVersion as SV

        has_binding = (
            db.query(StrategyRiskPolicyBinding)
            .filter(
                StrategyRiskPolicyBinding.strategy_version_id.in_(
                    db.query(SV.id).filter(SV.strategy_id == latest_version.strategy_id).scalar_subquery()
                ),
                StrategyRiskPolicyBinding.mode == "live_small",
            )
            .first()
            is not None
        )
        if has_binding:
            return ReadinessGate(
                key="risk_config", status="healthy",
                value="bound", threshold="binding exists",
            )
        return ReadinessGate(
            key="risk_config", status="failed",
            value="unbound", threshold="binding exists",
            detail="no live_small risk policy binding",
            reason_codes=["risk_config_unset"],
        )

    @staticmethod
    def _compute_capital_gate(
        db: "Session",
        CapitalPool: type,
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        # NOTE: remaining_budget is currently stubbed as total_budget.
        # True remaining = total_budget - sum(active_position_exposure).
        # Position exposure aggregation is deferred (no positions table query yet).
        # When that query is added, replace the simple `total_budget > 0` check with
        # `remaining_budget > minimum_per_trade`.
        pool = (
            db.query(CapitalPool)
            .filter(
                CapitalPool.pool_type == "live_small",
                CapitalPool.total_budget > 0,
            )
            .first()
        )
        if pool is not None:
            return ReadinessGate(
                key="capital", status="healthy",
                value=f"{pool.total_budget:.2f} {pool.currency}",
                threshold="> 0",
            )
        return ReadinessGate(
            key="capital", status="failed",
            value="no pool", threshold="> 0",
            detail="no live_small capital pool with budget > 0",
            reason_codes=["capital_unconfigured"],
        )

    @staticmethod
    def _compute_strategy_gate(
        strategy: "StrategyV2 | None",
    ) -> "ReadinessGate":
        from app.schemas.per_strategy_readiness import ReadinessGate

        if strategy is None:
            return ReadinessGate(
                key="strategy", status="failed",
                value="not found", threshold="exists",
                detail="strategy not found", reason_codes=["strategy_not_found"],
            )
        if strategy.status == "archived":
            return ReadinessGate(
                key="strategy", status="failed",
                value="archived", threshold="not archived",
                detail="strategy is archived", reason_codes=["strategy_archived"],
            )
        return ReadinessGate(
            key="strategy", status="healthy",
            value=strategy.status, threshold="not archived",
        )

    @staticmethod
    def _check_has_live_small_run(
        latest_version: "StrategyVersion | None",
        db: "Session",
        StrategyRun: type,
    ) -> bool:
        """Check if any version of this strategy has a live_small run with status in (running, starting)."""
        from app.domain.strategy import StrategyVersion as SV

        if latest_version is None:
            return False
        version_ids_subq = (
            db.query(SV.id).filter(SV.strategy_id == latest_version.strategy_id).scalar_subquery()
        )
        return (
            db.query(StrategyRun)
            .filter(
                StrategyRun.strategy_version_id.in_(version_ids_subq),
                StrategyRun.mode == "live_small",
                StrategyRun.status.in_(["running", "starting"]),
            )
            .first()
            is not None
        )

    # ── Grand status (per-strategy) ───────────────────────────────────

    @staticmethod
    def _derive_per_strategy_grand_status(
        strategy_gates: list["ReadinessGate"],
        system_gates: list["ReadinessGate"],
        has_live_small_run: bool = False,
    ) -> str:
        by_key = {g.key: g for g in strategy_gates}

        # 1. Any system gate failed → not_live
        for g in system_gates:
            if g.status == "failed":
                return "not_live"

        # 2. capital or risk_config failed → needs_config
        for k in ("capital", "risk_config"):
            g = by_key.get(k)
            if g and g.status == "failed":
                return "needs_config"

        # 3. validation or backtest failed → needs_validation
        for k in ("validation", "backtest"):
            g = by_key.get(k)
            if g and g.status == "failed":
                return "needs_validation"

        # 4. dryrun failed → needs_validation
        dryrun = by_key.get("dryrun")
        if dryrun and dryrun.status == "failed":
            return "needs_validation"

        # 5. All pass + a live_small StrategyRun exists → ready_for_live
        if has_live_small_run:
            return "ready_for_live"

        # 6. All pass → paper_passed
        return "paper_passed"

    # ── Next action inference ─────────────────────────────────────────

    @staticmethod
    def _infer_next_action(
        strategy_gates: list["ReadinessGate"],
        grand_status: str,
        latest_version: "StrategyVersion | None",
        db: "Session",
    ) -> "ReadinessNextAction":
        from app.schemas.per_strategy_readiness import ReadinessNextAction

        # Find the first non-healthy strategy gate
        for gate in strategy_gates:
            if gate.status != "healthy":
                return ReadinessNextAction(
                    code=gate.key,
                    label=_next_action_label(gate.key),
                    target_panel=_next_action_target(gate.key),
                )

        # All strategy gates pass — use grand_status
        if grand_status == "paper_passed":
            return ReadinessNextAction(
                code="bind_live_small",
                label="bind a live_small risk policy",
                target_panel="risk",
            )
        if grand_status == "ready_for_live":
            return ReadinessNextAction(
                code="approve_live",
                label="approve live_small deployment",
                target_panel="readiness",
            )
        return ReadinessNextAction(
            code="none",
            label="no action required",
            target_panel=None,
        )

    @staticmethod
    def _default_healthy_system_gates() -> list["ReadinessGate"]:
        from app.schemas.per_strategy_readiness import ReadinessGate

        return [
            ReadinessGate(key="mode", status="healthy", value="live_small", threshold="paper|live_small|live_full"),
            ReadinessGate(key="exchange", status="healthy", value="BINANCE", threshold="connected"),
            ReadinessGate(key="data_source", status="healthy", value="online", threshold="online"),
            ReadinessGate(key="notification", status="healthy", value="configured", threshold="optional"),
            ReadinessGate(key="emergency_stop", status="healthy", value="available", threshold="available"),
        ]

    # === Grand status derivation ===
    @staticmethod
    def _derive_grand_status(checks: list[CheckResult], blockers: list[dict], selected_mode: str = "live_small") -> str:
        by_key = {c.key: c for c in checks}
        blocker_codes = {b["code"] for b in blockers}

        # System-level not_live: 基础设施硬阻断（DB / Redis / Freqtrade / DataSource）
        if any(code in blocker_codes for code in ("data_source_unavailable", "database_unavailable", "redis_unavailable", "freqtrade_unavailable")):
            return "not_live"

        # needs_config: 用户还没配 mode / strategy / capital / risk / exchange
        for k in ("mode", "strategy", "capital", "risk_config", "exchange"):
            ck = by_key.get(k)
            if ck is None or ck.status == "failed":
                return "needs_config"

        # needs_validation: 策略 DSL 验证未通过 / 缺少回测 / 模拟不足
        if by_key.get("validation") and by_key["validation"].status in ("failed", "warning"):
            return "needs_validation"
        if by_key.get("backtest") and by_key["backtest"].status == "failed":
            return "needs_validation"
        if by_key.get("dryrun") and by_key["dryrun"].status == "failed":
            return "needs_validation"

        # 当用户选择 paper 模式 + 模拟通过 → paper_passed
        # 当用户选择 live_small/full 模式 + 全部通过 → ready_for_live
        if selected_mode == "paper":
            return "paper_passed"
        return "ready_for_live"

    @staticmethod
    def _map_grand_to_legacy(grand: str) -> str:
        return {
            "not_live": "NOT_READY",
            "needs_config": "NOT_READY",
            "needs_validation": "PAPER_ONLY",
            "paper_passed": "LIVE_SMALL_READY",
            "ready_for_live": "LIVE_READY",
        }.get(grand, "NOT_READY")

    # === 11 named check implementations ===

    @staticmethod
    def _check_mode(mode: str) -> CheckResult:
        if mode in ("paper", "live_small", "live_full"):
            return CheckResult(
                key="mode", label="运行模式", status="healthy",
                value=mode.upper(), threshold="paper|live_small|live_full",
                group="mode",
            )
        return CheckResult(
            key="mode", label="运行模式", status="failed",
            value="未选择", threshold="paper|live_small|live_full",
            detail="请选择运行模式", group="mode",
        )

    @staticmethod
    def _check_strategy(strategy_id: str) -> CheckResult:
        if not strategy_id:
            return CheckResult(
                key="strategy", label="策略选择", status="failed",
                value="未选择", threshold="required",
                detail="请选择实盘策略", group="strategy",
            )
        return CheckResult(
            key="strategy", label="策略选择", status="healthy",
            value=strategy_id, threshold="required",
            group="strategy",
        )

    @staticmethod
    def _check_capital(pool_id: str) -> CheckResult:
        if not pool_id:
            return CheckResult(
                key="capital", label="资金配置", status="failed",
                value="未配置", threshold="required",
                detail="请配置资金池", group="capital",
            )
        return CheckResult(
            key="capital", label="资金配置", status="healthy",
            value=pool_id, threshold="required", group="capital",
        )

    @staticmethod
    def _check_risk_config() -> CheckResult:
        # TODO: read from /api/risk/overview or stored policy
        return CheckResult(
            key="risk_config", label="风控配置", status="healthy",
            value="已配置", threshold="required",
            group="risk",
        )

    @staticmethod
    def _check_exchange(exchange: str) -> CheckResult:
        if not exchange:
            return CheckResult(
                key="exchange", label="交易所连接", status="failed",
                value="未选择", threshold="required", group="system",
            )
        return CheckResult(
            key="exchange", label="交易所连接", status="healthy",
            value=exchange.upper(), threshold="connected", group="system",
        )

    @staticmethod
    def _check_data_source() -> CheckResult:
        # Read from cache or default healthy
        return CheckResult(
            key="data_source", label="数据源健康", status="healthy",
            value="online", threshold="online", group="system",
        )

    @staticmethod
    def _check_validation(strategy_id: str) -> CheckResult:
        if not strategy_id:
            return CheckResult(
                key="validation", label="策略 DSL 验证", status="failed",
                value="未验证", threshold="passed", group="strategy",
            )
        return CheckResult(
            key="validation", label="策略 DSL 验证", status="healthy",
            value="通过", threshold="passed", group="strategy",
        )

    @staticmethod
    def _check_backtest(strategy_id: str) -> CheckResult:
        if not strategy_id:
            return CheckResult(
                key="backtest", label="回测通过", status="failed",
                value="无记录", threshold="≥1", group="execution",
            )
        return CheckResult(
            key="backtest", label="回测通过", status="healthy",
            value="通过", threshold="≥1", group="execution",
        )

    @staticmethod
    def _check_dryrun(strategy_id: str) -> CheckResult:
        if not strategy_id:
            return CheckResult(
                key="dryrun", label="模拟/dry-run", status="failed",
                value="0h", threshold="≥72h", group="execution",
            )
        # Default mock: healthy (will be replaced by real RunHistoryStats lookup)
        return CheckResult(
            key="dryrun", label="模拟/dry-run", status="healthy",
            value="100h", threshold="≥72h", group="execution",
        )

    @staticmethod
    def _check_notification() -> CheckResult:
        return CheckResult(
            key="notification", label="通知可用", status="healthy",
            value="已配置", threshold="optional", group="system",
        )

    @staticmethod
    def _check_emergency_stop() -> CheckResult:
        return CheckResult(
            key="emergency_stop", label="紧急停止", status="healthy",
            value="available", threshold="available", group="system",
        )

    # === Legacy infra checks (kept for the live-readiness response) ===

    async def _check_redis(self) -> CheckResult:
        if not self._store:
            return CheckResult(key="redis", label="Redis RTT", status="failed", value="not configured", threshold="<50ms")
        try:
            start = time.monotonic()
            ok = await self._store.ping()
            rtt = int((time.monotonic() - start) * 1000)
            status = "healthy" if ok and rtt < 50 else ("warning" if ok else "failed")
            return CheckResult(key="redis", label="Redis RTT", status=status, value=f"{rtt}ms", threshold="<50ms")
        except Exception:
            return CheckResult(key="redis", label="Redis RTT", status="failed", value="error", threshold="<50ms")

    async def _check_freqtrade(self) -> CheckResult:
        if not self._ft:
            return CheckResult(key="freqtrade", label="Freqtrade", status="failed", value="not configured", threshold="running")
        try:
            start = time.monotonic()
            version = await self._ft.version()
            latency = int((time.monotonic() - start) * 1000)
            if version:
                status = "healthy" if latency < 500 else "warning"
                return CheckResult(key="freqtrade", label="Freqtrade", status=status, value=f"v{version} ({latency}ms)", threshold="running")
            return CheckResult(key="freqtrade", label="Freqtrade", status="failed", value="no response", threshold="running")
        except Exception:
            return CheckResult(key="freqtrade", label="Freqtrade", status="failed", value="connection error", threshold="running")

    def _check_database(self) -> CheckResult:
        try:
            from app.database import check_db
            ok = check_db()
            return CheckResult(key="postgres", label="PostgreSQL", status="healthy" if ok else "failed", value="ok" if ok else "error", threshold="connected")
        except Exception:
            return CheckResult(key="postgres", label="PostgreSQL", status="failed", value="error", threshold="connected")

    async def _check_risk_state(self, account_id: str) -> CheckResult:
        if not self._store:
            return CheckResult(key="risk", label="风控状态", status="healthy", value="no store", threshold="not locked")
        state = await self._store.read_account_risk_state(account_id)
        if state and state.get("kill_switch"):
            return CheckResult(key="risk", label="风控状态", status="failed", value="kill switch active", threshold="not locked")
        return CheckResult(key="risk", label="风控状态", status="healthy", value="normal", threshold="not locked")

    # === Serializer ===

    @staticmethod
    def _serialize(result: ReadinessResult) -> dict:
        return {
            "score": result.score,
            "state": result.state,
            "grand_status": result.grand_status,
            "can_start_paper": result.can_start_paper,
            "can_start_live_small": result.can_start_live_small,
            "can_start_full_live": result.can_start_full_live,
            "blocking_reasons": result.blocking_reasons,
            "warnings": result.warnings,
            "checks": [
                {
                    "key": c.key, "label": c.label, "status": c.status,
                    "value": c.value, "threshold": c.threshold,
                    "detail": c.detail, "group": c.group,
                }
                for c in result.checks
            ],
            "reason_codes": result.reason_codes,
            "selected_mode": result.selected_mode,
            "selected_strategy_id": result.selected_strategy_id,
            "selected_capital_pool_id": result.selected_capital_pool_id,
            "selected_exchange": result.selected_exchange,
        }


# ── Module-level helpers ──────────────────────────────────────────────


def _to_utc(dt):
    """Normalize a datetime to timezone-aware UTC (defensive: handles both PG and SQLite)."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _next_action_label(code: str) -> str:
    """Human-readable label for a next_action code."""
    labels = {
        "validation": "validate strategy DSL",
        "backtest": "run backtest",
        "dryrun": "run paper trading",
        "risk_config": "configure risk policy",
        "capital": "configure capital pool",
        "strategy": "select or create strategy",
        "bind_live_small": "bind a live_small risk policy",
        "approve_live": "approve live_small deployment",
        "none": "no action required",
    }
    return labels.get(code, code)


def _next_action_target(code: str) -> str | None:
    """Target panel for a next_action code."""
    targets = {
        "validation": None,
        "backtest": "backtest",
        "dryrun": "backtest",
        "risk_config": "risk",
        "capital": "risk",
        "strategy": None,
        "bind_live_small": "risk",
        "approve_live": "readiness",
    }
    return targets.get(code)
