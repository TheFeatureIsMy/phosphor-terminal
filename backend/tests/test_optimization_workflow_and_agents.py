"""Phase 6 tests — StrategyOptimizationWorkflow (PRD §10.3) + agents router."""
from __future__ import annotations

import pytest

from app.domain.command import CommandBusCommand
from app.domain.growth import GrowthReport, StrategyCandidate
from app.domain.strategy import StrategyV2, StrategyVersion
from app.models.agent_signal import AgentProfile


def _sample_dsl() -> dict:
    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": "<",
                 "value": 30, "params": {"period": 14}},
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": ">",
                 "value": 70, "params": {"period": 14}},
            ],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {"stoploss": -0.05, "max_open_trades": 3, "trailing_stop": False},
    }


def _seed_candidate(session, dsl: dict | None = None, status: str = "draft") -> StrategyCandidate:
    strategy = StrategyV2(name="opt-strategy", strategy_type="dsl", source_type="manual")
    session.add(strategy)
    session.flush()
    version = StrategyVersion(
        strategy_id=strategy.id, version_no=1, status="backtested",
        dsl_version="2.5", rule_dsl=_sample_dsl(), dsl_hash="h", created_by="t",
    )
    session.add(version)
    session.flush()
    report = GrowthReport(
        strategy_run_id=None,
        report_type="run_review",
        period_start=None,
        period_end=None,
        metrics={},
        findings=[],
    )
    session.add(report)
    session.flush()
    candidate = StrategyCandidate(
        source_growth_report_id=report.id,
        source_strategy_version_id=version.id,
        candidate_dsl=dsl if dsl is not None else _sample_dsl(),
        candidate_dsl_hash="candidate-hash",
        status=status,
        rationale="test",
    )
    session.add(candidate)
    session.commit()
    return candidate


class TestOptimizationWorkflow:
    def _advance(self, client, candidate_id) -> dict:
        r = client.post(f"/api/growth/candidates/{candidate_id}/advance")
        assert r.status_code == 200, r.text
        return r.json()

    def test_full_pipeline_to_pending_review(self, client, session):
        candidate = _seed_candidate(session)

        # draft → validated (DSL validation)
        body = self._advance(client, candidate.id)
        assert body["stage"] == "validated" and body["state"] == "healthy"

        # validated → backtesting (enqueues START_BACKTEST)
        body = self._advance(client, candidate.id)
        assert body["stage"] == "backtesting"
        cmd = session.get(CommandBusCommand, __import__("uuid").UUID(body["command_id"]))
        assert cmd.command_type == "start_backtest"

        # backtesting → paper_running (enqueues START_DRYRUN with mode=paper)
        body = self._advance(client, candidate.id)
        assert body["stage"] == "paper_running"
        cmd = session.get(CommandBusCommand, __import__("uuid").UUID(body["command_id"]))
        assert cmd.command_type == "start_dryrun"
        assert cmd.payload["mode"] == "paper"

        # paper_running → pending_review
        body = self._advance(client, candidate.id)
        assert body["stage"] == "pending_review"

        # pending_review → blocked, final approval is manual
        body = self._advance(client, candidate.id)
        assert body["state"] == "blocked"
        assert "use_confirm_endpoint" in body["reason_codes"]

    def test_invalid_dsl_blocks_at_draft(self, client, session):
        dsl = _sample_dsl()
        del dsl["risk"]["stoploss"]
        candidate = _seed_candidate(session, dsl=dsl)
        body = self._advance(client, candidate.id)
        assert body["state"] == "blocked"
        assert body["stage"] == "draft"
        assert "dsl_validation_failed" in body["reason_codes"]
        assert body["errors"]

    def test_missing_candidate_404(self, client, session):
        import uuid
        r = client.post(f"/api/growth/candidates/{uuid.uuid4()}/advance")
        assert r.status_code == 404


class TestAgentsRouter:
    def test_list_agents(self, client, session):
        session.add(AgentProfile(name="research-agent", kind="research", status="active"))
        session.commit()
        r = client.get("/api/agents")
        assert r.status_code == 200
        body = r.json()
        assert body["total"] == 1
        assert body["agents"][0]["name"] == "research-agent"

    def test_run_agent_enqueues_command(self, client, session):
        session.add(AgentProfile(name="trading-agents", kind="research", status="active"))
        session.commit()
        profile = session.query(AgentProfile).first()
        r = client.post(f"/api/agents/{profile.id}/run", json={"symbol": "ETH/USDT"})
        assert r.status_code == 202
        body = r.json()
        assert body["state"] == "running"
        cmd = session.get(CommandBusCommand, __import__("uuid").UUID(body["task_id"]))
        assert cmd.command_type == "run_agent_task"
        assert cmd.payload["symbol"] == "ETH/USDT"
        assert cmd.payload["agent_id"] == profile.id

    def test_tasks_list_shows_queue(self, client, session):
        session.add(AgentProfile(name="trading-agents", kind="research", status="active"))
        session.commit()
        profile = session.query(AgentProfile).first()
        client.post(f"/api/agents/{profile.id}/run", json={})
        r = client.get("/api/agents/tasks")
        body = r.json()
        assert body["state"] == "healthy"
        assert body["total"] == 1
        assert body["tasks"][0]["status"] == "pending"

    def test_cancel_queued_task(self, client, session):
        session.add(AgentProfile(name="trading-agents", kind="research", status="active"))
        session.commit()
        profile = session.query(AgentProfile).first()
        run_body = client.post(f"/api/agents/{profile.id}/run", json={}).json()
        r = client.post(f"/api/agents/tasks/{run_body['task_id']}/cancel")
        assert r.status_code == 200
        cmd = session.get(CommandBusCommand, __import__("uuid").UUID(run_body["task_id"]))
        assert cmd.status == "cancelled"

    def test_cancel_missing_task_404(self, client, session):
        import uuid
        r = client.post(f"/api/agents/tasks/{uuid.uuid4()}/cancel")
        assert r.status_code == 404

    def test_run_missing_agent_404(self, client, session):
        r = client.post("/api/agents/9999/run", json={})
        assert r.status_code == 404
