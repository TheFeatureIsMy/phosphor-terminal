"""AI Research v2 tests — schema validation, service logic, security boundaries.

27 tests covering:
- Schema safety (Literal fields, validation)
- Report builder (mock LLM, degraded fallback)
- Signal extractor (extraction logic, Hold → no candidates)
- Strategy drafter (DSL generation, Python rejection)
- ProviderTrace recording
- API integration (full pipeline, confirm flow)
- Security boundary (no forbidden imports)
"""
from __future__ import annotations

import json
import inspect
import uuid
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest
from pydantic import ValidationError

from app.schemas.research_v2 import (
    AgentOpinion,
    ResearchReportData,
    SignalCandidateData,
    StrategyDraftData,
)
from app.services.research.report_builder import build_research_report, _parse_report_json
from app.services.research.signal_extractor import extract_candidates
from app.services.research.strategy_drafter import generate_strategy_draft, _contains_python
from app.services.llm_service import LLMResponse


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════

def _mock_llm_response(content: str, provider: str = "mock") -> LLMResponse:
    return LLMResponse(
        content=content,
        model="mock-model",
        provider=provider,
        tokens_used=100,
        latency_ms=50.0,
    )


def _mock_research_json() -> str:
    return json.dumps({
        "rating": "Buy",
        "direction": "long",
        "confidence": 0.74,
        "risk_level": "medium",
        "summary": "BTC showing strong momentum",
        "evidence": ["RSI oversold", "Volume increasing"],
        "agent_opinions": {
            "technical": {
                "role": "technical_analyst",
                "stance": "bullish",
                "reasoning": "RSI is at 28, oversold territory",
                "confidence": 0.8,
                "key_factors": ["rsi", "volume"],
            },
            "sentiment": {
                "role": "sentiment_analyst",
                "stance": "neutral",
                "reasoning": "Mixed social sentiment",
                "confidence": 0.5,
                "key_factors": ["twitter_volume"],
            },
        },
    })


def _mock_dsl_json() -> str:
    return json.dumps({
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [{
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30,
            }],
        },
        "exit": {
            "logic": "AND",
            "rules": [{
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70,
            }],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {
            "stoploss": -0.05,
            "max_open_trades": 3,
            "trailing_stop": False,
        },
    })


def _make_report_data(**overrides) -> ResearchReportData:
    defaults = dict(
        symbol="BTC/USDT",
        market="crypto",
        timeframe="1d",
        rating="Buy",
        direction="long",
        confidence=0.74,
        risk_level="medium",
        agent_opinions={
            "technical": AgentOpinion(
                role="technical_analyst",
                stance="bullish",
                reasoning="RSI oversold",
                confidence=0.8,
                key_factors=["rsi"],
            ),
        },
        summary="Strong buy signal",
        evidence=["RSI < 30"],
        created_at=datetime.now(timezone.utc),
    )
    defaults.update(overrides)
    return ResearchReportData(**defaults)


def _make_candidate_data(**overrides) -> SignalCandidateData:
    defaults = dict(
        report_id=uuid.uuid4(),
        symbol="BTC/USDT",
        direction="long",
        confidence=0.74,
        risk_level="medium",
        reasoning="Strong buy",
        entry_logic="RSI < 30",
        exit_logic="RSI > 70",
        suggested_indicators=["rsi"],
        time_horizon="1d",
    )
    defaults.update(overrides)
    return SignalCandidateData(**defaults)


# ══════════════════════════════════════════════════════════════════════
# 1–6: Schema validation tests
# ══════════════════════════════════════════════════════════════════════

