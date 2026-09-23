"""StrategyOptimizationWorkflow — PRD §10.3 safety pipeline orchestration.

Advances a StrategyCandidate through the mandatory pipeline:

    draft → (DSL validate) → validated → (backtest command) → backtesting
          → (paper/dry-run command) → paper_running → pending_review

Final approval (pending_review → confirmed) deliberately stays on the
existing manual confirm endpoint — the workflow never auto-promotes a
candidate into a live strategy version.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.domain.enums import CommandType
from app.domain.growth import StrategyCandidate
from app.services.command_bus import CommandBusService
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_validator import DSLValidator
from app.services.risk_engine import RiskEngine

logger = logging.getLogger(__name__)

_validator = DSLValidator()
_risk_engine = RiskEngine()

TERMINAL_STAGES = {"confirmed", "rejected"}


def _default_timerange() -> str:
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=180)
    return f"{start.strftime('%Y%m%d')}-{end.strftime('%Y%m%d')}"


class StrategyOptimizationWorkflow:
    def __init__(self, session: Session):
        self._s = session

    def advance(self, candidate: StrategyCandidate) -> dict:
        """Advance the candidate one pipeline stage. Returns a result dict with
        stage / blocked / command_id / reason_codes."""
        stage = candidate.status

        if stage in TERMINAL_STAGES:
            return {"stage": stage, "blocked": True,
                    "reason_codes": ["candidate_terminal_state"]}

        if stage == "draft":
            return self._validate(candidate)
        if stage == "validated":
            return self._enqueue_backtest(candidate)
        if stage == "backtesting":
            return self._enqueue_paper(candidate)
        if stage == "paper_running":
            candidate.status = "pending_review"
            self._s.flush()
            return {"stage": "pending_review", "blocked": False, "reason_codes": []}
        if stage == "pending_review":
            return {"stage": stage, "blocked": True,
                    "reason_codes": ["use_confirm_endpoint"],
                    "message": "Final approval requires the manual confirm endpoint"}

        return {"stage": stage, "blocked": True,
                "reason_codes": ["unknown_stage"]}

    # ── Stage implementations ─────────────────────────────────────────

    def _validate(self, candidate: StrategyCandidate) -> dict:
        report = _validator.validate(candidate.candidate_dsl)
        candidate.dsl_valid = report.valid
        candidate.dsl_errors = [
            {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
            for e in report.errors
        ]
        if not report.valid:
            self._s.flush()
            return {"stage": "draft", "blocked": True,
                    "reason_codes": ["dsl_validation_failed"],
                    "errors": candidate.dsl_errors}
        candidate.status = "validated"
        self._s.flush()
        return {"stage": "validated", "blocked": False, "reason_codes": []}

    def _enqueue_backtest(self, candidate: StrategyCandidate) -> dict:
        dsl = candidate.candidate_dsl
        timerange = _default_timerange()
        risk_result = _risk_engine.pre_backtest_check(
            dsl=dsl, timerange=timerange, initial_capital=10000,
        )
        if not risk_result.approved:
            return {"stage": "validated", "blocked": True,
                    "reason_codes": ["pre_backtest_risk_check_failed"],
                    "errors": risk_result.errors}

        cmd = self._enqueue(
            candidate,
            command_type=CommandType.START_BACKTEST.value,
            action="candidate_backtest",
            payload={
                "dsl": dsl,
                "dsl_hash": compute_dsl_hash(dsl),
                "timerange": timerange,
                "symbols": dsl.get("symbols", ["BTC/USDT"]),
                "initial_capital": 10000,
                "stake_amount": 100,
                "max_open_trades": (dsl.get("risk") or {}).get("max_open_trades", 3),
                "exchange": "binance",
                "fee": 0.001,
                "strategy_id": None,
                "strategy_version_id": str(candidate.source_strategy_version_id),
                "include_mtf_guard": False,
                "candidate_id": str(candidate.id),
            },
            timeout_sec=600,
        )
        candidate.status = "backtesting"
        self._s.flush()
        return {"stage": "backtesting", "blocked": False, "reason_codes": [],
                "command_id": str(cmd.id)}

    def _enqueue_paper(self, candidate: StrategyCandidate) -> dict:
        dsl = candidate.candidate_dsl
        risk_result = _risk_engine.pre_dryrun_check(
            dsl=dsl, stake_amount=100, initial_wallet=10000, max_open_trades=3,
        )
        if not risk_result.approved:
            return {"stage": "backtesting", "blocked": True,
                    "reason_codes": ["pre_paper_risk_check_failed"],
                    "errors": risk_result.errors}

        cmd = self._enqueue(
            candidate,
            command_type=CommandType.START_DRYRUN.value,
            action="candidate_paper",
            payload={
                "dsl": dsl,
                "dsl_hash": compute_dsl_hash(dsl),
                "symbols": dsl.get("symbols", ["BTC/USDT"]),
                "stake_amount": 100,
                "max_open_trades": (dsl.get("risk") or {}).get("max_open_trades", 3),
                "initial_wallet": 10000,
                "exchange": "binance",
                "api_port": 8080,
                "strategy_id": None,
                "strategy_version_id": str(candidate.source_strategy_version_id),
                "mode": "paper",
                "candidate_id": str(candidate.id),
            },
            timeout_sec=120,
        )
        candidate.status = "paper_running"
        self._s.flush()
        return {"stage": "paper_running", "blocked": False, "reason_codes": [],
                "command_id": str(cmd.id)}

    # ── Helpers ───────────────────────────────────────────────────────

    def _enqueue(
        self,
        candidate: StrategyCandidate,
        *,
        command_type: str,
        action: str,
        payload: dict,
        timeout_sec: int,
    ):
        bus = CommandBusService(self._s)
        idempotency_key = f"{action}:{candidate.id}:{payload['dsl_hash']}"
        cmd, _created = bus.enqueue(
            command_type=command_type,
            aggregate_type="strategy_candidate",
            aggregate_id=candidate.id,
            payload=payload,
            idempotency_key=idempotency_key,
            requested_by=f"api:optimization-workflow/{action}",
            timeout_sec=timeout_sec,
        )
        return cmd
