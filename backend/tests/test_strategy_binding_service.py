"""Tests for StrategyBindingService — CRUD, mode/pool consistency, in-use protection."""
from __future__ import annotations

import uuid

import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.risk import RiskPolicy, RiskPolicyVersion, CapitalPool, StrategyRiskPolicyBinding
from app.domain.execution import StrategyRun
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_binding_service import StrategyBindingService
from app.services.strategy_binding_errors import (
    DuplicateBindingError,
    PoolMismatchError,
    PolicyArchivedError,
    BindingInUseError,
)


@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def fixtures(db_session):
    s = StrategyV2(name="bt", strategy_type="rule_dsl", source_type="manual", status="paper_passed")
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()

    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="paper_passed",
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}), created_by="u",
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
    return dict(strategy=s, version=v, rpv=rpv, pool_live=pool_live, pool_paper=pool_paper)


def test_create_live_small_binding_happy(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id,
        strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id,
        capital_pool_id=fixtures["pool_live"].id,
        mode="live_small",
        actor="api",
    )
    db_session.commit()
    assert b.mode == "live_small"


def test_create_duplicate_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    with pytest.raises(DuplicateBindingError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
            mode="live_small", actor="api",
        )


def test_create_live_small_with_paper_pool_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    with pytest.raises(PoolMismatchError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_paper"].id,
            mode="live_small", actor="api",
        )


def test_create_with_archived_policy_raises(db_session, fixtures):
    fixtures["rpv"].status = "archived"
    db_session.commit()
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    with pytest.raises(PolicyArchivedError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
            mode="live_small", actor="api",
        )


def test_delete_binding(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    svc.delete(b.id, actor="api")
    db_session.commit()
    assert svc.list_for_strategy(fixtures["strategy"].id) == []


def test_delete_binding_with_active_run_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.add(StrategyRun(
        strategy_version_id=fixtures["version"].id,
        capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", status="running",
    ))
    db_session.commit()
    with pytest.raises(BindingInUseError):
        svc.delete(b.id, actor="api")


def test_list_for_strategy_returns_all_versions_bindings(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    rows = svc.list_for_strategy(fixtures["strategy"].id)
    assert len(rows) == 1
