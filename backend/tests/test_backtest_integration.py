"""Integration tests for backtest API endpoints using FastAPI TestClient."""

import uuid

import pytest


VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30,
            }
        ],
    },
    "exit": {
        "logic": "OR",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70,
            }
        ],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}


def _valid_body(**overrides):
    """Return a valid POST body, with optional field overrides."""
    body = {
        "dsl": VALID_DSL,
        "timerange": "20250101-20250601",
        "symbols": ["BTC/USDT"],
        "initial_capital": 10000,
        "strategy_id": 1,
    }
    body.update(overrides)
    return body


# --------------------------------------------------------------------------- #
#  Tests
# --------------------------------------------------------------------------- #


def test_start_backtest_golden_path(client):
    """POST /api/v2/backtest with valid DSL returns 202 with command_id and
    status 'pending'."""
    resp = client.post("/api/v2/backtest", json=_valid_body())

    assert resp.status_code == 202
    data = resp.json()
    assert "command_id" in data
    assert data["status"] == "pending"


def test_start_backtest_dsl_validation_fails(client):
    """POST with unsupported schema_version returns 422 with
    DSL_SCHEMA_VERSION_UNSUPPORTED error."""
    bad_dsl = {**VALID_DSL, "schema_version": "0.1"}
    resp = client.post("/api/v2/backtest", json=_valid_body(dsl=bad_dsl))

    assert resp.status_code == 422
    body = resp.json()
    errors = str(body)
    assert "DSL_SCHEMA_VERSION_UNSUPPORTED" in errors


def test_start_backtest_risk_check_fails(client):
    """POST with inverted timerange (start > end) returns 422 with
    BACKTEST_INVALID_TIMERANGE error."""
    resp = client.post(
        "/api/v2/backtest",
        json=_valid_body(timerange="20250601-20250101"),
    )

    assert resp.status_code == 422
    body = resp.json()
    errors = str(body)
    assert "BACKTEST_INVALID_TIMERANGE" in errors


def test_start_backtest_zero_capital(client):
    """POST with initial_capital=0 returns 422."""
    resp = client.post(
        "/api/v2/backtest",
        json=_valid_body(initial_capital=0),
    )

    assert resp.status_code == 422


def test_list_backtests(client):
    """GET /api/v2/backtest returns 200 and a list."""
    resp = client.get("/api/v2/backtest")

    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_get_backtest_status_not_found(client):
    """GET /api/v2/backtest/status/{random_uuid} returns 404."""
    random_id = uuid.uuid4()
    resp = client.get(f"/api/v2/backtest/status/{random_id}")

    assert resp.status_code == 404


def test_idempotency(client):
    """POSTing the same valid DSL twice on the same day returns the same
    command_id both times."""
    body = _valid_body()

    resp1 = client.post("/api/v2/backtest", json=body)
    resp2 = client.post("/api/v2/backtest", json=body)

    assert resp1.status_code == 202
    assert resp2.status_code == 202
    assert resp1.json()["command_id"] == resp2.json()["command_id"]
