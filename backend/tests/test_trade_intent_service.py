"""Tests for TradeIntentService — intent → risk → order pipeline."""
import uuid

import pytest
from sqlalchemy.orm import Session

from app.domain.enums import RiskDecisionType, TradeIntentStatus, StrategyRunMode
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.trade_intent import TradeIntent, RiskDecision
from app.services.trade_intent_service import TradeIntentService, _utcnow


VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {"logic": "AND", "rules": []},
    "exit": {"logic": "OR", "rules": []},
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
}


def _setup_strategy(session: Session, mode="dry_run", with_ft_run=True):
    strategy = StrategyV2(
        name="Test",
        strategy_type="rule_dsl",
        source_type="manual",
        status="active",
    )
    session.add(strategy)
    session.flush()

    version = StrategyVersion(
        strategy_id=strategy.id,
        version_no=1,
        status="paper_running",
        dsl_version="2.5",
        rule_dsl=VALID_DSL,
        dsl_hash="abc",
        created_by="test",
    )
    session.add(version)
    session.flush()

    run = StrategyRun(
        strategy_version_id=version.id,
        mode=mode,
        status="running",
        started_at=_utcnow(),
    )
    session.add(run)
    session.flush()

    ft_run = None
    if with_ft_run:
        ft_run = FreqtradeRun(
            strategy_run_id=run.id,
            config_path="/tmp/config.json",
            rules_path="/tmp/rules.json",
            rule_package_hash="abc",
            status="running",
            api_base_url="http://localhost:8080",
        )
        session.add(ft_run)
        session.flush()

    return strategy, version, run, ft_run


class TestTradeIntentService:
    def test_happy_path_dryrun_creates_order(self, session: Session):
        _, version, run, ft_run = _setup_strategy(session)
        session.commit()

        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.02,
            mode="dry_run",
        )
        session.commit()

        assert result.intent.status == TradeIntentStatus.SENT.value
        assert result.decision.decision == RiskDecisionType.ALLOW.value
        assert float(result.decision.final_position_pct) == 0.02
        assert result.order is not None
        assert result.order.symbol == "BTC/USDT"
        assert result.order.side == "buy"

    def test_live_small_requires_human_confirm(self, session: Session):
        _, version, run, ft_run = _setup_strategy(session, mode="live_small")
        session.commit()

        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="ETH/USDT",
            side="buy",
            requested_position_pct=0.01,
            mode="live_small",
        )
        session.commit()

        assert result.intent.status == TradeIntentStatus.APPROVED.value
        assert result.decision.decision == RiskDecisionType.HUMAN_CONFIRM.value
        assert result.order is None  # No order until confirmed

    def test_confirm_creates_order(self, session: Session):
        _, version, run, ft_run = _setup_strategy(session, mode="live_small")
        session.commit()

        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.01,
            mode="live_small",
        )
        session.commit()

        # Now confirm
        confirmed = svc.confirm_intent(result.intent.id)
        session.commit()

        assert confirmed is not None
        assert confirmed.intent.status == TradeIntentStatus.SENT.value
        assert confirmed.order is not None

    def test_reject_when_position_zero(self, session: Session):
        """If DSL position_pct is 0, risk rejects."""
        strategy = StrategyV2(name="Test", strategy_type="rule_dsl", source_type="manual", status="active")
        session.add(strategy)
        session.flush()

        zero_dsl = {**VALID_DSL, "position_sizing": {"type": "fixed_pct", "position_pct": 0.0}}
        version = StrategyVersion(
            strategy_id=strategy.id, version_no=1, status="paper_running",
            dsl_version="2.5", rule_dsl=zero_dsl, dsl_hash="xyz", created_by="test",
        )
        session.add(version)
        session.flush()

        run = StrategyRun(
            strategy_version_id=version.id, mode="dry_run", status="running", started_at=_utcnow(),
        )
        session.add(run)
        session.flush()
        session.commit()

        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.0,
            mode="dry_run",
        )
        session.commit()

        assert result.intent.status == TradeIntentStatus.REJECTED.value
        assert result.decision.decision == RiskDecisionType.REJECT.value
        assert result.order is None

    def test_no_ft_run_cancels_intent(self, session: Session):
        _, version, run, _ = _setup_strategy(session, with_ft_run=False)
        session.commit()

        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.02,
            mode="dry_run",
        )
        session.commit()

        assert result.intent.status == TradeIntentStatus.CANCELLED.value
        assert result.order is None

    def test_ledger_events_written(self, session: Session):
        _, version, run, ft_run = _setup_strategy(session)
        session.commit()

        svc = TradeIntentService(session)
        svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.02,
            mode="dry_run",
        )
        session.commit()

        from sqlalchemy import select
        events = list(session.scalars(
            select(ExecutionLedgerEvent).where(
                ExecutionLedgerEvent.strategy_run_id == run.id
            )
        ).all())
        event_types = {e.event_type for e in events}
        assert "PULSEDESK_RISK_DECISION_CREATED" in event_types
        assert "PULSEDESK_ORDER_CREATED" in event_types

    def test_signal_snapshots_saved(self, session: Session):
        from app.domain.trade_intent import TradeIntentSignalSnapshot
        from sqlalchemy import select

        _, version, run, ft_run = _setup_strategy(session)
        session.commit()

        sig_id = uuid.uuid4()
        svc = TradeIntentService(session)
        result = svc.submit_intent(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            symbol="BTC/USDT",
            side="buy",
            requested_position_pct=0.02,
            mode="dry_run",
            signal_snapshots=[
                {"signal_id": sig_id, "direction": "long", "confidence": 0.85},
            ],
        )
        session.commit()

        snaps = list(session.scalars(
            select(TradeIntentSignalSnapshot).where(
                TradeIntentSignalSnapshot.trade_intent_id == result.intent.id
            )
        ).all())
        assert len(snaps) == 1
        assert snaps[0].signal_id == sig_id
        assert float(snaps[0].confidence) == 0.85
