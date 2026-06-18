"""Tests for StrategyActivityService."""
from __future__ import annotations

import pytest

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService, INVALID_KIND


@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def strategy(db_session):
    s = StrategyV2(name="t", strategy_type="rule_dsl", source_type="manual", status="draft")
    StrategyRepository(db_session).create_strategy(s)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_record_writes_row(db_session, strategy):
    svc = StrategyActivityService(db_session)
    entry = svc.record(strategy.id, "version_created", "v1 created", actor="api", delta={"version_no": 1})
    assert entry.id is not None
    assert entry.strategy_id == strategy.id
    assert entry.kind == "version_created"
    assert entry.delta == {"version_no": 1}


def test_invalid_kind_raises(db_session, strategy):
    svc = StrategyActivityService(db_session)
    with pytest.raises(ValueError, match=INVALID_KIND):
        svc.record(strategy.id, "totally_made_up", "nope")


def test_list_recent_orders_desc(db_session, strategy):
    svc = StrategyActivityService(db_session)
    svc.record(strategy.id, "version_created", "older")
    svc.record(strategy.id, "binding_added", "newer")
    db_session.commit()

    rows = svc.list_recent(strategy.id, limit=10)
    assert [r.kind for r in rows] == ["binding_added", "version_created"]


def test_list_recent_filters_by_strategy(db_session, strategy):
    other = StrategyV2(name="o", strategy_type="rule_dsl", source_type="manual", status="draft")
    StrategyRepository(db_session).create_strategy(other)
    db_session.commit()
    db_session.refresh(other)

    svc = StrategyActivityService(db_session)
    svc.record(strategy.id, "version_created", "mine")
    svc.record(other.id, "version_created", "theirs")
    db_session.commit()

    rows = svc.list_recent(strategy.id)
    assert len(rows) == 1
    assert rows[0].summary == "mine"
