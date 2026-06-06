"""Growth Engine tests — schema safety, trade analysis, report building,
candidate generation, API integration, security boundaries.
"""
from __future__ import annotations

import inspect
import uuid
from datetime import datetime, timezone, timedelta
from typing import Literal

import pytest
from pydantic import ValidationError

from app.schemas.growth import (
    ConfirmCandidateResponse,
    DailyReviewRequest,
    Finding,
    GrowthReportData,
    GrowthReportResponse,
    RunReviewRequest,
    StrategyCandidateData,
    StrategyCandidateResponse,
    TradeMetrics,
)
from app.services.growth.trade_analyzer import compute_metrics
from app.services.growth.report_builder import generate_findings, generate_suggestions
from app.services.growth.candidate_generator import generate_candidate


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════

def _make_mock_trade(
    profit_pct=0.05, profit_abs=10.0, symbol="BTC/USDT",
    opened_at=None, closed_at=None, status="closed",
):
    class MockTrade:
        pass
    t = MockTrade()
    t.profit_pct = profit_pct
    t.profit_abs = profit_abs
    t.symbol = symbol
    t.status = status
    now = datetime.now(timezone.utc)
    t.opened_at = opened_at or (now - timedelta(hours=4))
    t.closed_at = closed_at or now
    return t


def _sample_dsl() -> dict:
    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": "lt", "value": 30, "params": {"period": 14}},
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": "gt", "value": 70, "params": {"period": 14}},
            ],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {
            "stoploss": -0.05,
            "max_open_trades": 3,
            "trailing_stop": False,
        },
    }


# ══════════════════════════════════════════════════════════════════════
# 1. Schema Safety
# ══════════════════════════════════════════════════════════════════════

class TestSchemas:
    def test_strategy_candidate_auto_execute_always_false(self):
        data = StrategyCandidateData(
            source_growth_report_id=uuid.uuid4(),
            source_strategy_version_id=uuid.uuid4(),
            candidate_dsl=_sample_dsl(),
            auto_execute=False,
        )
        assert data.auto_execute is False

    def test_strategy_candidate_auto_execute_rejects_true(self):
        with pytest.raises(ValidationError):
            StrategyCandidateData(
                source_growth_report_id=uuid.uuid4(),
                source_strategy_version_id=uuid.uuid4(),
                candidate_dsl=_sample_dsl(),
                auto_execute=True,
            )

    def test_strategy_candidate_default_status_draft(self):
        data = StrategyCandidateData(
            source_growth_report_id=uuid.uuid4(),
            source_strategy_version_id=uuid.uuid4(),
            candidate_dsl=_sample_dsl(),
        )
        assert data.status == "draft"
        assert data.auto_execute is False

    def test_trade_metrics_defaults(self):
        m = TradeMetrics()
        assert m.total_trades == 0
        assert m.win_rate == 0.0
        assert m.symbols_traded == []

    def test_finding_schema(self):
        f = Finding(category="strength", description="High win rate")
        assert f.category == "strength"
        assert f.evidence == {}

    def test_daily_review_request_bounds(self):
        r = DailyReviewRequest(days=1)
        assert r.days == 1
        with pytest.raises(ValidationError):
            DailyReviewRequest(days=0)
        with pytest.raises(ValidationError):
            DailyReviewRequest(days=31)


# ══════════════════════════════════════════════════════════════════════
# 2. Trade Analyzer
# ══════════════════════════════════════════════════════════════════════

