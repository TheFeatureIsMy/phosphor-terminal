"""Verify DryRunRunResponse exposes all fields the macOS Run Rail needs."""
from app.schemas.dryrun_v2 import DryRunRunResponse


def test_dryrun_run_response_has_runrail_fields():
    """Run Rail needs: status, open_trades, total_profit, pid, created_at, stopped_at, symbols, stake_amount."""
    sample = {
        "id": 1,
        "strategy_id": 1,
        "status": "running",
        "pid": 12345,
        "open_trades": 2,
        "total_profit": 12.5,
        "symbols": ["BTC/USDT"],
        "stake_amount": 100.0,
        "created_at": "2026-06-30T00:00:00Z",
        "stopped_at": None,
    }
    resp = DryRunRunResponse(**sample)
    assert resp.status == "running"
    assert resp.open_trades == 2
    assert resp.total_profit == 12.5
    assert resp.pid == 12345
    assert resp.symbols == ["BTC/USDT"]
    assert resp.stake_amount == 100.0
    assert resp.created_at is not None
    assert resp.stopped_at is None