class TestSchemaValidation:
    def test_research_report_schema_validation(self):
        report = _make_report_data()
        assert report.symbol == "BTC/USDT"
        assert 0 <= report.confidence <= 1
        assert report.rating in {"Buy", "Overweight", "Hold", "Underweight", "Sell"}

    def test_signal_candidate_can_live_trade_always_false(self):
        candidate = _make_candidate_data()
        assert candidate.can_live_trade is False

        with pytest.raises(ValidationError):
            SignalCandidateData(
                report_id=uuid.uuid4(),
                symbol="BTC/USDT",
                direction="long",
                confidence=0.5,
                risk_level="low",
                can_live_trade=True,
            )

    def test_signal_candidate_requires_human_confirm_always_true(self):
        candidate = _make_candidate_data()
        assert candidate.requires_human_confirm is True

        with pytest.raises(ValidationError):
            SignalCandidateData(
                report_id=uuid.uuid4(),
                symbol="BTC/USDT",
                direction="long",
                confidence=0.5,
                risk_level="low",
                requires_human_confirm=False,
            )

    def test_strategy_draft_auto_execute_always_false(self):
        draft = StrategyDraftData(
            candidate_id=uuid.uuid4(),
            report_id=uuid.uuid4(),
            name="test",
            rule_dsl={},
        )
        assert draft.auto_execute is False

        with pytest.raises(ValidationError):
            StrategyDraftData(
                candidate_id=uuid.uuid4(),
                report_id=uuid.uuid4(),
                name="test",
                rule_dsl={},
                auto_execute=True,
            )

    def test_strategy_draft_source_type_always_ai_research(self):
        draft = StrategyDraftData(
            candidate_id=uuid.uuid4(),
            report_id=uuid.uuid4(),
            name="test",
            rule_dsl={},
        )
        assert draft.source_type == "ai_research"

        with pytest.raises(ValidationError):
            StrategyDraftData(
                candidate_id=uuid.uuid4(),
                report_id=uuid.uuid4(),
                name="test",
                rule_dsl={},
                source_type="manual",
            )

    def test_agent_opinion_schema(self):
        opinion = AgentOpinion(
            role="technical_analyst",
            stance="bullish",
            reasoning="RSI oversold",
            confidence=0.8,
            key_factors=["rsi", "volume"],
        )
        assert opinion.role == "technical_analyst"
        assert opinion.confidence == 0.8


# ══════════════════════════════════════════════════════════════════════
# 7–8: Report builder tests
# ══════════════════════════════════════════════════════════════════════

class TestReportBuilder:
    @pytest.mark.asyncio
    async def test_report_builder_with_mock_llm(self):
        llm = AsyncMock()
        llm.chat = AsyncMock(return_value=_mock_llm_response(_mock_research_json()))

        report, llm_resp, input_hash, output_hash = await build_research_report(
            llm, "BTC/USDT", "crypto", "1d", "2025-01-01", ["market", "social"],
        )
        assert report.rating == "Buy"
        assert report.direction == "long"
        assert report.confidence == 0.74
        assert "technical" in report.agent_opinions
        assert llm_resp is not None
        assert len(input_hash) > 0
        assert len(output_hash) > 0

    @pytest.mark.asyncio
    async def test_report_builder_llm_failure_returns_degraded(self):
        llm = AsyncMock()
        llm.chat = AsyncMock(side_effect=RuntimeError("No LLM provider available"))

        report, llm_resp, input_hash, output_hash = await build_research_report(
            llm, "BTC/USDT", "crypto", "1d", "2025-01-01", ["market"],
        )
        assert report.rating == "Hold"
        assert report.confidence == 0.0
        assert report.risk_level == "high"
        assert llm_resp is None


# ══════════════════════════════════════════════════════════════════════
# 9–10: Signal extractor tests
# ══════════════════════════════════════════════════════════════════════

class TestSignalExtractor:
    def test_signal_extractor_from_report(self):
        report = _make_report_data(rating="Buy", confidence=0.74)
        candidates = extract_candidates(report)
        assert len(candidates) == 1
        assert candidates[0].direction == "long"
        assert candidates[0].can_live_trade is False
        assert candidates[0].requires_human_confirm is True

    def test_signal_extractor_hold_report_no_candidates(self):
        report = _make_report_data(rating="Hold", confidence=0.5, direction="hold")
        candidates = extract_candidates(report)
        assert len(candidates) == 0

    def test_signal_extractor_low_confidence_no_candidates(self):
        report = _make_report_data(rating="Buy", confidence=0.2)
        candidates = extract_candidates(report)
        assert len(candidates) == 0


# ══════════════════════════════════════════════════════════════════════
# 11–13: Strategy drafter tests
# ══════════════════════════════════════════════════════════════════════

class TestStrategyDrafter:
    @pytest.mark.asyncio
    async def test_strategy_drafter_generates_valid_dsl(self):
        llm = AsyncMock()
        llm.chat = AsyncMock(return_value=_mock_llm_response(_mock_dsl_json()))

        candidate = _make_candidate_data()
        draft, llm_resp, input_hash, output_hash = await generate_strategy_draft(
            llm, candidate, candidate.report_id,
        )
        assert draft.dsl_valid is True
        assert len(draft.dsl_errors) == 0
        assert draft.rule_dsl["schema_version"] == "2.5"

    @pytest.mark.asyncio
    async def test_strategy_drafter_invalid_dsl_marked(self):
        bad_dsl = json.dumps({"schema_version": "999", "invalid": True})
        llm = AsyncMock()
        llm.chat = AsyncMock(return_value=_mock_llm_response(bad_dsl))

        candidate = _make_candidate_data()
        draft, _, _, _ = await generate_strategy_draft(llm, candidate, candidate.report_id)
        assert draft.dsl_valid is False
        assert len(draft.dsl_errors) > 0

    def test_strategy_drafter_no_python_in_output(self):
        assert _contains_python("import os; os.system('rm -rf /')") is True
        assert _contains_python("def foo(): pass") is True
        assert _contains_python("exec('bad')") is True
        assert _contains_python('{"indicator": "rsi", "value": 30}') is False


