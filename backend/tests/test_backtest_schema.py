from app.schemas.backtest_v2 import (
    BacktestRunResponse, EquityPoint, TradeRow,
)


def test_equity_point_serialization():
    pt = EquityPoint(timestamp="2024-01-01T00:00:00Z", equity=10000.0, drawdown=0.0)
    assert pt.model_dump()["equity"] == 10000.0


def test_trade_row_serialization():
    t = TradeRow(
        open_time="2024-01-01T00:00:00Z",
        close_time="2024-01-01T01:00:00Z",
        pair="BTC/USDT",
        side="long",
        open_price=40000.0,
        close_price=40500.0,
        quantity=0.1,
        profit=50.0,
        duration="1h",
        mtf_state="confirmed",
    )
    assert t.model_dump()["pair"] == "BTC/USDT"


def test_backtest_run_response_extracts_equity_and_trades_from_result():
    run = BacktestRunResponse(
        id=1, strategy_id=1, status="completed",
        start_date="20240101", end_date="20240601", initial_capital=10000,
        result={
            "equity_curve": [
                {"timestamp": "2024-01-01", "equity": 10000, "drawdown": 0},
                {"timestamp": "2024-01-02", "equity": 10100, "drawdown": 0},
            ],
            "trades": [
                {"open_time": "2024-01-01", "close_time": "2024-01-01",
                 "pair": "BTC/USDT", "side": "long",
                 "open_price": 40000, "close_price": 40500,
                 "quantity": 0.1, "profit": 50, "duration": "1h",
                 "mtf_state": "confirmed"},
            ],
        },
    )
    assert len(run.equity_curve) == 2
    assert run.equity_curve[0].equity == 10000
    assert len(run.trades) == 1
    assert run.trades[0].profit == 50.0
