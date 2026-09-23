"""Tests for StrategyPromotionService."""
import uuid
from datetime import timedelta

import pytest
from sqlalchemy.orm import Session

from app.domain.enums import StrategyVersionStatus, StrategyRunMode
from app.domain.execution import StrategyRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.ledger_repository import LedgerRepository
from app.services.strategy_promotion_service import (
    StrategyPromotionService,
    PromotionCriteria,
    _utcnow,
)


def _make_strategy_and_run(
    session: Session,
    version_status: str = "paper_running",
    started_hours_ago: float = 100,
) -> tuple[StrategyVersion, StrategyRun]:
    strategy = StrategyV2(
        name="Test Strategy",
        strategy_type="rule_dsl",
        source_type="manual",
        status="active",
    )
    session.add(strategy)
    session.flush()

    version = StrategyVersion(
        strategy_id=strategy.id,
        version_no=1,
        status=version_status,
        dsl_version="2.5",
        rule_dsl={"schema_version": "2.5"},
        dsl_hash="abc",
        created_by="test",
    )
    session.add(version)
    session.flush()

    run = StrategyRun(
        strategy_version_id=version.id,
        mode=StrategyRunMode.DRY_RUN.value,
        status="running",
        started_at=_utcnow() - timedelta(hours=started_hours_ago),
    )
    session.add(run)
    session.flush()
    return version, run


def _add_closed_trades(session: Session, strategy_run_id: uuid.UUID, wins: int, losses: int):
    ledger = LedgerRepository(session)
    now = _utcnow()
    for i in range(wins):
        payload = {"profit_ratio": 0.05, "trade_id": f"win-{i}"}
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", f"win-{strategy_run_id}-{i}", "FREQTRADE_TRADE_CLOSED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now,
            event_type="FREQTRADE_TRADE_CLOSED",
            source_system="freqtrade",
            source_event_id=f"win-{strategy_run_id}-{i}",
            event_hash=event_hash,
            strategy_run_id=strategy_run_id,
            normalized_payload=payload,
        )
        ledger.append(evt)
    for i in range(losses):
        payload = {"profit_ratio": -0.03, "trade_id": f"loss-{i}"}
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", f"loss-{strategy_run_id}-{i}", "FREQTRADE_TRADE_CLOSED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now,
            event_type="FREQTRADE_TRADE_CLOSED",
            source_system="freqtrade",
            source_event_id=f"loss-{strategy_run_id}-{i}",
            event_hash=event_hash,
            strategy_run_id=strategy_run_id,
            normalized_payload=payload,
        )
        ledger.append(evt)


class TestStrategyPromotionService:
    def test_promotes_when_all_criteria_met(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=100)
        _add_closed_trades(session, run.id, wins=4, losses=2)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(
            min_dryrun_hours=72, min_total_trades=5, min_win_rate=0.4,
        ))
        promoted = svc.promote_if_eligible(run.id)
        session.commit()

        assert promoted is True
        refreshed = session.get(StrategyVersion, version.id)
        assert refreshed.status == StrategyVersionStatus.PAPER_PASSED.value

    def test_not_promoted_insufficient_duration(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=24)
        _add_closed_trades(session, run.id, wins=5, losses=1)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(min_dryrun_hours=72))
        result = svc.evaluate_promotion(run.id)
        assert result.eligible is False
        assert "duration" in result.reason

    def test_not_promoted_insufficient_trades(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=100)
        _add_closed_trades(session, run.id, wins=2, losses=1)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(min_total_trades=5))
        result = svc.evaluate_promotion(run.id)
        assert result.eligible is False
        assert "insufficient_trades" in result.reason

    def test_not_promoted_low_win_rate(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=100)
        _add_closed_trades(session, run.id, wins=1, losses=5)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(
            min_total_trades=5, min_win_rate=0.4,
        ))
        result = svc.evaluate_promotion(run.id)
        assert result.eligible is False
        assert "win_rate" in result.reason

    def test_not_promoted_wrong_status(self, session: Session):
        version, run = _make_strategy_and_run(session, version_status="draft", started_hours_ago=100)
        session.commit()

        svc = StrategyPromotionService(session)
        result = svc.evaluate_promotion(run.id)
        assert result.eligible is False
        assert "wrong_status" in result.reason

    def test_not_promoted_circuit_breaker(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=100)
        _add_closed_trades(session, run.id, wins=5, losses=1)

        # Add circuit breaker event
        ledger = LedgerRepository(session)
        now = _utcnow()
        payload = {"reason": "daily_loss"}
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", f"cb-{run.id}", "CIRCUIT_BREAKER_TRIPPED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now,
            event_type="CIRCUIT_BREAKER_TRIPPED",
            source_system="pulsedesk",
            source_event_id=f"cb-{run.id}",
            event_hash=event_hash,
            strategy_run_id=run.id,
            normalized_payload=payload,
        )
        ledger.append(evt)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(
            max_circuit_breaker_trips=0,
        ))
        result = svc.evaluate_promotion(run.id)
        assert result.eligible is False
        assert "circuit_breaker" in result.reason

    def test_promotion_writes_ledger_event(self, session: Session):
        version, run = _make_strategy_and_run(session, started_hours_ago=100)
        _add_closed_trades(session, run.id, wins=4, losses=2)
        session.commit()

        svc = StrategyPromotionService(session, criteria=PromotionCriteria(
            min_dryrun_hours=72, min_total_trades=5, min_win_rate=0.4,
        ))
        svc.promote_if_eligible(run.id)
        session.commit()

        from sqlalchemy import select
        events = list(session.scalars(
            select(ExecutionLedgerEvent).where(
                ExecutionLedgerEvent.event_type == "PULSEDESK_STRATEGY_PROMOTED"
            )
        ).all())
        assert len(events) == 1
        assert events[0].normalized_payload["to_status"] == "paper_passed"
