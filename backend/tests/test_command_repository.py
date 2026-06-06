"""Command Bus Repository tests."""
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.repositories.command_repository import CommandRepository


def _make_command(**overrides) -> CommandBusCommand:
    defaults = dict(
        command_type="start_backtest", aggregate_type="strategy_run",
        payload={"test": True}, idempotency_key=str(uuid.uuid4()),
        requested_by="test_user",
    )
    defaults.update(overrides)
    return CommandBusCommand(**defaults)


class TestCommandRepository:
    def test_create_command(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command())
        session.commit()
        assert cmd.id is not None
        assert cmd.status == CommandStatus.PENDING.value

    def test_idempotency_key_unique(self, session: Session):
        repo = CommandRepository(session)
        key = "test-idempotency-key"
        repo.create(_make_command(idempotency_key=key))
        session.commit()

        existing = repo.get_by_idempotency_key(key)
        assert existing is not None
        assert existing.idempotency_key == key

    def test_mark_succeeded(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command())
        session.commit()

        repo.mark_succeeded(cmd.id)
        session.commit()

        updated = repo.get_by_id(cmd.id)
        assert updated.status == CommandStatus.SUCCEEDED.value
        assert updated.completed_at is not None

    def test_mark_failed_retries(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command(max_retries=3))
        cmd.status = CommandStatus.RUNNING.value
        session.commit()

        repo.mark_failed(cmd.id, "TEST_ERROR", "something broke")
        session.commit()

        updated = repo.get_by_id(cmd.id)
        assert updated.status == CommandStatus.RETRY_WAITING.value
        assert updated.retry_count == 1
        assert updated.error_code == "TEST_ERROR"
        assert updated.locked_by is None

    def test_mark_failed_exhausted(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command(max_retries=1))
        cmd.status = CommandStatus.RUNNING.value
        cmd.retry_count = 1
        session.commit()

        repo.mark_failed(cmd.id, "FINAL_ERROR", "no more retries")
        session.commit()

        updated = repo.get_by_id(cmd.id)
        assert updated.status == CommandStatus.FAILED.value
        assert updated.completed_at is not None

    def test_cancel_pending(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command())
        session.commit()

        result = repo.cancel(cmd.id)
        session.commit()
        assert result is True

        updated = repo.get_by_id(cmd.id)
        assert updated.status == CommandStatus.CANCELLED.value

    def test_cancel_succeeded_fails(self, session: Session):
        repo = CommandRepository(session)
        cmd = repo.create(_make_command())
        cmd.status = CommandStatus.SUCCEEDED.value
        session.commit()

        result = repo.cancel(cmd.id)
        assert result is False

    def test_cancel_nonexistent(self, session: Session):
        repo = CommandRepository(session)
        assert repo.cancel(uuid.uuid4()) is False
