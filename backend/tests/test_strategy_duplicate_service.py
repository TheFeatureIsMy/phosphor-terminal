"""Tests for StrategyDuplicateService."""
from __future__ import annotations

import copy
import uuid

import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_duplicate_service import StrategyDuplicateService


@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def source(db_session):
    s = StrategyV2(name="origin", strategy_type="rule_dsl", source_type="manual", status="backtested")
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="backtested",
        dsl_version="2.5",
        rule_dsl={"schema_version": "2.5", "entry": {"logic": "AND", "rules": []}},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}),
        created_by="user",
    )
    repo.create_version(v)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_duplicate_creates_new_strategy_in_draft(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    assert new.id != source.id
    assert new.status == "draft"
    assert new.name == "origin copy"


def test_duplicate_clones_latest_version_as_v1_draft(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    db_session.commit()
    repo = StrategyRepository(db_session)
    versions = repo.list_versions(new.id)
    assert len(versions) == 1
    assert versions[0].version_no == 1
    assert versions[0].status == "draft"
    src_versions = repo.list_versions(source.id)
    assert len(src_versions) == 1
    assert versions[0].rule_dsl == src_versions[0].rule_dsl


def test_duplicate_uses_custom_name(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id, name="custom name")
    assert new.name == "custom name"


def test_duplicate_dsl_is_deep_copy(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    db_session.commit()
    repo = StrategyRepository(db_session)
    new_version = repo.list_versions(new.id)[0]
    new_version.rule_dsl["entry"]["logic"] = "OR"
    db_session.commit()

    src_version = repo.list_versions(source.id)[0]
    assert src_version.rule_dsl["entry"]["logic"] == "AND"


def test_duplicate_writes_activity_log(db_session, source):
    activity = StrategyActivityService(db_session)
    svc = StrategyDuplicateService(db_session, activity)
    new = svc.duplicate(source.id)
    db_session.commit()
    rows = activity.list_recent(new.id)
    assert len(rows) == 1
    assert rows[0].kind == "version_created"
    assert "origin" in rows[0].summary


def test_duplicate_missing_source_raises(db_session):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    with pytest.raises(ValueError, match="not found"):
        svc.duplicate(uuid.uuid4())


def test_duplicate_source_with_no_version_raises(db_session):
    s = StrategyV2(name="empty", strategy_type="rule_dsl", source_type="manual", status="draft")
    StrategyRepository(db_session).create_strategy(s)
    db_session.commit()
    db_session.refresh(s)

    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    with pytest.raises(ValueError, match="no version"):
        svc.duplicate(s.id)
