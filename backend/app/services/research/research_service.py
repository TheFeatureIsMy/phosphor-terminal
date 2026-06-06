"""AI Research Service — orchestrates read-only research pipeline.

Dependency boundary:
  ALLOWED: LLMService, DSLValidator, ProviderTrace, research sub-modules
  FORBIDDEN: command bus, freqtrade adapter, trade intent, risk engine, docker
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.provider import ProviderTrace
from app.models.research import AIResearchRun
from app.models.research_v2 import (
    ResearchReport as ResearchReportModel,
    SignalCandidate as SignalCandidateModel,
    StrategyDraft as StrategyDraftModel,
)
from app.schemas.research_v2 import (
    ResearchReportData,
    SignalCandidateData,
    StrategyDraftData,
)
from app.services.llm_service import LLMResponse, LLMService
from app.services.research.report_builder import build_research_report
from app.services.research.signal_extractor import extract_candidates
from app.services.research.strategy_drafter import generate_strategy_draft


class ResearchService:
    def __init__(self, db: Session, llm_service: LLMService) -> None:
        self._db = db
        self._llm = llm_service

    # ── Run research ──────────────────────────────────────────────────

    async def execute_research(
        self,
        run: AIResearchRun,
        symbol: str,
        market: str,
        timeframe: str,
        analysis_date: str,
        selected_analysts: list[str],
    ) -> ResearchReportModel:
        run.status = "running"
        run.started_at = datetime.now(timezone.utc)
        self._db.commit()

        report_data, llm_response, input_hash, output_hash = await build_research_report(
            self._llm, symbol, market, timeframe, analysis_date, selected_analysts,
        )

        report_model = ResearchReportModel(
            run_id=run.id,
            symbol=report_data.symbol,
            market=report_data.market,
            timeframe=report_data.timeframe,
            rating=report_data.rating,
            direction=report_data.direction.value if hasattr(report_data.direction, 'value') else str(report_data.direction),
            confidence=report_data.confidence,
            risk_level=report_data.risk_level.value if hasattr(report_data.risk_level, 'value') else str(report_data.risk_level),
            agent_opinions={k: v.model_dump() for k, v in report_data.agent_opinions.items()},
            summary=report_data.summary,
            evidence=report_data.evidence,
        )
        self._db.add(report_model)
        self._db.flush()

        if llm_response:
            trace = self._record_trace(
                object_type="research_report",
                object_id=report_model.id,
                task_type="research_deep_dive",
                llm_response=llm_response,
                input_hash=input_hash,
                output_hash=output_hash,
            )
            report_model.provider_trace_id = trace.id

        candidates_data = extract_candidates(report_data)
        for cd in candidates_data:
            direction_str = cd.direction.value if hasattr(cd.direction, 'value') else str(cd.direction)
            risk_str = cd.risk_level.value if hasattr(cd.risk_level, 'value') else str(cd.risk_level)
            cand_model = SignalCandidateModel(
                id=cd.candidate_id,
                report_id=report_model.id,
                symbol=cd.symbol,
                direction=direction_str,
                confidence=cd.confidence,
                risk_level=risk_str,
                reasoning=cd.reasoning,
                entry_logic=cd.entry_logic,
                exit_logic=cd.exit_logic,
                suggested_indicators=cd.suggested_indicators,
                time_horizon=cd.time_horizon,
                can_live_trade=False,
                can_backtest=cd.can_backtest,
                can_paper_trade=cd.can_paper_trade,
                requires_human_confirm=True,
            )
            self._db.add(cand_model)

        is_degraded = report_data.confidence == 0.0 and report_data.rating == "Hold"
        run.status = "degraded" if is_degraded else "completed"
        run.rating = report_data.rating
        run.confidence = report_data.confidence
        run.final_decision = report_data.summary
        run.completed_at = datetime.now(timezone.utc)
        self._db.commit()

        return report_model

    # ── Generate draft ────────────────────────────────────────────────

    async def generate_draft(
        self,
        candidate: SignalCandidateModel,
        report: ResearchReportModel,
        name_hint: str | None = None,
    ) -> StrategyDraftModel:
        candidate_data = SignalCandidateData(
            candidate_id=candidate.id,
            report_id=candidate.report_id,
            symbol=candidate.symbol,
            direction=candidate.direction,
            confidence=candidate.confidence,
            risk_level=candidate.risk_level,
            reasoning=candidate.reasoning,
            entry_logic=candidate.entry_logic,
            exit_logic=candidate.exit_logic,
            suggested_indicators=candidate.suggested_indicators,
            time_horizon=candidate.time_horizon,
        )

        draft_data, llm_response, input_hash, output_hash = await generate_strategy_draft(
            self._llm, candidate_data, report.id, name_hint,
        )

        draft_model = StrategyDraftModel(
            id=draft_data.draft_id,
            candidate_id=candidate.id,
            report_id=report.id,
            name=draft_data.name,
            description=draft_data.description,
            rule_dsl=draft_data.rule_dsl,
            dsl_valid=draft_data.dsl_valid,
            dsl_errors=draft_data.dsl_errors,
            dsl_warnings=draft_data.dsl_warnings,
            source_type="ai_research",
            auto_execute=False,
            requires_human_confirm=True,
        )
        self._db.add(draft_model)
        self._db.flush()

        if llm_response:
            trace = self._record_trace(
                object_type="strategy_draft",
                object_id=draft_model.id,
                task_type="strategy_draft_generation",
                llm_response=llm_response,
                input_hash=input_hash,
                output_hash=output_hash,
            )
            draft_model.provider_trace_id = trace.id

        self._db.commit()
        return draft_model

    # ── Confirm draft → StrategyVersion ───────────────────────────────

    def confirm_draft(self, draft: StrategyDraftModel) -> tuple[Any, Any]:
        """Confirm a valid draft → create StrategyV2 + StrategyVersion(status=draft).

        Returns (strategy, version). Does NOT trigger backtest/dry-run/execution.
        """
        from app.domain.strategy import StrategyV2, StrategyVersion
        from app.repositories.strategy_repository import StrategyRepository
        from app.services.dsl_hasher import compute_dsl_hash

        if not draft.dsl_valid:
            raise ValueError("Cannot confirm draft with invalid DSL")

        if draft.confirmed_strategy_id is not None:
            raise ValueError("Draft already confirmed")

        repo = StrategyRepository(self._db)

        strategy = StrategyV2(
            name=draft.name,
            description=draft.description,
            strategy_type="rule_dsl",
            source_type="ai_research",
            status="draft",
        )
        repo.create_strategy(strategy)

        version = StrategyVersion(
            strategy_id=strategy.id,
            version_no=1,
            status="draft",
            dsl_version="2.5",
            rule_dsl=draft.rule_dsl,
            dsl_hash=compute_dsl_hash(draft.rule_dsl),
            created_by="ai_research",
        )
        repo.create_version(version)

        draft.confirmed_strategy_id = strategy.id
        draft.confirmed_at = datetime.now(timezone.utc)
        self._db.commit()

        return strategy, version

    # ── Internal helpers ──────────────────────────────────────────────

    def _record_trace(
        self,
        object_type: str,
        object_id: uuid.UUID,
        task_type: str,
        llm_response: LLMResponse,
        input_hash: str,
        output_hash: str,
        privacy_level: str = "low",
    ) -> ProviderTrace:
        trace = ProviderTrace(
            object_type=object_type,
            object_id=object_id,
            provider=llm_response.provider,
            model=llm_response.model,
            task_type=task_type,
            privacy_level=privacy_level,
            latency_ms=int(llm_response.latency_ms),
            estimated_cost_usd=self._estimate_cost(llm_response),
            input_hash=f"sha256:{input_hash}",
            output_hash=f"sha256:{output_hash}",
            status="success",
        )
        self._db.add(trace)
        self._db.flush()
        return trace

    @staticmethod
    def _estimate_cost(resp: LLMResponse) -> float:
        rates = {
            "openai": 0.00001,
            "anthropic": 0.000012,
            "ollama": 0.0,
        }
        rate = rates.get(resp.provider, 0.00001)
        return round(resp.tokens_used * rate, 6)
