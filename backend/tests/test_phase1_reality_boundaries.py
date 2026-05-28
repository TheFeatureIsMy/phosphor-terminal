import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers.backtest import _generate_simulated_backtest
from app.schemas.api import BacktestRequest


def test_simulated_backtest_is_deterministic():
    request = BacktestRequest(
        strategy_id=7,
        start_date="2025-01-01",
        end_date="2025-01-10",
        initial_capital=10000,
        symbols=["BTC/USDT"],
    )

    first = _generate_simulated_backtest(request)
    second = _generate_simulated_backtest(request)

    assert first == second
    assert first["data_source"]["source"] == "simulated"
    assert first["data_source"]["simulated"] is True


def test_system_status_reports_disconnected_when_freqtrade_errors(monkeypatch):
    async def fake_status():
        return {"error": "connection refused"}

    monkeypatch.setattr("app.routers.system.freqtrade_client.get_status", fake_status)

    client = TestClient(app)
    response = client.get("/api/system/status")

    assert response.status_code == 200
    body = response.json()
    assert body["api_status"] == "disconnected"
    assert body["data_source"]["source"] == "unavailable"


def test_system_status_reports_connected_when_freqtrade_returns_list(monkeypatch):
    async def fake_status():
        return [{"pair": "BTC/USDT"}]

    monkeypatch.setattr("app.routers.system.freqtrade_client.get_status", fake_status)

    client = TestClient(app)
    response = client.get("/api/system/status")

    assert response.status_code == 200
    body = response.json()
    assert body["api_status"] == "connected"
    assert body["open_positions"] == 1
    assert body["data_source"]["source"] == "freqtrade"
