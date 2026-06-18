"""Tests for strategy workspace router — 7 endpoints (spec §6.1 A-G).

TDD: tests written first, then router implementation.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from app.domain.activity_log import StrategyActivityLog
from app.domain.execution import StrategyRun
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash

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


# ── Fixtures ──────────────────────────────────────────────────────────

@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def strategy(db_session):
    """A minimal strategy with one version for workspace/duplicate/archive/activity tests."""
    from app.domain.strategy import StrategyV2, StrategyVersion

    s = StrategyV2(
        name="test-strat", strategy_type="rule_dsl", source_type="manual", status="draft",
    )
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()

    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="draft",
        dsl_version="2.5", rule_dsl=VALID_DSL,
        dsl_hash=compute_dsl_hash(VALID_DSL), created_by="u",
    )
    repo.create_version(v)
    db_session.commit()
    db_session.refresh(s)
    return s


@pytest.fixture
def binding_fixtures(db_session):
    """Strategy + version + risk policy + capital pools for binding endpoint tests."""
    from app.domain.strategy import StrategyV2, StrategyVersion
    from app.domain.risk import CapitalPool, RiskPolicy, RiskPolicyVersion

    s = StrategyV2(
        name="bt-strat", strategy_type="rule_dsl", source_type="manual", status="paper_passed",
    )
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()

    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="paper_passed",
        dsl_version="2.5", rule_dsl=VALID_DSL,
        dsl_hash=compute_dsl_hash(VALID_DSL), created_by="u",
    )
    repo.create_version(v)
    db_session.flush()

    rp = RiskPolicy(name="conservative", policy_type="conservative", status="active")
    db_session.add(rp)
    db_session.flush()
    rpv = RiskPolicyVersion(
        risk_policy_id=rp.id, version_no=1,
        policy_json={"max_position_pct": 0.02},
        policy_hash="abc", status="active", created_by="u",
    )
    db_session.add(rpv)
    db_session.flush()

    pool_live = CapitalPool(
        name="ls", pool_type="live_small", currency="USDT",
        total_budget=5000, max_position_pct_per_trade=0.02,
        max_total_exposure_pct=0.5, max_daily_loss_pct=0.05, max_drawdown_pct=0.15,
    )
    pool_paper = CapitalPool(
        name="paper", pool_type="paper", currency="USDT",
        total_budget=10000, max_position_pct_per_trade=0.05,
        max_total_exposure_pct=1.0, max_daily_loss_pct=0.10, max_drawdown_pct=0.20,
    )
    db_session.add_all([pool_live, pool_paper])
    db_session.commit()
    db_session.refresh(s)
    return dict(
        strategy=s, version=v, rpv=rpv,
        pool_live=pool_live, pool_paper=pool_paper,
    )


# ═══════════════════════════════════════════════════════════════════════
# A. GET /{strategy_id}/workspace
# ═══════════════════════════════════════════════════════════════════════

def test_get_workspace_returns_snapshot(client: TestClient, strategy):
    resp = client.get(f"/api/v2/strategies/{strategy.id}/workspace")
    assert resp.status_code == 200
    body = resp.json()
    assert body["strategy"]["id"] == str(strategy.id)
    assert body["strategy"]["name"] == "test-strat"
    assert len(body["versions"]) == 1
    assert body["latest_version_id"] is not None
    assert body["bindings"] == []
    assert body["readiness"]["total"] == 11
    assert "signal_logic_summary" in body
    assert "data_dependencies" in body


def test_get_workspace_404_when_missing(client: TestClient):
    resp = client.get("/api/v2/strategies/00000000-0000-0000-0000-000000000000/workspace")
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# B. POST /{strategy_id}/duplicate
# ═══════════════════════════════════════════════════════════════════════

def test_duplicate_creates_new_strategy_201(client: TestClient, strategy):
    resp = client.post(f"/api/v2/strategies/{strategy.id}/duplicate", json={})
    assert resp.status_code == 201
    body = resp.json()
    assert body["id"] != str(strategy.id)
    assert body["status"] == "draft"
    assert "copy" in body["name"]


def test_duplicate_uses_custom_name(client: TestClient, strategy):
    resp = client.post(
        f"/api/v2/strategies/{strategy.id}/duplicate",
        json={"name": "my-copy"},
    )
    assert resp.status_code == 201
    assert resp.json()["name"] == "my-copy"


def test_duplicate_404_when_source_missing(client: TestClient):
    resp = client.post(
        "/api/v2/strategies/00000000-0000-0000-0000-000000000000/duplicate",
        json={},
    )
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# C. GET /{strategy_id}/bindings
# ═══════════════════════════════════════════════════════════════════════

def test_get_bindings_returns_full_summaries(client: TestClient, binding_fixtures, session):
    f = binding_fixtures
    # Create a binding first via the service
    from app.services.strategy_activity_service import StrategyActivityService
    from app.services.strategy_binding_service import StrategyBindingService

    svc = StrategyBindingService(session, StrategyActivityService(session))
    b = svc.create(
        strategy_id=f["strategy"].id,
        strategy_version_id=f["version"].id,
        risk_policy_version_id=f["rpv"].id,
        capital_pool_id=f["pool_live"].id,
        mode="live_small",
        actor="api",
    )
    session.commit()

    resp = client.get(f"/api/v2/strategies/{f['strategy'].id}/bindings")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    entry = data[0]
    assert entry["mode"] == "live_small"
    assert entry["risk_policy"]["name"] == "conservative"
    assert entry["risk_policy"]["version_no"] == 1
    assert entry["risk_policy"]["policy_json_summary"] == {"max_position_pct": 0.02}
    assert entry["capital_pool"]["name"] == "ls"
    assert entry["capital_pool"]["pool_type"] == "live_small"
    assert entry["capital_pool"]["total_budget"] == 5000


def test_get_bindings_empty_when_no_bindings(client: TestClient, strategy):
    resp = client.get(f"/api/v2/strategies/{strategy.id}/bindings")
    assert resp.status_code == 200
    assert resp.json() == []


# ═══════════════════════════════════════════════════════════════════════
# D. POST /{strategy_id}/bindings
# ═══════════════════════════════════════════════════════════════════════

def test_create_binding_201_happy(client: TestClient, binding_fixtures):
    f = binding_fixtures
    resp = client.post(
        f"/api/v2/strategies/{f['strategy'].id}/bindings",
        json={
            "strategy_version_id": str(f["version"].id),
            "risk_policy_version_id": str(f["rpv"].id),
            "capital_pool_id": str(f["pool_live"].id),
            "mode": "live_small",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["mode"] == "live_small"
    assert body["risk_policy"]["name"] == "conservative"
    assert body["capital_pool"]["name"] == "ls"


def test_create_binding_409_duplicate(client: TestClient, binding_fixtures):
    f = binding_fixtures
    # Create first binding
    client.post(
        f"/api/v2/strategies/{f['strategy'].id}/bindings",
        json={
            "strategy_version_id": str(f["version"].id),
            "risk_policy_version_id": str(f["rpv"].id),
            "capital_pool_id": str(f["pool_live"].id),
            "mode": "live_small",
        },
    )
    # Duplicate should 409
    resp = client.post(
        f"/api/v2/strategies/{f['strategy'].id}/bindings",
        json={
            "strategy_version_id": str(f["version"].id),
            "risk_policy_version_id": str(f["rpv"].id),
            "capital_pool_id": str(f["pool_live"].id),
            "mode": "live_small",
        },
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == "BINDING_DUPLICATE"


def test_create_binding_422_pool_mismatch(client: TestClient, binding_fixtures):
    f = binding_fixtures
    resp = client.post(
        f"/api/v2/strategies/{f['strategy'].id}/bindings",
        json={
            "strategy_version_id": str(f["version"].id),
            "risk_policy_version_id": str(f["rpv"].id),
            "capital_pool_id": str(f["pool_paper"].id),
            "mode": "live_small",
        },
    )
    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "BINDING_POOL_MISMATCH"


def test_create_binding_422_policy_archived(
    client: TestClient, binding_fixtures, session,
):
    f = binding_fixtures
    f["rpv"].status = "archived"
    session.commit()

    resp = client.post(
        f"/api/v2/strategies/{f['strategy'].id}/bindings",
        json={
            "strategy_version_id": str(f["version"].id),
            "risk_policy_version_id": str(f["rpv"].id),
            "capital_pool_id": str(f["pool_live"].id),
            "mode": "live_small",
        },
    )
    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "BINDING_POLICY_ARCHIVED"


def test_create_binding_404_when_strategy_missing(client: TestClient):
    resp = client.post(
        "/api/v2/strategies/00000000-0000-0000-0000-000000000000/bindings",
        json={
            "strategy_version_id": "00000000-0000-0000-0000-000000000001",
            "risk_policy_version_id": "00000000-0000-0000-0000-000000000002",
            "capital_pool_id": "00000000-0000-0000-0000-000000000003",
            "mode": "live_small",
        },
    )
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# E. DELETE /{strategy_id}/bindings/{binding_id}
# ═══════════════════════════════════════════════════════════════════════

def test_delete_binding_204(client: TestClient, binding_fixtures, session):
    f = binding_fixtures
    # Create binding
    from app.services.strategy_activity_service import StrategyActivityService
    from app.services.strategy_binding_service import StrategyBindingService

    svc = StrategyBindingService(session, StrategyActivityService(session))
    b = svc.create(
        strategy_id=f["strategy"].id,
        strategy_version_id=f["version"].id,
        risk_policy_version_id=f["rpv"].id,
        capital_pool_id=f["pool_live"].id,
        mode="live_small",
        actor="api",
    )
    session.commit()

    resp = client.delete(
        f"/api/v2/strategies/{f['strategy'].id}/bindings/{b.id}",
    )
    assert resp.status_code == 204

    # Verify deleted
    get_resp = client.get(f"/api/v2/strategies/{f['strategy'].id}/bindings")
    assert get_resp.json() == []


def test_delete_binding_409_in_use(client: TestClient, binding_fixtures, session):
    f = binding_fixtures
    # Create binding
    from app.services.strategy_activity_service import StrategyActivityService
    from app.services.strategy_binding_service import StrategyBindingService

    svc = StrategyBindingService(session, StrategyActivityService(session))
    b = svc.create(
        strategy_id=f["strategy"].id,
        strategy_version_id=f["version"].id,
        risk_policy_version_id=f["rpv"].id,
        capital_pool_id=f["pool_live"].id,
        mode="live_small",
        actor="api",
    )
    session.commit()

    # Create active run
    run = StrategyRun(
        strategy_version_id=f["version"].id,
        capital_pool_id=f["pool_live"].id,
        mode="live_small",
        status="running",
    )
    session.add(run)
    session.commit()

    resp = client.delete(
        f"/api/v2/strategies/{f['strategy'].id}/bindings/{b.id}",
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == "BINDING_IN_USE"


def test_delete_binding_404_when_missing(client: TestClient, strategy):
    resp = client.delete(
        f"/api/v2/strategies/{strategy.id}/bindings/"
        "00000000-0000-0000-0000-000000000000",
    )
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# F. PATCH /{strategy_id}/archive
# ═══════════════════════════════════════════════════════════════════════

def test_archive_changes_status_200(client: TestClient, strategy):
    resp = client.patch(
        f"/api/v2/strategies/{strategy.id}/archive",
        json={"reason": "cleanup"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "archived"


def test_archive_idempotent(client: TestClient, strategy):
    # First archive
    client.patch(
        f"/api/v2/strategies/{strategy.id}/archive",
        json={"reason": "first"},
    )
    # Second archive — still 200
    resp = client.patch(
        f"/api/v2/strategies/{strategy.id}/archive",
        json={"reason": "again"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "archived"


def test_archive_404_when_strategy_missing(client: TestClient):
    resp = client.patch(
        "/api/v2/strategies/00000000-0000-0000-0000-000000000000/archive",
        json={},
    )
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# G. GET /{strategy_id}/activity
# ═══════════════════════════════════════════════════════════════════════

def test_get_activity_returns_recent_entries(client: TestClient, strategy, session):
    # Create 3 activity entries directly
    for i in range(3):
        entry = StrategyActivityLog(
            strategy_id=strategy.id,
            kind="version_created",
            summary=f"entry {i}",
            actor="u",
        )
        session.add(entry)
    session.commit()

    resp = client.get(f"/api/v2/strategies/{strategy.id}/activity")
    assert resp.status_code == 200
    entries = resp.json()
    assert len(entries) == 3
    assert entries[0]["kind"] == "version_created"
    # entries are ordered by occurred_at DESC, so most recent first
    assert "ref" in entries[0]  # ref is null but key exists


def test_get_activity_respects_limit_query(client: TestClient, strategy, session):
    # Create 5 entries
    for i in range(5):
        entry = StrategyActivityLog(
            strategy_id=strategy.id,
            kind="version_created",
            summary=f"entry {i}",
            actor="u",
        )
        session.add(entry)
    session.commit()

    resp = client.get(
        f"/api/v2/strategies/{strategy.id}/activity?limit=2",
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_get_activity_404_when_strategy_missing(client: TestClient):
    resp = client.get(
        "/api/v2/strategies/00000000-0000-0000-0000-000000000000/activity",
    )
    assert resp.status_code == 404
