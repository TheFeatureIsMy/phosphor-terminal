"""Tests for the 5 new command handlers: deploy_rules, pause, live_small, emergency_stop, reconciliation."""
import json
import uuid
import tempfile
from pathlib import Path

import pytest
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.enums import StrategyVersionStatus, StrategyRunMode
from app.workers.deploy_rules_handler import DeployRulesHandler
from app.workers.pause_handler import PauseStrategyHandler
from app.workers.live_small_handler import RequestLiveSmallHandler
from app.workers.emergency_stop_handler import EmergencyStopHandler
from app.workers.reconciliation_handler import StartReconciliationHandler


def _make_command(session: Session, command_type: str, payload: dict,
                  aggregate_id: uuid.UUID | None = None) -> CommandBusCommand:
    cmd = CommandBusCommand(
        command_type=command_type,
        aggregate_type="strategy_version",
        aggregate_id=aggregate_id,
        payload=payload,
        idempotency_key=str(uuid.uuid4()),
        requested_by="test",
        status="running",
    )
    session.add(cmd)
    session.flush()
    return cmd


def _make_strategy_version(session: Session, status: str = "draft") -> StrategyVersion:
    s = StrategyV2(name="Test", strategy_type="rule_dsl", source_type="manual", status="draft")
    session.add(s)
    session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status=status,
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash="sha256:test", created_by="test",
    )
    session.add(v)
    session.flush()
    return v


def _make_strategy_run(session: Session, version: StrategyVersion,
                       mode: str = "dry_run", status: str = "running") -> StrategyRun:
    run = StrategyRun(
        strategy_version_id=version.id,
        mode=mode,
        status=status,
    )
    session.add(run)
    session.flush()
    return run


class TestDeployRulesHandler:
    def test_writes_rules_and_manifest(self, session: Session):
        with tempfile.TemporaryDirectory() as tmpdir:
            rules_dir = Path(tmpdir)
            handler = DeployRulesHandler(rules_dir=rules_dir)

            dsl = {"schema_version": "2.5", "timeframe": "1h", "entry": {"logic": "AND", "rules": []}}
            cmd = _make_command(session, "deploy_rules", {
                "dsl": dsl,
                "strategy_version_id": str(uuid.uuid4()),
                "dsl_hash": "sha256:abc123",
            })

            result = handler.execute(cmd, session)

            rules_path = rules_dir / "strategy_rules.json"
            assert rules_path.exists()
            written_dsl = json.loads(rules_path.read_text())
            assert written_dsl["schema_version"] == "2.5"

            manifest_path = rules_dir / "strategy_rules_manifest.json"
            assert manifest_path.exists()
            manifest = json.loads(manifest_path.read_text())
            assert manifest["dsl_hash"] == "sha256:abc123"
            assert "content_sha256" in manifest

            assert result["rules_path"] == str(rules_path)

    def test_creates_directory_if_missing(self, session: Session):
        with tempfile.TemporaryDirectory() as tmpdir:
            rules_dir = Path(tmpdir) / "nested" / "dir"
            handler = DeployRulesHandler(rules_dir=rules_dir)

            cmd = _make_command(session, "deploy_rules", {
                "dsl": {"schema_version": "2.5"},
                "strategy_version_id": str(uuid.uuid4()),
            })
            handler.execute(cmd, session)
            assert (rules_dir / "strategy_rules.json").exists()


class TestPauseStrategyHandler:
    def test_pause_running_run(self, session: Session):
        version = _make_strategy_version(session, status="paper_running")
        run = _make_strategy_run(session, version, status="running")
        session.commit()

        cmd = _make_command(session, "pause_strategy", {"reason": "manual"}, aggregate_id=run.id)
        handler = PauseStrategyHandler()
        result = handler.execute(cmd, session)

        assert result["status"] == "stopped"
        assert run.status == "stopped"
        assert run.stopped_at is not None
        assert version.status == "paused"

    def test_pause_already_stopped(self, session: Session):
        version = _make_strategy_version(session, status="paused")
        run = _make_strategy_run(session, version, status="stopped")
        session.commit()

        cmd = _make_command(session, "pause_strategy", {}, aggregate_id=run.id)
        handler = PauseStrategyHandler()
        result = handler.execute(cmd, session)

        assert result["already_stopped"] is True

    def test_pause_run_not_found(self, session: Session):
        fake_id = uuid.uuid4()
        cmd = _make_command(session, "pause_strategy", {}, aggregate_id=fake_id)
        handler = PauseStrategyHandler()
        with pytest.raises(RuntimeError, match="not found"):
            handler.execute(cmd, session)


