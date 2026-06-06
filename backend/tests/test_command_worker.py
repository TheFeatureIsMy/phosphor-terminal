"""CommandWorker tests — acquire, execute, retry, timeout, cancel."""
import uuid
from datetime import datetime, timezone, timedelta
from app.workers.command_worker import _utcnow

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.services.command_bus import CommandBusService
from app.workers.command_worker import CommandWorker
from app.workers.handlers import register_handler, CommandHandler, _registry


class SuccessHandler(CommandHandler):
    def execute(self, command, session):
        return {"result": "ok"}


class FailHandler(CommandHandler):
    def execute(self, command, session):
        raise RuntimeError("handler exploded")


def _enqueue_cmd(session: Session, **overrides) -> CommandBusCommand:
    svc = CommandBusService(session)
    defaults = dict(
        command_type="test_cmd", aggregate_type="test",
        payload={}, idempotency_key=str(uuid.uuid4()),
        requested_by="test",
    )
    defaults.update(overrides)
    cmd, _ = svc.enqueue(**defaults)
    session.commit()
    return cmd


def _ledger_events(session: Session, command_id: uuid.UUID) -> list[ExecutionLedgerEvent]:
    stmt = select(ExecutionLedgerEvent).where(
        ExecutionLedgerEvent.command_id == command_id
    ).order_by(ExecutionLedgerEvent.event_time)
    return list(session.scalars(stmt).all())


class TestAcquireAndSucceed:
    def setup_method(self):
        _registry.clear()
        register_handler("test_cmd", SuccessHandler)

    def test_acquire_and_succeed(self, session: Session):
        cmd = _enqueue_cmd(session)
        worker = CommandWorker(session, worker_id="w1")

        acquired = worker.acquire_next()
        assert acquired is not None
        assert acquired.status == CommandStatus.RUNNING.value
        assert acquired.locked_by == "w1"

        worker.execute_command(acquired)
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.SUCCEEDED.value
        assert refreshed.completed_at is not None

        events = _ledger_events(session, cmd.id)
        types = [e.event_type for e in events]
        assert "PULSEDESK_COMMAND_STARTED" in types
        assert "PULSEDESK_COMMAND_SUCCEEDED" in types

    def test_no_pending_returns_none(self, session: Session):
        worker = CommandWorker(session)
        assert worker.acquire_next() is None


class TestAcquireAndFail:
    def setup_method(self):
        _registry.clear()
        register_handler("test_cmd", FailHandler)

    def test_fail_with_retry(self, session: Session):
        cmd = _enqueue_cmd(session, max_retries=3)
        worker = CommandWorker(session)

        acquired = worker.acquire_next()
        worker.execute_command(acquired)
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.RETRY_WAITING.value
        assert refreshed.retry_count == 1
        assert refreshed.locked_by is None
        assert refreshed.next_retry_at is not None
        assert refreshed.error_code == "HANDLER_ERROR"

    def test_fail_exhausted(self, session: Session):
        cmd = _enqueue_cmd(session, max_retries=0)
        worker = CommandWorker(session)

        acquired = worker.acquire_next()
        worker.execute_command(acquired)
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.FAILED.value
        assert refreshed.completed_at is not None

        events = _ledger_events(session, cmd.id)
        types = [e.event_type for e in events]
        assert "PULSEDESK_COMMAND_FAILED" in types


class TestNoHandler:
    def setup_method(self):
        _registry.clear()

    def test_no_handler_fails(self, session: Session):
        cmd = _enqueue_cmd(session, command_type="unknown_type")
        worker = CommandWorker(session)

        acquired = worker.acquire_next()
        worker.execute_command(acquired)
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.error_code == "NO_HANDLER"


class TestCancelRequested:
    def setup_method(self):
        _registry.clear()
        register_handler("test_cmd", SuccessHandler)

    def test_cancel_before_execute(self, session: Session):
        cmd = _enqueue_cmd(session)
        cmd.cancel_requested = True
        session.commit()

        worker = CommandWorker(session)
        acquired = worker.acquire_next()
        worker.execute_command(acquired)
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.CANCELLED.value


class TestTimeoutRecovery:
    def test_recover_stale(self, session: Session):
        cmd = _enqueue_cmd(session, timeout_sec=60)
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = "dead-worker"
        cmd.locked_at = _utcnow() - timedelta(seconds=120)
        session.commit()

        worker = CommandWorker(session)
        recovered = worker.recover_stale()
        session.commit()

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.TIMEOUT.value
        assert recovered == 1

        events = _ledger_events(session, cmd.id)
        types = [e.event_type for e in events]
        assert "PULSEDESK_COMMAND_FAILED" in types

    def test_skip_healthy_running(self, session: Session):
        cmd = _enqueue_cmd(session, timeout_sec=300)
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = "active"
        cmd.locked_at = _utcnow() - timedelta(seconds=10)
        session.commit()

        worker = CommandWorker(session)
        recovered = worker.recover_stale()
        assert recovered == 0


class TestPollOnce:
    def setup_method(self):
        _registry.clear()
        register_handler("test_cmd", SuccessHandler)

    def test_poll_once_full_cycle(self, session: Session):
        cmd = _enqueue_cmd(session)
        worker = CommandWorker(session)

        processed = worker.poll_once()
        assert processed is True

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.SUCCEEDED.value

    def test_poll_once_empty(self, session: Session):
        worker = CommandWorker(session)
        assert worker.poll_once() is False


class TestRetryWithDelay:
    def setup_method(self):
        _registry.clear()
        register_handler("test_cmd", FailHandler)

    def test_retry_respects_next_retry_at(self, session: Session):
        cmd = _enqueue_cmd(session, max_retries=3)
        worker = CommandWorker(session)

        # First failure
        acquired = worker.acquire_next()
        worker.execute_command(acquired)
        session.commit()
        assert cmd.status == CommandStatus.RETRY_WAITING.value
        assert cmd.next_retry_at is not None
        assert cmd.next_retry_at is not None  # delay set

        # Try acquire again — should be blocked by next_retry_at
        acquired2 = worker.acquire_next()
        assert acquired2 is None