class TestTradeAnalyzer:
    def test_empty_trades(self):
        m = compute_metrics([])
        assert m.total_trades == 0
        assert m.win_rate == 0.0

    def test_all_winners(self):
        trades = [_make_mock_trade(profit_pct=0.05, profit_abs=10) for _ in range(5)]
        m = compute_metrics(trades)
        assert m.total_trades == 5
        assert m.win_count == 5
        assert m.loss_count == 0
        assert m.win_rate == 1.0

    def test_mixed_trades(self):
        trades = [
            _make_mock_trade(profit_pct=0.10, profit_abs=20),
            _make_mock_trade(profit_pct=-0.05, profit_abs=-10),
            _make_mock_trade(profit_pct=0.0, profit_abs=0),
        ]
        m = compute_metrics(trades)
        assert m.total_trades == 3
        assert m.win_count == 1
        assert m.loss_count == 1
        assert m.breakeven_count == 1
        assert m.total_pnl == 10.0

    def test_symbols_tracked(self):
        trades = [
            _make_mock_trade(symbol="BTC/USDT"),
            _make_mock_trade(symbol="ETH/USDT"),
            _make_mock_trade(symbol="BTC/USDT"),
        ]
        m = compute_metrics(trades)
        assert m.symbols_traded == ["BTC/USDT", "ETH/USDT"]

    def test_hold_duration_calculated(self):
        now = datetime.now(timezone.utc)
        trades = [_make_mock_trade(
            opened_at=now - timedelta(hours=2),
            closed_at=now,
        )]
        m = compute_metrics(trades)
        assert abs(m.avg_hold_duration_hours - 2.0) < 0.1


# ══════════════════════════════════════════════════════════════════════
# 3. Report Builder
# ══════════════════════════════════════════════════════════════════════

class TestReportBuilder:
    def test_no_trades_finding(self):
        m = TradeMetrics()
        findings = generate_findings(m)
        assert len(findings) == 1
        assert findings[0].category == "pattern"
        assert "No trades" in findings[0].description

    def test_high_win_rate_strength(self):
        m = TradeMetrics(total_trades=10, win_count=7, win_rate=0.7)
        findings = generate_findings(m)
        categories = [f.category for f in findings]
        assert "strength" in categories

    def test_low_win_rate_weakness(self):
        m = TradeMetrics(total_trades=10, win_count=2, win_rate=0.2)
        findings = generate_findings(m)
        categories = [f.category for f in findings]
        assert "weakness" in categories

    def test_high_drawdown_risk(self):
        m = TradeMetrics(total_trades=5, max_drawdown_pct=15.0)
        findings = generate_findings(m)
        categories = [f.category for f in findings]
        assert "risk" in categories

    def test_suggestions_for_drawdown(self):
        m = TradeMetrics(total_trades=5, max_drawdown_pct=15.0)
        findings = [Finding(category="risk", description="High max drawdown at 15.0%")]
        suggestions = generate_suggestions(m, findings)
        assert any("stop-loss" in s.lower() or "drawdown" in s.lower() for s in suggestions)

    def test_suggestions_for_losing_strategy(self):
        m = TradeMetrics(total_trades=10, profit_factor=0.5)
        findings = []
        suggestions = generate_suggestions(m, findings)
        assert any("losing" in s.lower() or "net" in s.lower() for s in suggestions)


# ══════════════════════════════════════════════════════════════════════
# 4. Candidate Generator
# ══════════════════════════════════════════════════════════════════════

class TestCandidateGenerator:
    def test_generate_candidate_auto_execute_false(self):
        dsl = _sample_dsl()
        m = TradeMetrics(total_trades=10, win_count=3, win_rate=0.3, max_drawdown_pct=12.0)
        findings = [Finding(category="risk", description="High drawdown")]
        c = generate_candidate(uuid.uuid4(), uuid.uuid4(), dsl, m, findings)
        assert c.auto_execute is False
        assert c.status == "draft"

    def test_generate_candidate_tightens_stoploss_on_drawdown(self):
        dsl = _sample_dsl()
        m = TradeMetrics(total_trades=10, max_drawdown_pct=12.0)
        findings = [Finding(category="risk", description="High drawdown")]
        c = generate_candidate(uuid.uuid4(), uuid.uuid4(), dsl, m, findings)
        new_sl = c.candidate_dsl.get("risk", {}).get("stoploss")
        assert new_sl is not None
        assert new_sl > -0.05  # tighter than original -0.05

    def test_generate_candidate_has_rationale(self):
        dsl = _sample_dsl()
        m = TradeMetrics(total_trades=10, win_rate=0.3, profit_factor=0.8)
        findings = [
            Finding(category="weakness", description="Low win rate"),
            Finding(category="risk", description="Net losing"),
        ]
        c = generate_candidate(uuid.uuid4(), uuid.uuid4(), dsl, m, findings)
        assert "Low win rate" in c.rationale

    def test_generate_candidate_reduces_trades_on_loss(self):
        dsl = _sample_dsl()
        m = TradeMetrics(total_trades=10, profit_factor=0.5)
        findings = []
        c = generate_candidate(uuid.uuid4(), uuid.uuid4(), dsl, m, findings)
        new_mot = c.candidate_dsl.get("risk", {}).get("max_open_trades")
        assert new_mot is not None
        assert new_mot < 3