class TestRequestLiveSmallHandler:
    def test_creates_live_small_run(self, session: Session):
        version = _make_strategy_version(session, status="live_pending")
        session.commit()

        cmd = _make_command(session, "request_live_small", {
            "strategy_version_id": str(version.id),
        })
        handler = RequestLiveSmallHandler()
        result = handler.execute(cmd, session)

        assert result["mode"] == "live_small"
        assert result["status"] == "created"
        assert version.status == "live_small"

        run = session.get(StrategyRun, uuid.UUID(result["strategy_run_id"]))
        assert run is not None
        assert run.mode == "live_small"

    def test_rejects_wrong_status(self, session: Session):
        version = _make_strategy_version(session, status="draft")
        session.commit()

        cmd = _make_command(session, "request_live_small", {
            "strategy_version_id": str(version.id),
        })
        handler = RequestLiveSmallHandler()
        with pytest.raises(RuntimeError, match="live_pending"):
            handler.execute(cmd, session)

    def test_version_not_found(self, session: Session):
        cmd = _make_command(session, "request_live_small", {
            "strategy_version_id": str(uuid.uuid4()),
        })
        handler = RequestLiveSmallHandler()
        with pytest.raises(RuntimeError, match="not found"):
            handler.execute(cmd, session)


class TestEmergencyStopHandler:
    def test_stops_all_active_runs(self, session: Session):
        version = _make_strategy_version(session, status="live_small")
        run1 = _make_strategy_run(session, version, status="running")
        run2 = _make_strategy_run(session, version, status="starting")
        _make_strategy_run(session, version, status="stopped")
        session.commit()

        cmd = _make_command(session, "emergency_stop", {
            "strategy_version_id": str(version.id),
            "reason": "circuit_breaker",
        })
        handler = EmergencyStopHandler()
        result = handler.execute(cmd, session)

        assert result["stopped_count"] == 2
        assert run1.status == "stopped"
        assert run2.status == "stopped"
        assert version.status == "paused"

    def test_stops_all_runs_globally(self, session: Session):
        v1 = _make_strategy_version(session, status="paper_running")
        v2 = _make_strategy_version(session, status="live_small")
        r1 = _make_strategy_run(session, v1, status="running")
        r2 = _make_strategy_run(session, v2, status="running")
        session.commit()

        cmd = _make_command(session, "emergency_stop", {"reason": "global_halt"})
        handler = EmergencyStopHandler()
        result = handler.execute(cmd, session)

        assert result["stopped_count"] == 2
        assert r1.status == "stopped"
        assert r2.status == "stopped"

    def test_no_active_runs(self, session: Session):
        cmd = _make_command(session, "emergency_stop", {"reason": "test"})
        handler = EmergencyStopHandler()
        result = handler.execute(cmd, session)
        assert result["stopped_count"] == 0


class TestStartReconciliationHandler:
    def _make_freqtrade_run(self, session, strategy_run, status="running"):
        ft_run = FreqtradeRun(
            strategy_run_id=strategy_run.id,
            status=status,
            config_path="/tmp/test/config.json",
            rules_path="/tmp/test/strategy_rules.json",
            rule_package_hash="abc123deadbeef",
        )
        session.add(ft_run)
        session.flush()
        return ft_run

    def test_reconciles_running_runs(self, session: Session):
        version = _make_strategy_version(session, status="paper_running")
        run = _make_strategy_run(session, version, status="running")
        ft_run = self._make_freqtrade_run(session, run, status="running")
        session.commit()

        cmd = _make_command(session, "start_reconciliation", {
            "strategy_run_id": str(run.id),
            "freqtrade_run_id": str(ft_run.id),
        })
        handler = StartReconciliationHandler()
        result = handler.execute(cmd, session)

        assert result["status"] == "completed"
        assert "reconciliation_event_id" in result

    def test_skips_stopped_runs(self, session: Session):
        """Reconciliation on a stopped FreqtradeRun still completes (reports drift)."""
        version = _make_strategy_version(session, status="paused")
        run = _make_strategy_run(session, version, status="stopped")
        ft_run = self._make_freqtrade_run(session, run, status="stopped")
        session.commit()

        cmd = _make_command(session, "start_reconciliation", {
            "strategy_run_id": str(run.id),
            "freqtrade_run_id": str(ft_run.id),
        })
        handler = StartReconciliationHandler()
        result = handler.execute(cmd, session)

        assert result["status"] in ("completed", "failed")

    def test_reconcile_without_filter(self, session: Session):
        """Missing required IDs raises ValueError."""
        cmd = _make_command(session, "start_reconciliation", {})
        handler = StartReconciliationHandler()
        import pytest
        with pytest.raises(ValueError, match="requires both"):
            handler.execute(cmd, session)


class TestHandlerRegistry:
    def test_all_command_types_have_handlers(self):
        from app.domain.enums import CommandType
        import app.workers.handlers as h

        h._initialized = False
        h._registry.clear()

        for ct in CommandType:
            handler = h.get_handler(ct.value)
            assert handler is not None, f"No handler registered for {ct.value}"
