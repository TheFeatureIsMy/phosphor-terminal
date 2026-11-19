"""System status must report real execution counts, not placeholders."""
import uuid

from app.domain.execution import StrategyRun
from app.domain.order import ExecutionOrder


def _open_order() -> ExecutionOrder:
    return ExecutionOrder(
        latest_ledger_event_id=uuid.uuid4(),
        source_system="freqtrade",
        source_order_id=f"order-{uuid.uuid4().hex[:8]}",
        exchange="binance",
        symbol="BTC/USDT",
        side="buy",
        status="open",
    )


def test_status_reports_database_counts(client, session):
    session.add_all([
        StrategyRun(strategy_version_id=uuid.uuid4(), mode="dry_run", status="running"),
        StrategyRun(strategy_version_id=uuid.uuid4(), mode="dry_run", status="running"),
        StrategyRun(strategy_version_id=uuid.uuid4(), mode="dry_run", status="stopped"),
        _open_order(),
    ])
    session.commit()

    resp = client.get("/api/system/status")
    assert resp.status_code == 200
    body = resp.json()
    assert body["active_strategies"] == 2
    assert body["pending_orders"] == 1


def test_command_queue_reports_counts(client, session):
    from app.domain.command import CommandBusCommand

    session.add_all([
        CommandBusCommand(
            command_type="start_backtest", aggregate_type="test",
            payload={}, idempotency_key=f"k-{uuid.uuid4().hex}",
            requested_by="test", status="pending",
        ),
        CommandBusCommand(
            command_type="start_backtest", aggregate_type="test",
            payload={}, idempotency_key=f"k-{uuid.uuid4().hex}",
            requested_by="test", status="running",
        ),
    ])
    session.commit()

    resp = client.get("/api/system/command-queue")
    assert resp.status_code == 200
    body = resp.json()
    assert body["counts"]["pending"] == 1
    assert body["running"] == 1
    assert body["state"] == "healthy"