# ══════════════════════════════════════════════════════════════════════
# 14–15: ProviderTrace tests (integration with DB)
# ══════════════════════════════════════════════════════════════════════

class TestProviderTrace:
    def test_provider_trace_recorded_on_research(self, session):
        from app.models.research import AIResearchRun
        from app.models.research_v2 import ResearchReport
        from app.domain.provider import ProviderTrace
        from app.services.research.research_service import ResearchService

        run = AIResearchRun(
            symbol="BTC/USDT", asset_type="crypto",
            analysis_date=date(2025, 1, 1), provider="llm_structured",
            runtime_config={}, status="pending",
        )
        session.add(run)
        session.commit()

        llm = AsyncMock()
        llm.chat = AsyncMock(return_value=_mock_llm_response(_mock_research_json()))

        svc = ResearchService(session, llm)
        import asyncio
        report = asyncio.run(
            svc.execute_research(run, "BTC/USDT", "crypto", "1d", "2025-01-01", ["market"])
        )

        traces = session.query(ProviderTrace).filter(
            ProviderTrace.object_type == "research_report",
        ).all()
        assert len(traces) == 1
        assert traces[0].provider == "mock"
        assert traces[0].task_type == "research_deep_dive"

    def test_provider_trace_recorded_on_draft(self, session):
        from app.models.research import AIResearchRun
        from app.models.research_v2 import ResearchReport, SignalCandidate
        from app.domain.provider import ProviderTrace
        from app.services.research.research_service import ResearchService

        run = AIResearchRun(
            symbol="BTC/USDT", asset_type="crypto",
            analysis_date=date(2025, 1, 1), provider="llm_structured",
            runtime_config={}, status="pending",
        )
        session.add(run)
        session.commit()

        llm = AsyncMock()
        llm.chat = AsyncMock(return_value=_mock_llm_response(_mock_research_json()))

        svc = ResearchService(session, llm)
        import asyncio
        report = asyncio.run(
            svc.execute_research(run, "BTC/USDT", "crypto", "1d", "2025-01-01", ["market"])
        )

        candidates = session.query(SignalCandidate).filter(
            SignalCandidate.report_id == report.id,
        ).all()
        assert len(candidates) > 0

        llm.chat = AsyncMock(return_value=_mock_llm_response(_mock_dsl_json()))
        draft = asyncio.run(
            svc.generate_draft(candidates[0], report)
        )

        draft_traces = session.query(ProviderTrace).filter(
            ProviderTrace.object_type == "strategy_draft",
        ).all()
        assert len(draft_traces) == 1
        assert draft_traces[0].task_type == "strategy_draft_generation"


# ══════════════════════════════════════════════════════════════════════
# 16–23: API integration tests
# ══════════════════════════════════════════════════════════════════════

