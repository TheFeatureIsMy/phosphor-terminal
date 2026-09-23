"""Tests for OrderMaterializerService."""
import uuid

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.order import ExecutionOrder, ExecutionTrade, ExecutionPosition
from app.repositories.ledger_repository import LedgerRepository
from app.services.order_materializer import OrderMaterializerService, _utcnow


def _setup_run(session: Session):
    run = StrategyRun(
        strategy_version_id=uuid.uuid4(),
        mode="dry_run",
        status="running",
        started_at=_utcnow(),
    )
    session.add(run)
    session.flush()

    ft_run = FreqtradeRun(
        strategy_run_id=run.id,
        config_path="/tmp/c.json",
        rules_path="/tmp/r.json",
        rule_package_hash="abc",
        status="running",
    )
    session.add(ft_run)
    session.flush()
    return run, ft_run


def _add_trade_event(session, run, ft_run, trade_id, is_open=True, profit_abs=0):
    ledger = LedgerRepository(session)
    now = _utcnow()
    event_type = "FREQTRADE_TRADE_OPENED" if is_open else "FREQTRADE_TRADE_CLOSED"
    payload = {
        "trade_id": trade_id,
        "pair": "BTC/USDT",
        "is_open": is_open,
        "open_rate": 42000.0,
        "close_rate": None if is_open else 43000.0,
        "amount": 0.01,
        "stake_amount": 420.0,
        "profit_abs": profit_abs,
        "profit_ratio": profit_abs / 420.0 if profit_abs else 0,
    }
    event_hash = LedgerRepository.compute_event_hash(
        "freqtrade", f"mat-{run.id}-{trade_id}-{event_type}", event_type, payload, now,
    )
    evt = ExecutionLedgerEvent(
        id=uuid.uuid4(), event_time=now,
        event_type=event_type,
        source_system="freqtrade",
        source_event_id=f"mat-{run.id}-{trade_id}-{event_type}",
        event_hash=event_hash,
        strategy_run_id=run.id,
        freqtrade_run_id=ft_run.id,
        normalized_payload=payload,
    )
    ledger.append(evt)
    return evt


class TestOrderMaterializer:
    def test_materializes_open_trade(self, session: Session):
        run, ft_run = _setup_run(session)
        _add_trade_event(session, run, ft_run, trade_id=101, is_open=True)
        session.commit()

        svc = OrderMaterializerService(session)
        changes = svc.materialize_for_run(run.id)
        session.commit()

        assert changes >= 1
        trades = list(session.scalars(select(ExecutionTrade)).all())
        assert len(trades) == 1
        assert trades[0].source_trade_id == "ft-101"
        assert trades[0].status == "open"
        assert trades[0].symbol == "BTC/USDT"

    def test_materializes_closed_trade(self, session: Session):
        run, ft_run = _setup_run(session)
        _add_trade_event(session, run, ft_run, trade_id=102, is_open=True)
        _add_trade_event(session, run, ft_run, trade_id=102, is_open=False, profit_abs=50.0)
        session.commit()

        svc = OrderMaterializerService(session)
        svc.materialize_for_run(run.id)
        session.commit()

        trades = list(session.scalars(select(ExecutionTrade)).all())
        assert len(trades) == 1
        assert trades[0].status == "closed"
        assert float(trades[0].profit_abs) == 50.0

    def test_creates_position_from_open_trades(self, session: Session):
        run, ft_run = _setup_run(session)
        _add_trade_event(session, run, ft_run, trade_id=201, is_open=True)
        _add_trade_event(session, run, ft_run, trade_id=202, is_open=True)
        session.commit()

        svc = OrderMaterializerService(session)
        svc.materialize_for_run(run.id)
        session.commit()

        positions = list(session.scalars(select(ExecutionPosition)).all())
        assert len(positions) == 1
        assert positions[0].symbol == "BTC/USDT"
        assert positions[0].status == "open"
        assert float(positions[0].amount) == 0.02  # 2 trades × 0.01

    def test_closes_position_when_all_trades_close(self, session: Session):
        run, ft_run = _setup_run(session)
        _add_trade_event(session, run, ft_run, trade_id=301, is_open=True)
        session.commit()

        svc = OrderMaterializerService(session)
        svc.materialize_for_run(run.id)
        session.commit()

        # Now close the trade
        _add_trade_event(session, run, ft_run, trade_id=301, is_open=False, profit_abs=10.0)
        session.commit()

        svc.materialize_for_run(run.id)
        session.commit()

        positions = list(session.scalars(select(ExecutionPosition)).all())
        assert len(positions) == 1
        assert positions[0].status == "closed"

    def test_idempotent_materialization(self, session: Session):
        run, ft_run = _setup_run(session)
        _add_trade_event(session, run, ft_run, trade_id=401, is_open=True)
        session.commit()

        svc = OrderMaterializerService(session)
        svc.materialize_for_run(run.id)
        session.commit()

        # Run again — should not create duplicate
        svc.materialize_for_run(run.id)
        session.commit()

        trades = list(session.scalars(select(ExecutionTrade)).all())
        assert len(trades) == 1
