"""Tests for UUID query parameter filters on runs/backtest/dryrun/risk_overview.

Task 9: extend 4 existing routers with optional UUID query parameters so the
macOS workbench can filter by strategy_id (UUID) and strategy_version_id (UUID).

All new params are optional. Existing callers (no UUID query) must continue to
work exactly as before — no behavior change.
"""
import uuid

from fastapi.testclient import TestClient

from app.domain.execution import StrategyRun
from app.domain.strategy import StrategyV2, StrategyVersion
from app.models.strategy import BacktestRun
from app.models.dryrun import DryRunRun


def _create_strategy(db) -> tuple[uuid.UUID, uuid.UUID]:
    """Create a StrategyV2 + StrategyVersion and return (strategy_id, version_id)."""
    strategy = StrategyV2(
        name="Test Strategy",
        strategy_type="rule_dsl",
        source_type="manual",
    )
    db.add(strategy)
    db.flush()

    version = StrategyVersion(
        strategy_id=strategy.id,
        version_no=1,
        status="validated",
        dsl_version="2.5",
        rule_dsl={"test": True},
        dsl_hash="abc123",
        created_by="test",
    )
    db.add(version)
    db.flush()
    db.commit()
    return strategy.id, version.id


class TestStrategyRunsFilter:
    """Tests for GET /api/v2/strategy-runs UUID filters."""

    def test_strategy_runs_filter_by_version_id(self, client: TestClient, session):
        """strategy_version_id UUID param filters StrategyRun.strategy_version_id."""
        _sid, vid = _create_strategy(session)
        other_vid = uuid.uuid4()

        run1 = StrategyRun(strategy_version_id=vid, mode="paper", status="running")
        run2 = StrategyRun(strategy_version_id=other_vid, mode="paper", status="running")
        session.add_all([run1, run2])
        session.commit()

        resp = client.get(f"/api/v2/strategy-runs?strategy_version_id={vid}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == str(run1.id)

    def test_strategy_runs_filter_by_strategy_id_via_join(
        self, client: TestClient, session,
    ):
        """strategy_id UUID param joins through StrategyVersion to filter."""
        sid, vid = _create_strategy(session)
        _other_sid, other_vid = _create_strategy(session)

        run1 = StrategyRun(strategy_version_id=vid, mode="paper", status="running")
        run2 = StrategyRun(strategy_version_id=other_vid, mode="paper", status="running")
        session.add_all([run1, run2])
        session.commit()

        resp = client.get(f"/api/v2/strategy-runs?strategy_id={sid}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == str(run1.id)

    def test_strategy_runs_no_filter_unchanged(self, client: TestClient, session):
        """Without UUID params, all runs are returned (backward compat)."""
        _sid, vid = _create_strategy(session)

        run1 = StrategyRun(strategy_version_id=vid, mode="paper", status="running")
        run2 = StrategyRun(strategy_version_id=uuid.uuid4(), mode="paper", status="stopped")
        session.add_all([run1, run2])
        session.commit()

        resp = client.get("/api/v2/strategy-runs")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2


class TestBacktestListFilter:
    """Tests for GET /api/v2/backtest UUID filters."""

    def test_backtest_list_filter_by_strategy_uuid(self, client: TestClient, session):
        """strategy_uuid UUID param filters BacktestRun.strategy_uuid."""
        strategy_uuid = uuid.uuid4()
        other_uuid = uuid.uuid4()

        run1 = BacktestRun(
            strategy_id=1, strategy_uuid=strategy_uuid,
            status="completed", start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        run2 = BacktestRun(
            strategy_id=2, strategy_uuid=other_uuid,
            status="completed", start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        session.add_all([run1, run2])
        session.commit()

        resp = client.get(f"/api/v2/backtest?strategy_uuid={strategy_uuid}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == run1.id

    def test_backtest_list_filter_by_strategy_version_uuid(
        self, client: TestClient, session,
    ):
        """strategy_version_uuid UUID param filters BacktestRun.strategy_version_uuid."""
        version_uuid = uuid.uuid4()
        other_uuid = uuid.uuid4()

        run1 = BacktestRun(
            strategy_id=1, strategy_version_uuid=version_uuid,
            status="completed", start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        run2 = BacktestRun(
            strategy_id=2, strategy_version_uuid=other_uuid,
            status="completed", start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        session.add_all([run1, run2])
        session.commit()

        resp = client.get(f"/api/v2/backtest?strategy_version_uuid={version_uuid}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == run1.id

    def test_backtest_legacy_int_strategy_id_still_works(
        self, client: TestClient, session,
    ):
        """Legacy int strategy_id param still works (backward compat)."""
        run1 = BacktestRun(
            strategy_id=1, status="completed",
            start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        run2 = BacktestRun(
            strategy_id=2, status="completed",
            start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        session.add_all([run1, run2])
        session.commit()

        resp = client.get("/api/v2/backtest?strategy_id=1")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["strategy_id"] == 1

    def test_backtest_no_filter_unchanged(self, client: TestClient, session):
        """Without UUID params, all backtest runs are returned."""
        run1 = BacktestRun(
            strategy_id=1, status="completed",
            start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        run2 = BacktestRun(
            strategy_id=2, status="completed",
            start_date="20240101", end_date="20240131",
            initial_capital=10000,
        )
        session.add_all([run1, run2])
        session.commit()

        resp = client.get("/api/v2/backtest")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2


class TestDryrunListFilter:
    """Tests for GET /api/v2/dryrun UUID filters."""

    def test_dryrun_list_filter_by_strategy_version_id(
        self, client: TestClient, session,
    ):
        """strategy_version_id UUID param filters DryRunRun.strategy_version_id."""
        version_id = str(uuid.uuid4())
        other_id = str(uuid.uuid4())

        run1 = DryRunRun(strategy_id=1, strategy_version_id=version_id, status="running")
        run2 = DryRunRun(strategy_id=2, strategy_version_id=other_id, status="stopped")
        session.add_all([run1, run2])
        session.commit()

        resp = client.get(f"/api/v2/dryrun?strategy_version_id={version_id}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == run1.id

    def test_dryrun_no_filter_unchanged(self, client: TestClient, session):
        """Without UUID params, all dryruns are returned."""
        run1 = DryRunRun(strategy_id=1, status="running")
        run2 = DryRunRun(strategy_id=2, status="stopped")
        session.add_all([run1, run2])
        session.commit()

        resp = client.get("/api/v2/dryrun")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2


class TestRiskOverviewStrategyFilter:
    """Tests for GET /api/risk/overview?strategy_id=<uuid>."""

    def test_risk_overview_no_strategy_id_returns_account_level(
        self, client: TestClient,
    ):
        """Without strategy_id, falls through to existing RiskAggregator path."""
        resp = client.get("/api/risk/overview")
        # In test env, RiskAggregator may be unavailable — that's OK, just
        # verify it returns something (200 with fallback or actual response).
        assert resp.status_code == 200
        data = resp.json()
        assert "state" in data
        assert "reason_codes" in data

    def test_risk_overview_strategy_id_returns_per_strategy_state(
        self, client: TestClient, session,
    ):
        """With strategy_id, calls LiveReadinessService.compute_for_strategy."""
        sid, _vid = _create_strategy(session)

        resp = client.get(f"/api/risk/overview?strategy_id={sid}")
        assert resp.status_code == 200
        data = resp.json()
        # Response should have guards derived from the strategy gates
        assert "guards" in data
        assert "state" in data
        assert "account_state" in data
        # Should have at least risk_config and capital guards
        guard_keys = {g["key"] for g in data["guards"]}
        assert "risk_config" in guard_keys
        assert "capital" in guard_keys

    def test_risk_overview_bad_strategy_id_graceful(self, client: TestClient):
        """With non-existent strategy_id, returns degraded response, not 500."""
        bad_id = uuid.uuid4()
        resp = client.get(f"/api/risk/overview?strategy_id={bad_id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "guards" in data
        assert "state" in data
