"""TradeIntentService — orchestrates intent → risk decision → execution order."""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.enums import RiskDecisionType, TradeIntentStatus
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.order import ExecutionOrder
from app.domain.risk import StrategyRiskPolicyBinding, CapitalPool
from app.domain.strategy import StrategyVersion
from app.domain.trade_intent import TradeIntent, TradeIntentSignalSnapshot, RiskDecision
from app.repositories.ledger_repository import LedgerRepository
from app.services.risk_engine import RiskEngine

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


@dataclass
class RiskEvaluationResult:
    decision_type: str
    final_position_pct: float
    checks: dict
    codes: list[str]
    reasoning: str | None


@dataclass
class TradeIntentResult:
    intent: TradeIntent
    decision: RiskDecision
    order: ExecutionOrder | None


class TradeIntentService:
    def __init__(self, db: Session):
        self._db = db
        self._risk = RiskEngine()
        self._ledger = LedgerRepository(db)

    def submit_intent(
        self,
        *,
        strategy_run_id: uuid.UUID,
        strategy_version_id: uuid.UUID,
        symbol: str,
        side: str,
        requested_position_pct: float,
        mode: str,
        intent_type: str = "planned",
        reasoning: str | None = None,
        feature_snapshot_id: uuid.UUID | None = None,
        signal_snapshots: list[dict[str, Any]] | None = None,
    ) -> TradeIntentResult:
        # Step 1: Create TradeIntent
        intent = TradeIntent(
            intent_type=intent_type,
            strategy_run_id=strategy_run_id,
            strategy_version_id=strategy_version_id,
            feature_snapshot_id=feature_snapshot_id,
            symbol=symbol,
            side=side,
            requested_position_pct=requested_position_pct,
            mode=mode,
            status=TradeIntentStatus.CREATED.value,
            reasoning=reasoning,
        )
        self._db.add(intent)
        self._db.flush()

        # Step 1b: Save signal snapshots
        if signal_snapshots:
            for snap in signal_snapshots:
                self._db.add(TradeIntentSignalSnapshot(
                    trade_intent_id=intent.id,
                    signal_id=snap["signal_id"],
                    direction=snap.get("direction"),
                    confidence=snap.get("confidence"),
                    score=snap.get("score"),
                ))
            self._db.flush()

        # Step 2: Risk evaluation
        risk_result = self._evaluate_risk(intent)

        # Step 3: Create RiskDecision
        decision = RiskDecision(
            trade_intent_id=intent.id,
            strategy_run_id=strategy_run_id,
            decision=risk_result.decision_type,
            final_position_pct=risk_result.final_position_pct,
            risk_checks=risk_result.checks,
            risk_codes=risk_result.codes,
            reasoning=risk_result.reasoning,
        )
        self._db.add(decision)
        self._db.flush()

        intent.status = TradeIntentStatus.RISK_EVALUATED.value
        self._db.flush()

        self._write_event(
            "PULSEDESK_RISK_DECISION_CREATED",
            strategy_run_id=strategy_run_id,
            trade_intent_id=intent.id,
            payload={
                "trade_intent_id": str(intent.id),
                "risk_decision_id": str(decision.id),
                "decision": risk_result.decision_type,
                "final_position_pct": risk_result.final_position_pct,
                "symbol": symbol,
            },
        )

        # Step 4: Act on decision
        if risk_result.decision_type in (
            RiskDecisionType.REJECT.value,
            RiskDecisionType.PAPER_ONLY.value,
        ):
            intent.status = TradeIntentStatus.REJECTED.value
            self._db.flush()
            return TradeIntentResult(intent=intent, decision=decision, order=None)

        if risk_result.decision_type == RiskDecisionType.HUMAN_CONFIRM.value:
            intent.status = TradeIntentStatus.APPROVED.value
            self._db.flush()
            return TradeIntentResult(intent=intent, decision=decision, order=None)

        # ALLOW or REDUCE_SIZE → create order
        intent.status = TradeIntentStatus.APPROVED.value
        self._db.flush()

        order = self._create_order(intent, decision)
        return TradeIntentResult(intent=intent, decision=decision, order=order)

    def confirm_intent(self, intent_id: uuid.UUID) -> TradeIntentResult | None:
        """Human confirms a HUMAN_CONFIRM intent → create order."""
        intent = self._db.get(TradeIntent, intent_id)
        if not intent or intent.status != TradeIntentStatus.APPROVED.value:
            return None

        decision = self._db.scalars(
            select(RiskDecision).where(RiskDecision.trade_intent_id == intent_id)
        ).first()
        if not decision:
            return None

        order = self._create_order(intent, decision)
        return TradeIntentResult(intent=intent, decision=decision, order=order)

    def _evaluate_risk(self, intent: TradeIntent) -> RiskEvaluationResult:
        version = self._db.get(StrategyVersion, intent.strategy_version_id)
        dsl = version.rule_dsl if version else {}
        position_sizing = dsl.get("position_sizing", {})

        # Layer 1: DSL position_pct
        dsl_pct = position_sizing.get("position_pct", intent.requested_position_pct)

        # Layer 2: Risk policy limit
        risk_policy_pct = self._get_risk_policy_limit(intent)

        # Layer 3: Capital pool remaining
        capital_pool_pct = self._get_capital_pool_remaining(intent)

        # Layer 4: Freqtrade config limit (from FreqtradeRun config)
        freqtrade_limit_pct = None

        final_pct = RiskEngine.four_layer_position_clip(
            dsl_pct, risk_policy_pct, capital_pool_pct, freqtrade_limit_pct
        )

        checks = {
            "dsl_pct": dsl_pct,
            "risk_policy_pct": risk_policy_pct,
            "capital_pool_pct": capital_pool_pct,
            "freqtrade_limit_pct": freqtrade_limit_pct,
            "final_pct": final_pct,
            "requested": intent.requested_position_pct,
        }
        codes: list[str] = []

        if final_pct <= 0:
            return RiskEvaluationResult(
                decision_type=RiskDecisionType.REJECT.value,
                final_position_pct=0, checks=checks,
                codes=["ZERO_POSITION"],
                reasoning="Position clipped to zero by risk layers",
            )

        if final_pct < intent.requested_position_pct:
            codes.append("REDUCED")

        # Determine decision type based on mode
        if intent.mode == "live_small":
            decision_type = RiskDecisionType.HUMAN_CONFIRM.value
        elif intent.mode == "dry_run":
            decision_type = RiskDecisionType.ALLOW.value
        else:
            decision_type = RiskDecisionType.ALLOW.value

        if final_pct < intent.requested_position_pct:
            decision_type = RiskDecisionType.REDUCE_SIZE.value

        return RiskEvaluationResult(
            decision_type=decision_type,
            final_position_pct=final_pct,
            checks=checks, codes=codes, reasoning=None,
        )

    def _get_risk_policy_limit(self, intent: TradeIntent) -> float | None:
        binding = self._db.scalars(
            select(StrategyRiskPolicyBinding).where(
                StrategyRiskPolicyBinding.strategy_version_id == intent.strategy_version_id,
                StrategyRiskPolicyBinding.mode == intent.mode,
            ).limit(1)
        ).first()
        if not binding or not binding.capital_pool_id:
            return None
        pool = self._db.get(CapitalPool, binding.capital_pool_id)
        if pool:
            return float(pool.max_position_pct_per_trade)
        return None

    def _get_capital_pool_remaining(self, intent: TradeIntent) -> float | None:
        binding = self._db.scalars(
            select(StrategyRiskPolicyBinding).where(
                StrategyRiskPolicyBinding.strategy_version_id == intent.strategy_version_id,
                StrategyRiskPolicyBinding.mode == intent.mode,
            ).limit(1)
        ).first()
        if not binding or not binding.capital_pool_id:
            return None
        pool = self._db.get(CapitalPool, binding.capital_pool_id)
        if pool:
            return float(pool.max_total_exposure_pct)
        return None

    def _create_order(self, intent: TradeIntent, decision: RiskDecision) -> ExecutionOrder | None:
        ft_run = self._db.scalars(
            select(FreqtradeRun).where(
                FreqtradeRun.strategy_run_id == intent.strategy_run_id,
                FreqtradeRun.status == "running",
            ).limit(1)
        ).first()

        if not ft_run:
            intent.status = TradeIntentStatus.CANCELLED.value
            self._db.flush()
            logger.warning("No running FreqtradeRun for intent %s", intent.id)
            return None

        now = _utcnow()
        order = ExecutionOrder(
            latest_ledger_event_id=uuid.uuid4(),
            strategy_run_id=intent.strategy_run_id,
            freqtrade_run_id=ft_run.id,
            source_system="pulsedesk",
            source_order_id=f"intent-{intent.id}",
            exchange="binance",
            symbol=intent.symbol,
            side=intent.side,
            order_type="market",
            amount=decision.final_position_pct,
            status="pending",
            opened_at=now,
        )
        self._db.add(order)
        self._db.flush()

        intent.status = TradeIntentStatus.SENT.value
        self._db.flush()

        self._write_event(
            "PULSEDESK_ORDER_CREATED",
            strategy_run_id=intent.strategy_run_id,
            trade_intent_id=intent.id,
            payload={
                "order_id": str(order.id),
                "trade_intent_id": str(intent.id),
                "symbol": intent.symbol,
                "side": intent.side,
                "amount": float(decision.final_position_pct),
            },
        )

        return order

    def _write_event(
        self, event_type: str, *,
        strategy_run_id: uuid.UUID,
        trade_intent_id: uuid.UUID,
        payload: dict,
    ) -> None:
        now = _utcnow()
        source_event_id = f"{event_type.lower()}-{trade_intent_id}"
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", source_event_id, event_type, payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="pulsedesk",
            source_event_id=source_event_id,
            event_hash=event_hash,
            strategy_run_id=strategy_run_id,
            trade_intent_id=trade_intent_id,
            normalized_payload=payload,
        )
        self._ledger.append(evt)
