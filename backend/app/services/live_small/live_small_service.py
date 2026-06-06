"""LiveSmall Service — orchestrates safety checks for live_small approval.

This service DOES NOT execute trades, start containers, or interact with
Freqtrade/exchanges. It evaluates whether a live_small request meets all
safety requirements and returns an approval report with config preview.

Dependency boundary:
  ALLOWED: RiskEngine, DSLValidator, precondition_checker, circuit_breaker,
           config_generator, CapitalPool (read), StrategyVersion (read)
  FORBIDDEN: command bus, freqtrade adapter, trade intent, exchange API, container runtime
"""
from __future__ import annotations

import uuid
from typing import Any, Literal

from sqlalchemy.orm import Session

from app.domain.risk import CapitalPool
from app.domain.strategy import StrategyVersion
from app.schemas.live_small import (
    CapitalPoolParams,
    FreqtradeConfigPreview,
    LiveSmallApprovalResponse,
    PreconditionReport,
    RunHistoryStats,
)
from app.services.live_small.circuit_breaker import TradeResult, check_circuit_breaker
from app.services.live_small.config_generator import generate_config_preview, validate_config_safety
from app.services.live_small.precondition_checker import check_preconditions
from app.services.risk_engine import RiskEngine


class LiveSmallService:
    can_execute: Literal[False] = False
    auto_start: Literal[False] = False
    requires_human_confirm: Literal[True] = True

    def __init__(self, db: Session) -> None:
        self._db = db
        self._risk = RiskEngine()

    def evaluate_approval(
        self,
        strategy_version_id: uuid.UUID,
        capital_pool_id: uuid.UUID,
        run_history: RunHistoryStats,
        exchange_name: str = "binance",
    ) -> LiveSmallApprovalResponse:
        version = self._db.get(StrategyVersion, strategy_version_id)
        if not version:
            return LiveSmallApprovalResponse(
                preconditions=PreconditionReport(
                    all_passed=False,
                    items=[],
                    strategy_version_id=strategy_version_id,
                ),
                risk_errors=[{"code": "NOT_FOUND", "message": f"StrategyVersion {strategy_version_id} not found"}],
            )

        pool = self._db.get(CapitalPool, capital_pool_id)
        if not pool:
            return LiveSmallApprovalResponse(
                preconditions=PreconditionReport(
                    all_passed=False,
                    items=[],
                    capital_pool_id=capital_pool_id,
                ),
                risk_errors=[{"code": "NOT_FOUND", "message": f"CapitalPool {capital_pool_id} not found"}],
            )

        preconditions = check_preconditions(run_history)
        preconditions.strategy_version_id = strategy_version_id
        preconditions.capital_pool_id = capital_pool_id

        if not preconditions.all_passed:
            return LiveSmallApprovalResponse(
                preconditions=preconditions,
                risk_check_passed=False,
            )

        pool_params = CapitalPoolParams(
            total_budget=float(pool.total_budget),
            max_position_pct_per_trade=float(pool.max_position_pct_per_trade),
            max_total_exposure_pct=float(pool.max_total_exposure_pct),
            max_daily_loss_pct=float(pool.max_daily_loss_pct),
            max_drawdown_pct=float(pool.max_drawdown_pct),
            allow_leverage=False,
            allow_auto_trade=False,
            requires_human_confirm=True,
            currency="USDT",
        )

        risk_result = self._risk.pre_live_small_check(
            dsl=version.rule_dsl,
            capital_pool={
                "total_budget": pool_params.total_budget,
                "max_position_pct_per_trade": pool_params.max_position_pct_per_trade,
                "max_total_exposure_pct": pool_params.max_total_exposure_pct,
                "max_daily_loss_pct": pool_params.max_daily_loss_pct,
                "allow_leverage": False,
                "allow_auto_trade": False,
                "requires_human_confirm": True,
            },
        )

        if not risk_result.approved:
            return LiveSmallApprovalResponse(
                preconditions=preconditions,
                risk_check_passed=False,
                risk_errors=risk_result.errors,
            )

        config_preview = generate_config_preview(
            dsl=version.rule_dsl,
            pool=pool_params,
            exchange_name=exchange_name,
        )

        config_errors = validate_config_safety(config_preview, pool_params)
        if config_errors:
            return LiveSmallApprovalResponse(
                preconditions=preconditions,
                risk_check_passed=True,
                risk_errors=[{"code": "CONFIG_SAFETY", "message": e} for e in config_errors],
                config_preview=config_preview,
            )

        return LiveSmallApprovalResponse(
            preconditions=preconditions,
            risk_check_passed=True,
            config_preview=config_preview,
            can_proceed=True,
        )

    def check_circuit_breaker(
        self,
        trades_today: list[TradeResult],
        total_budget: float,
        max_daily_loss_pct: float = 0.03,
        max_consecutive_losses: int = 3,
    ) -> dict:
        return check_circuit_breaker(
            trades_today=trades_today,
            total_budget=total_budget,
            max_daily_loss_pct=max_daily_loss_pct,
            max_consecutive_losses=max_consecutive_losses,
        )
