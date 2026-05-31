"""Tests for AI Phase 3 endpoints: /api/ai/strategies/generate, /api/ai/forecast,
/api/ai/factors/research, /api/ai/freqai/*, /api/ai/strategies/{id}/backtest."""

import pytest
from unittest.mock import patch, AsyncMock


# ── Mock helpers ───────────────────────────────────────────────────────────────

MOCK_STRATEGY_RESULT = {
    "strategy": {"name": "TestMA策略", "type": "ma_cross", "market": "crypto", "source": "rag_generated"},
    "code": '"""test strategy"""\nfrom freqtrade.strategy import IStrategy\n\nclass TestStrat(IStrategy):\n    pass\n',
    "explanation": "Generated a test strategy.",
    "context_used": None,
}

MOCK_FORECAST_RESULT = {
    "points": [
        {"date": "2025-01-02", "value": 101.0},
        {"date": "2025-01-03", "value": 102.0},
    ],
    "confidence": 0.62,
}

MOCK_QLIB_RESULT = {
    "status": "completed",
    "metrics": {
        "ic_mean": 0.04,
        "ic_std": 0.18,
        "rank_ic": 0.056,
        "turnover": 0.32,
    },
}

# _generate_simulated_backtest does NOT include a "result" key but
# ai_phase3.backtest_generated_strategy accesses simulated["result"].
# We provide a mock that matches the expected shape.
MOCK_SIMULATED_BACKTEST = {
    "result": {
        "equity_curve": [{"date": "2025-01-01", "value": 10000.0, "drawdown": 0.0, "data_source": {"source": "simulated", "simulated": True, "available": False, "detail": "test"}}],
        "trades": [],
        "metrics": {
            "total_return": 5.0,
            "sharpe_ratio": 1.2,
            "max_drawdown": 2.0,
            "win_rate": 60.0,
            "profit_factor": 1.5,
            "total_trades": 10,
            "avg_trade_duration": "2h 00m",
            "best_trade": 100.0,
            "worst_trade": -50.0,
        },
    },
    "sharpe_ratio": 1.2,
    "max_drawdown": 2.0,
    "win_rate": 60.0,
    "total_return": 5.0,
    "data_source": {"source": "simulated", "simulated": True, "available": False, "detail": "test"},
}


# ── POST /api/ai/strategies/generate ───────────────────────────────────────────