# ══════════════════════════════════════════════════════════════════════
# 5. API Integration
# ══════════════════════════════════════════════════════════════════════

class TestGrowthAPI:
    def test_daily_review_creates_report(self, client):
        resp = client.post("/api/growth/reports/daily-review", json={"days": 1})
        assert resp.status_code == 201
        data = resp.json()
        assert data["report_type"] == "daily_review"
        assert "id" in data

    def test_list_reports_empty(self, client):
        resp = client.get("/api/growth/reports")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_get_report_not_found(self, client):
        fake_id = str(uuid.uuid4())
        resp = client.get(f"/api/growth/reports/{fake_id}")
        assert resp.status_code == 404

    def test_get_report_after_creation(self, client):
        create_resp = client.post("/api/growth/reports/daily-review", json={"days": 1})
        assert create_resp.status_code == 201
        report_id = create_resp.json()["id"]
        get_resp = client.get(f"/api/growth/reports/{report_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["id"] == report_id

    def test_run_review_missing_run_returns_404(self, client):
        fake_id = str(uuid.uuid4())
        resp = client.post("/api/growth/reports/run-review", json={"strategy_run_id": fake_id})
        assert resp.status_code == 404

    def test_list_candidates_empty(self, client):
        resp = client.get("/api/growth/candidates")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_get_candidate_not_found(self, client):
        fake_id = str(uuid.uuid4())
        resp = client.get(f"/api/growth/candidates/{fake_id}")
        assert resp.status_code == 404

    def test_generate_candidate_missing_report_returns_400(self, client):
        fake_id = str(uuid.uuid4())
        resp = client.post(f"/api/growth/candidates/generate/{fake_id}")
        assert resp.status_code == 400


# ══════════════════════════════════════════════════════════════════════
# 6. Security Boundaries
# ══════════════════════════════════════════════════════════════════════

class TestSecurityBoundary:
    def test_growth_service_has_no_command_bus_import(self):
        from app.services.growth import growth_service
        src = inspect.getsource(growth_service)
        for forbidden in ["CommandBus", "TradeIntent", "FreqtradeAdapter"]:
            assert forbidden not in src, f"growth_service must not reference {forbidden}"

    def test_growth_service_has_no_docker_import(self):
        from app.services.growth import growth_service
        src = inspect.getsource(growth_service)
        assert "import docker" not in src

    def test_candidate_generator_no_execution_imports(self):
        from app.services.growth import candidate_generator
        src = inspect.getsource(candidate_generator)
        for forbidden in ["CommandBus", "TradeIntent", "FreqtradeAdapter", "RiskEngine"]:
            assert forbidden not in src, f"candidate_generator must not reference {forbidden}"

    def test_growth_service_literal_safety(self):
        from typing import get_type_hints
        from app.services.growth.growth_service import GrowthService
        hints = get_type_hints(GrowthService, include_extras=True)
        assert hints.get("can_live_trade") == Literal[False]
        assert hints.get("auto_execute") == Literal[False]
        assert hints.get("requires_human_confirm") == Literal[True]

    def test_router_has_no_forbidden_imports(self):
        from app.routers import growth
        src = inspect.getsource(growth)
        for forbidden in ["CommandBus", "TradeIntent", "FreqtradeAdapter", "RiskEngine"]:
            assert forbidden not in src, f"growth router must not reference {forbidden}"
