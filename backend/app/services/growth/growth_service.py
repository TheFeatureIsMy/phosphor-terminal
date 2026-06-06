"""Growth Service — orchestrates trade review, reporting, and candidate generation.

Dependency boundary:
  ALLOWED: Execution Ledger (read), ExecutionTrade (read), StrategyVersion (read),
           DSLValidator, DSLHasher, growth sub-modules
  FORBIDDEN: command bus, freqtrade adapter, trade intent, risk engine, container runtime
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone, timedelta
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.growth import GrowthReport, StrategyCandidate
from app.domain.order import ExecutionTrade
from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.schemas.growth import (
    Finding,
    GrowthReportData,
    StrategyCandidateData,
    TradeMetrics,
)
from app.services.dsl_hasher import compute_dsl_hash
from app.services.growth.candidate_generator import generate_candidate
from app.services.growth.report_builder import generate_findings, generate_suggestions
from app.services.growth.trade_analyzer import compute_metrics


class GrowthService:
    can_live_trade: Literal[False] = False
    auto_execute: Literal[False] = False
    requires_human_confirm: Literal[True] = True

    def __init__(self, db: Session) -> None:
        self._db = db

    # ── Run Review ────────────────────────────────────────────────────

    def create_run_review(self, strategy_run_id: uuid.UUID) -> GrowthReport:
        run = self._db.get(StrategyRun, strategy_run_id)
        if not run:
            raise ValueError(f"StrategyRun {strategy_run_id} not found")

        trades = self._get_trades_for_run(strategy_run_id)
        metrics = compute_metrics(trades)
        findings = generate_findings(metrics)
        suggestions = generate_suggestions(metrics, findings)

        report = GrowthReport(
            strategy_run_id=strategy_run_id,
            strategy_version_id=run.strategy_version_id,
            report_type="run_review",
            period_start=run.started_at,
            period_end=run.stopped_at or datetime.now(timezone.utc),
            metrics=metrics.model_dump(),
            findings=[f.model_dump() for f in findings],
        )
        self._db.add(report)
        self._db.commit()
        return report

    # ── Daily Review ──────────────────────────────────────────────────

    def create_daily_review(self, days: int = 1) -> GrowthReport:
        now = datetime.now(timezone.utc)
        start = now - timedelta(days=days)

        trades = self._get_trades_in_range(start, now)
        metrics = compute_metrics(trades)
        findings = generate_findings(metrics)
        suggestions = generate_suggestions(metrics, findings)

        report = GrowthReport(
            report_type="daily_review",
            period_start=start,
            period_end=now,
            metrics=metrics.model_dump(),
            findings=[f.model_dump() for f in findings],
        )
        self._db.add(report)
        self._db.commit()
        return report

    # ── Strategy Performance Report ───────────────────────────────────

    def strategy_performance(self, strategy_version_id: uuid.UUID) -> GrowthReport:
        version = self._db.get(StrategyVersion, strategy_version_id)
        if not version:
            raise ValueError(f"StrategyVersion {strategy_version_id} not found")

        runs = list(self._db.scalars(
            select(StrategyRun)
            .where(StrategyRun.strategy_version_id == strategy_version_id)
        ).all())

        all_trades: list[ExecutionTrade] = []
        earliest_start = None
        latest_end = None
        for run in runs:
            all_trades.extend(self._get_trades_for_run(run.id))
            if run.started_at:
                if earliest_start is None or run.started_at < earliest_start:
                    earliest_start = run.started_at
            if run.stopped_at:
                if latest_end is None or run.stopped_at > latest_end:
                    latest_end = run.stopped_at

        metrics = compute_metrics(all_trades)
        findings = generate_findings(metrics)

        report = GrowthReport(
            strategy_version_id=strategy_version_id,
            report_type="strategy_performance",
            period_start=earliest_start,
            period_end=latest_end or datetime.now(timezone.utc),
            metrics=metrics.model_dump(),
            findings=[f.model_dump() for f in findings],
        )
        self._db.add(report)
        self._db.commit()
        return report

    # ── Generate Candidate ────────────────────────────────────────────

    def generate_candidate(self, report_id: uuid.UUID) -> StrategyCandidate:
        report = self._db.get(GrowthReport, report_id)
        if not report:
            raise ValueError(f"GrowthReport {report_id} not found")
        if not report.strategy_version_id:
            raise ValueError("Report has no strategy_version_id — cannot generate candidate")

        version = self._db.get(StrategyVersion, report.strategy_version_id)
        if not version:
            raise ValueError(f"StrategyVersion {report.strategy_version_id} not found")

        metrics = TradeMetrics(**(report.metrics or {}))
        findings = [Finding(**f) for f in (report.findings or [])]

        candidate_data = generate_candidate(
            report_id=report.id,
            source_version_id=version.id,
            source_dsl=version.rule_dsl,
            metrics=metrics,
            findings=findings,
        )

        candidate = StrategyCandidate(
            source_growth_report_id=candidate_data.source_growth_report_id,
            source_strategy_version_id=candidate_data.source_strategy_version_id,
            candidate_dsl=candidate_data.candidate_dsl,
            candidate_dsl_hash=candidate_data.candidate_dsl_hash,
            status=candidate_data.status,
            rationale=candidate_data.rationale,
            dsl_valid=candidate_data.dsl_valid,
            dsl_errors=candidate_data.dsl_errors,
            auto_execute=False,
        )
        self._db.add(candidate)
        self._db.commit()
        return candidate

    # ── Confirm Candidate → StrategyVersion ───────────────────────────

    def confirm_candidate(self, candidate_id: uuid.UUID) -> tuple[Any, Any]:
        candidate = self._db.get(StrategyCandidate, candidate_id)
        if not candidate:
            raise ValueError(f"StrategyCandidate {candidate_id} not found")
        if not candidate.dsl_valid:
            raise ValueError("Cannot confirm candidate with invalid DSL")
        if candidate.status == "confirmed":
            raise ValueError("Candidate already confirmed")

        version = self._db.get(StrategyVersion, candidate.source_strategy_version_id)
        if not version:
            raise ValueError("Source strategy version not found")

        repo = StrategyRepository(self._db)
        strategy = self._db.get(StrategyV2, version.strategy_id)

        next_no = repo.next_version_no(version.strategy_id)
        new_version = StrategyVersion(
            strategy_id=version.strategy_id,
            version_no=next_no,
            status="draft",
            dsl_version="2.5",
            rule_dsl=candidate.candidate_dsl,
            dsl_hash=compute_dsl_hash(candidate.candidate_dsl),
            created_by="growth_engine",
        )
        repo.create_version(new_version)

        candidate.status = "confirmed"
        self._db.commit()

        return strategy, new_version

    # ── List / Get ────────────────────────────────────────────────────

    def list_reports(
        self, *, report_type: str | None = None, offset: int = 0, limit: int = 50,
    ) -> list[GrowthReport]:
        stmt = select(GrowthReport)
        if report_type:
            stmt = stmt.where(GrowthReport.report_type == report_type)
        stmt = stmt.order_by(GrowthReport.created_at.desc()).offset(offset).limit(limit)
        return list(self._db.scalars(stmt).all())

    def get_report(self, report_id: uuid.UUID) -> GrowthReport | None:
        return self._db.get(GrowthReport, report_id)

    def list_candidates(
        self, *, report_id: uuid.UUID | None = None, offset: int = 0, limit: int = 50,
    ) -> list[StrategyCandidate]:
        stmt = select(StrategyCandidate)
        if report_id:
            stmt = stmt.where(StrategyCandidate.source_growth_report_id == report_id)
        stmt = stmt.order_by(StrategyCandidate.created_at.desc()).offset(offset).limit(limit)
        return list(self._db.scalars(stmt).all())

    def get_candidate(self, candidate_id: uuid.UUID) -> StrategyCandidate | None:
        return self._db.get(StrategyCandidate, candidate_id)

    # ── Internal helpers ──────────────────────────────────────────────

    def _get_trades_for_run(self, strategy_run_id: uuid.UUID) -> list[ExecutionTrade]:
        stmt = (
            select(ExecutionTrade)
            .where(ExecutionTrade.strategy_run_id == strategy_run_id)
            .where(ExecutionTrade.status == "closed")
        )
        return list(self._db.scalars(stmt).all())

    def _get_trades_in_range(self, start: datetime, end: datetime) -> list[ExecutionTrade]:
        stmt = (
            select(ExecutionTrade)
            .where(ExecutionTrade.closed_at >= start)
            .where(ExecutionTrade.closed_at <= end)
            .where(ExecutionTrade.status == "closed")
        )
        return list(self._db.scalars(stmt).all())
