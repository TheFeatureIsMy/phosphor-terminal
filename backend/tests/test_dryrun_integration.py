"""Integration tests for dry-run API endpoints and RiskEngine pre_dryrun_check."""

import uuid

import pytest

from app.services.risk_engine import RiskEngine


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _valid_dsl():
    """Return a minimal valid DSL payload."""
    return {
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
    """Build a valid POST /api/v2/dryrun request body with optional overrides."""
    body = {
        "dsl": _valid_dsl(),
        "symbols": ["BTC/USDT"],
        "stake_amount": 100,
        "max_open_trades": 5,
        "initial_wallet": 10000,
        "exchange": "binance",
        "strategy_id": 1,
    }
    body.update(overrides)
    return body


# ---------------------------------------------------------------------------
# API endpoint tests
# ---------------------------------------------------------------------------


class TestStartDryrun:
    """POST /api/v2/dryrun"""

    def test_start_dryrun_golden_path(self, client):
        """Valid DSL returns 202 with command_id and status 'pending'."""
        resp = client.post("/api/v2/dryrun", json=_valid_body())
        assert resp.status_code == 202, resp.text
        data = resp.json()
        assert "command_id" in data
        assert data["status"] == "pending"

    def test_start_dryrun_dsl_validation_fails(self, client):
        """Unsupported schema_version 1.0 returns 422 with DSL_SCHEMA_VERSION_UNSUPPORTED."""
        dsl = _valid_dsl()
        dsl["schema_version"] = "1.0"
        resp = client.post("/api/v2/dryrun", json=_valid_body(dsl=dsl))
        assert resp.status_code == 422, resp.text
        body = resp.json()
        errors = body if isinstance(body, list) else body.get("errors", body.get("detail", []))
        error_text = str(errors)
        assert "DSL_SCHEMA_VERSION_UNSUPPORTED" in error_text

    def test_start_dryrun_zero_stake(self, client):
        """stake_amount=0 should be rejected by Pydantic (gt=0) with 422."""
        resp = client.post("/api/v2/dryrun", json=_valid_body(stake_amount=0))
        assert resp.status_code == 422, resp.text

    def test_start_dryrun_stake_exceeds_wallet(self, client):
        """stake_amount * max_open_trades > initial_wallet returns 422."""
        resp = client.post(
            "/api/v2/dryrun",
            json=_valid_body(stake_amount=5000, max_open_trades=5, initial_wallet=10000),
        )
        assert resp.status_code == 422, resp.text
        body = resp.json()
        error_text = str(body)
        assert "DRYRUN_STAKE_EXCEEDS_WALLET" in error_text


class TestListDryruns:
    """GET /api/v2/dryrun"""

    def test_list_dryruns(self, client):
        """Listing dry-runs returns 200 and a list."""
        resp = client.get("/api/v2/dryrun")
        assert resp.status_code == 200, resp.text
        assert isinstance(resp.json(), list)


class TestStopDryrun:
    """POST /api/v2/dryrun/{id}/stop"""

    def test_stop_dryrun_not_found(self, client):
        """Stopping a non-existent dry-run returns 404."""
        resp = client.post("/api/v2/dryrun/99999/stop")
        assert resp.status_code == 404, resp.text


class TestGetDryrunStatus:
    """GET /api/v2/dryrun/status/{command_id}"""

    def test_get_status_not_found(self, client):
        """Querying status with a random UUID returns 404."""
        random_id = str(uuid.uuid4())
        resp = client.get(f"/api/v2/dryrun/status/{random_id}")
        assert resp.status_code == 404, resp.text


class TestIdempotency:
    """Idempotent POST /api/v2/dryrun"""

    def test_idempotency(self, client):
        """Posting the same valid body twice returns the same command_id."""
        body = _valid_body()
        resp1 = client.post("/api/v2/dryrun", json=body)
        resp2 = client.post("/api/v2/dryrun", json=body)
        assert resp1.status_code == 202, resp1.text
        assert resp2.status_code == 202, resp2.text
        assert resp1.json()["command_id"] == resp2.json()["command_id"]


# ---------------------------------------------------------------------------
# RiskEngine pre_dryrun_check tests
# ---------------------------------------------------------------------------


class TestRiskEnginePreDryrunCheck:
    """Direct unit-level tests for RiskEngine.pre_dryrun_check."""

    def _engine(self):
        return RiskEngine()

    def test_pre_dryrun_check_valid(self):
        """A valid DSL and wallet should be approved."""
        engine = self._engine()
        result = engine.pre_dryrun_check(
            dsl=_valid_dsl(),
            initial_wallet=10000,
            stake_amount=100,
            max_open_trades=5,
        )
        assert result.approved is True

    def test_pre_dryrun_check_invalid_dsl(self):
        """A DSL with unsupported schema_version should not be approved."""
        engine = self._engine()
        dsl = _valid_dsl()
        dsl["schema_version"] = "0.1"
        result = engine.pre_dryrun_check(
            dsl=dsl,
            initial_wallet=10000,
            stake_amount=100,
            max_open_trades=5,
        )
        assert result.approved is False

    def test_pre_dryrun_check_negative_wallet(self):
        """A negative initial_wallet should yield DRYRUN_INVALID_WALLET."""
        engine = self._engine()
        result = engine.pre_dryrun_check(
            dsl=_valid_dsl(),
            initial_wallet=-1,
            stake_amount=100,
            max_open_trades=5,
        )
        assert result.approved is False
        error_codes = [e.code if hasattr(e, "code") else str(e) for e in result.errors]
        assert "DRYRUN_INVALID_WALLET" in " ".join(error_codes)