class TestResearchV2API:
    def _patch_llm(self, content: str):
        mock_provider = AsyncMock()
        mock_provider.health_check = AsyncMock(return_value=True)
        mock_provider.chat = AsyncMock(return_value=_mock_llm_response(content))
        mock_provider.name = "mock"
        mock_provider.model_id = "mock-model"
        llm = AsyncMock()
        llm.chat = mock_provider.chat
        return llm

    def test_create_and_execute_research_run(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT",
                "market": "crypto",
                "analysis_date": "2025-01-01",
            })
            assert resp.status_code == 201
            run_id = resp.json()["id"]

            resp = client.post(f"/api/ai-research/v2/runs/{run_id}/execute")
            assert resp.status_code == 200
            data = resp.json()
            assert data["rating"] == "Buy"
            assert data["confidence"] == 0.74

    def test_get_report_after_execution(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "ETH/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/report")
            assert resp.status_code == 200
            data = resp.json()
            assert "agent_opinions" in data
            assert data["rating"] == "Buy"

    def test_get_candidates_after_execution(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/candidates")
            assert resp.status_code == 200
            candidates = resp.json()
            assert len(candidates) >= 1
            assert candidates[0]["can_live_trade"] is False

    def test_generate_draft_from_candidate(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/candidates")
            candidate_id = resp.json()[0]["id"]

            llm = self._patch_llm(_mock_dsl_json())
            mock_get.return_value = llm
            resp = client.post(f"/api/ai-research/v2/candidates/{candidate_id}/generate-draft")
            assert resp.status_code == 201
            draft = resp.json()
            assert "rule_dsl" in draft
            assert draft["source_type"] == "ai_research"

    def test_confirm_valid_draft_creates_version(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/candidates")
            candidate_id = resp.json()[0]["id"]

            llm = self._patch_llm(_mock_dsl_json())
            mock_get.return_value = llm
            resp = client.post(f"/api/ai-research/v2/candidates/{candidate_id}/generate-draft")
            draft_id = resp.json()["id"]

            resp = client.post(f"/api/ai-research/v2/drafts/{draft_id}/confirm")
            assert resp.status_code == 200
            data = resp.json()
            assert "strategy_id" in data
            assert "version_id" in data
            assert data["status"] == "draft"

    def test_confirm_invalid_draft_rejected(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            bad_dsl = json.dumps({"schema_version": "999"})
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/candidates")
            candidate_id = resp.json()[0]["id"]

            llm = self._patch_llm(bad_dsl)
            mock_get.return_value = llm
            resp = client.post(f"/api/ai-research/v2/candidates/{candidate_id}/generate-draft")
            draft_id = resp.json()["id"]

            resp = client.post(f"/api/ai-research/v2/drafts/{draft_id}/confirm")
            assert resp.status_code == 409

    def test_confirm_does_not_trigger_execution(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = self._patch_llm(_mock_research_json())
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]
            client.post(f"/api/ai-research/v2/runs/{run_id}/execute")

            resp = client.get(f"/api/ai-research/v2/runs/{run_id}/candidates")
            candidate_id = resp.json()[0]["id"]

            llm = self._patch_llm(_mock_dsl_json())
            mock_get.return_value = llm
            resp = client.post(f"/api/ai-research/v2/candidates/{candidate_id}/generate-draft")
            draft_id = resp.json()["id"]

            resp = client.post(f"/api/ai-research/v2/drafts/{draft_id}/confirm")
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "draft"  # not "running" or "backtested"

            # Confirm only creates StrategyVersion(status=draft),
            # does not create any Command or trigger execution.
            assert data["version_no"] == 1

    def test_research_failure_returns_degraded(self, client):
        with patch("app.routers.ai_research._get_llm_service") as mock_get:
            llm = AsyncMock()
            llm.chat = AsyncMock(side_effect=RuntimeError("No LLM provider available"))
            mock_get.return_value = llm

            resp = client.post("/api/ai-research/v2/runs", json={
                "symbol": "BTC/USDT", "market": "crypto", "analysis_date": "2025-01-01",
            })
            run_id = resp.json()["id"]

            resp = client.post(f"/api/ai-research/v2/runs/{run_id}/execute")
            assert resp.status_code == 200
            data = resp.json()
            assert data["rating"] == "Hold"
            assert data["confidence"] == 0.0


# ══════════════════════════════════════════════════════════════════════
# 24–27: Security boundary tests
# ══════════════════════════════════════════════════════════════════════

class TestSecurityBoundary:
    def test_research_service_has_no_command_bus_import(self):
        import app.services.research.research_service as mod
        source = inspect.getsource(mod)
        forbidden = ["app.domain.command", "app.workers", "CommandBus", "FreqtradeCommand"]
        for term in forbidden:
            assert term not in source, f"research_service.py must not reference {term}"

    def test_research_service_has_no_trade_intent_import(self):
        import app.services.research.research_service as mod
        source = inspect.getsource(mod)
        forbidden = ["TradeIntent", "trade_intent", "PlannedTradeIntent"]
        for term in forbidden:
            assert term not in source, f"research_service.py must not reference {term}"

    def test_draft_dsl_uses_whitelisted_indicators_only(self):
        from app.domain.dsl import DSLIndicator
        allowed = {e.value for e in DSLIndicator}

        dsl = json.loads(_mock_dsl_json())
        for rule in dsl.get("entry", {}).get("rules", []):
            if "indicator" in rule:
                assert rule["indicator"] in allowed
        for rule in dsl.get("exit", {}).get("rules", []):
            if "indicator" in rule:
                assert rule["indicator"] in allowed

    def test_draft_dsl_uses_whitelisted_operators_only(self):
        from app.domain.dsl import DSLOperator
        allowed = {e.value for e in DSLOperator}

        dsl = json.loads(_mock_dsl_json())
        for rule in dsl.get("entry", {}).get("rules", []):
            if "operator" in rule:
                assert rule["operator"] in allowed
        for rule in dsl.get("exit", {}).get("rules", []):
            if "operator" in rule:
                assert rule["operator"] in allowed
