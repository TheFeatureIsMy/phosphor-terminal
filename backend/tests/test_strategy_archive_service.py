"""Tests for StrategyArchiveService — admin force-archive of strategy + all non-archived versions."""
from __future__ import annotations

import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_archive_service import StrategyArchiveService


@pytest.fixture
def db_session(session):
    return session


def _make(db_session, status: str, version_status: str) -> StrategyV2:
    s = StrategyV2(name="x", strategy_type="rule_dsl", source_type="manual", status=status)
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status=version_status,
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}),
        created_by="u",
    )
    repo.create_version(v)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_archive_transitions_all_non_archived_versions(db_session):
    """Happy path: a backtested strategy with a backtested version -> both become archived."""
    s = _make(db_session, "backtested", "backtested")
    svc = StrategyArchiveService(db_session, StrategyActivityService(db_session))
    out = svc.archive(s.id, reason="cleanup")
    db_session.commit()

    assert out.status == "archived"
    repo = StrategyRepository(db_session)
    versions = repo.list_versions(s.id)
    assert all(v.status == "archived" for v in versions)


def test_archive_writes_activity_with_reason(db_session):
    """An activity log entry with kind=archived and the reason in the summary is written."""
    s = _make(db_session, "draft", "draft")
    activity = StrategyActivityService(db_session)
    svc = StrategyArchiveService(db_session, activity)
    svc.archive(s.id, reason="done with it")
    db_session.commit()

    rows = activity.list_recent(s.id)
    archived_entry = next(r for r in rows if r.kind == "archived")
    assert "done with it" in archived_entry.summary


def test_archive_idempotent(db_session):
    """Calling archive on an already-archived strategy is a no-op (still archived)."""
    s = _make(db_session, "archived", "archived")
    svc = StrategyArchiveService(db_session, StrategyActivityService(db_session))
    out = svc.archive(s.id)
    assert out.status == "archived"