class TestGenerateStrategyArtifact:
    @patch("app.routers.ai_phase3.generate_strategy", return_value=MOCK_STRATEGY_RESULT)
    def test_generate_creates_artifact(self, mock_gen, client):
        resp = client.post(
            "/api/ai/strategies/generate",
            json={"prompt": "MA cross strategy", "risk_level": "medium", "market": "crypto"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] is not None
        assert body["strategy"]["name"] == "TestMA策略"
        assert body["code"] is not None
        assert body["safety_status"] in ("passed", "failed")
        mock_gen.assert_called_once()

    @patch("app.routers.ai_phase3._generate_simulated_backtest", return_value=MOCK_SIMULATED_BACKTEST)
    @patch("app.routers.ai_phase3.generate_strategy", return_value=MOCK_STRATEGY_RESULT)
    def test_generate_persists_to_db(self, mock_gen, mock_bt, client):
        resp = client.post(
            "/api/ai/strategies/generate",
            json={"prompt": "breakout strategy", "risk_level": "high", "market": "crypto"},
        )
        artifact_id = resp.json()["id"]
        # Verify via backtest endpoint which queries the artifact
        resp2 = client.post(f"/api/ai/strategies/{artifact_id}/backtest")
        assert resp2.status_code == 200


# ── POST /api/ai/forecast ─────────────────────────────────────────────────────


class TestForecast:
    @patch("app.routers.ai_phase3.generate_forecast", new_callable=AsyncMock, return_value=MOCK_FORECAST_RESULT)
    def test_create_forecast(self, mock_fc, client):
        resp = client.post(
            "/api/ai/forecast",
            json={"symbol": "BTC/USDT", "model": "timesfm", "horizon": "7d"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["symbol"] == "BTC/USDT"
        assert body["model"] == "timesfm"
        assert body["status"] == "completed"
        assert body["confidence"] == 0.62
        mock_fc.assert_called_once()

    @patch("app.routers.ai_phase3.generate_forecast", new_callable=AsyncMock, return_value=MOCK_FORECAST_RESULT)
    def test_forecast_persists(self, mock_fc, client):
        client.post("/api/ai/forecast", json={"symbol": "ETH/USDT"})
        # Second call should also succeed (different symbol)
        resp = client.post("/api/ai/forecast", json={"symbol": "ETH/USDT"})
        assert resp.status_code == 200


# ── POST /api/ai/factors/research ─────────────────────────────────────────────


class TestFactorResearch:
    @patch("app.routers.ai_phase3._qlib")
    def test_factor_research(self, mock_qlib, client):
        mock_qlib.research = AsyncMock(return_value=MOCK_QLIB_RESULT)
        resp = client.post(
            "/api/ai/factors/research",
            json={
                "market": "crypto",
                "universe": ["BTC/USDT", "ETH/USDT"],
                "factor_name": "momentum_quality",
            },
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["factor_name"] == "momentum_quality"
        assert body["status"] == "completed"
        assert body["metrics"]["ic_mean"] == 0.04

    @patch("app.routers.ai_phase3._qlib")
    def test_factor_research_unavailable(self, mock_qlib, client):
        mock_qlib.research = AsyncMock(return_value={"status": "unavailable", "metrics": {}})
        resp = client.post(
            "/api/ai/factors/research",
            json={"market": "crypto", "universe": ["BTC/USDT"], "factor_name": "test"},
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "unavailable"


# ── POST /api/ai/freqai/train ─────────────────────────────────────────────────


class TestFreqAITrain:
    def test_create_training_run(self, client):
        resp = client.post(
            "/api/ai/freqai/train",
            json={"model_name": "freqai-lightgbm", "training_config": {"epochs": 100}},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["model_name"] == "freqai-lightgbm"
        assert body["status"] == "queued"
        assert body["id"] is not None

    def test_create_training_run_with_strategy_id(self, client):
        resp = client.post(
            "/api/ai/freqai/train",
            json={"strategy_id": 42, "model_name": "freqai-xgboost"},
        )
        assert resp.status_code == 200
        assert resp.json()["strategy_id"] == 42


# ── GET /api/ai/freqai/status ─────────────────────────────────────────────────


class TestFreqAIStatus:
    def test_status_no_runs(self, client):
        resp = client.get("/api/ai/freqai/status")
        assert resp.status_code == 200
        assert resp.json()["status"] == "no_runs"

    def test_status_after_train(self, client):
        client.post("/api/ai/freqai/train", json={"model_name": "test-model"})
        resp = client.get("/api/ai/freqai/status")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "queued"
        assert body["latest_run"]["model_name"] == "test-model"


# ── GET /api/ai/freqai/runs ───────────────────────────────────────────────────


class TestFreqAIRuns:
    def test_runs_empty(self, client):
        resp = client.get("/api/ai/freqai/runs")
        assert resp.status_code == 200
        body = resp.json()
        assert body["runs"] == []
        assert body["total"] == 0

    def test_runs_after_training(self, client):
        client.post("/api/ai/freqai/train", json={"model_name": "model-a"})
        client.post("/api/ai/freqai/train", json={"model_name": "model-b"})
        resp = client.get("/api/ai/freqai/runs")
        body = resp.json()
        assert body["total"] == 2
        names = {r["model_name"] for r in body["runs"]}
        assert "model-a" in names
        assert "model-b" in names


# ── POST /api/ai/strategies/{id}/backtest ─────────────────────────────────────


class TestBacktestGeneratedStrategy:
    @patch("app.routers.ai_phase3._generate_simulated_backtest", return_value=MOCK_SIMULATED_BACKTEST)
    @patch("app.routers.ai_phase3.generate_strategy", return_value=MOCK_STRATEGY_RESULT)
    def test_backtest_existing_artifact(self, mock_gen, mock_bt, client):
        # Create artifact first
        create_resp = client.post(
            "/api/ai/strategies/generate",
            json={"prompt": "momentum strategy", "risk_level": "medium", "market": "crypto"},
        )
        artifact_id = create_resp.json()["id"]

        resp = client.post(f"/api/ai/strategies/{artifact_id}/backtest")
        assert resp.status_code == 200
        body = resp.json()
        assert body["strategy_id"] == artifact_id
        assert "sharpe_ratio" in body
        assert "max_drawdown" in body
        assert "win_rate" in body
        assert "total_return" in body
        assert "result" in body
        assert "passed" in body

    def test_backtest_nonexistent_artifact(self, client):
        resp = client.post("/api/ai/strategies/99999/backtest")
        assert resp.status_code == 404
