"""Two workers must not claim the same command (PostgreSQL SKIP LOCKED)."""
import os

import pytest
from sqlalchemy.orm import sessionmaker

from app.workers.command_worker import CommandWorker
from tests.test_command_worker import _enqueue_cmd


pytestmark = pytest.mark.skipif(
    not os.environ.get("TEST_DATABASE_URL", "").startswith("postgresql"),
    reason="SKIP LOCKED semantics require PostgreSQL",
)


def test_two_workers_claim_distinct_commands(session):
    _enqueue_cmd(session)
    _enqueue_cmd(session)
    session.commit()

    engine = session.get_bind()
    Session = sessionmaker(bind=engine)
    s1, s2 = Session(), Session()
    try:
        w1, w2 = CommandWorker(s1, worker_id="w1"), CommandWorker(s2, worker_id="w2")
        first = w1.acquire_next()
        second = w2.acquire_next()
        assert first is not None and second is not None
        assert first.id != second.id
    finally:
        s1.rollback()
        s2.rollback()
        s1.close()
        s2.close()
