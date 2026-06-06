"""CommandBusService tests — enqueue idempotency, cancel, stale recovery."""
import uuid
from datetime import datetime, timezone, timedelta
from app.services.command_bus import _utcnow

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.services.command_bus import CommandBusService


def _enqueue(svc: CommandBusService, **overrides):
    defaults = dict(
        command_type="start_backtest", aggregate_type="strategy_run",
        payload={"test": True}, idempotency_key=str(uuid.uuid4()),
        requested_by="test",
    )
    defaults.update(overrides)
    return svc.enqueue(**defaults)


class TestEnqueue:
    def test_new_command(self, session: Session):
        svc = CommandBusService(session)
        cmd, created = _enqueue(svc)
        session.commit()
        assert created is True
        assert cmd.status == CommandStatus.PENDING.value
        assert cmd.id is not None

    def test_idempotent_succeeded(self, session: Session):
        svc = CommandBusService(session)
        key = "idem-succeed"
        cmd1, _ = _enqueue(svc, idempotency_key=key)
        cmd1.status = CommandStatus.SUCCEEDED.value
        session.commit()

        cmd2, created = _enqueue(svc, idempotency_key=key)
        assert created is False
        assert cmd2.id == cmd1.id

    def test_idempotent_running(self, session: Session):
        svc = CommandBusService(session)
        key = "idem-running"
        cmd1, _ = _enqueue(svc, idempotency_key=key)
        cmd1.status = CommandStatus.RUNNING.value
        session.commit()

        cmd2, created = _enqueue(svc, idempotency_key=key)
        assert created is False
        assert cmd2.id == cmd1.id

    def test_idempotent_pending(self, session: Session):
        svc = CommandBusService(session)
        key = "idem-pending"
        cmd1, _ = _enqueue(svc, idempotency_key=key)
        session.commit()

        cmd2, created = _enqueue(svc, idempotency_key=key)
        assert created is False
        assert cmd2.id == cmd1.id

    def test_idempotent_failed_retryable(self, session: Session):
        svc = CommandBusService(session)
        key = "idem-fail-retry"
        cmd1, _ = _enqueue(svc, idempotency_key=key, max_retries=3)
        cmd1.status = CommandStatus.FAILED.value
        cmd1.retry_count = 1
        session.commit()

        cmd2, created = _enqueue(svc, idempotency_key=key)
        assert created is False
        assert cmd2.status == CommandStatus.RETRY_WAITING.value

    def test_idempotent_failed_exhausted(self, session: Session):
        svc = CommandBusService(session)
        key = "idem-fail-exhausted"
        cmd1, _ = _enqueue(svc, idempotency_key=key, max_retries=2)
        cmd1.status = CommandStatus.FAILED.value
        cmd1.retry_count = 2
        session.commit()

        cmd2, created = _enqueue(svc, idempotency_key=key)
        assert created is False
        assert cmd2.status == CommandStatus.FAILED.value


class TestCancel:
    def test_cancel_pending(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc)
        session.commit()

        success, reason = svc.cancel(cmd.id)
        session.commit()
        assert success is True
        assert reason == "ok"
        assert cmd.status == CommandStatus.CANCELLED.value
        assert cmd.completed_at is not None

    def test_cancel_running_sets_flag(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc)
        cmd.status = CommandStatus.RUNNING.value
        session.commit()

        success, reason = svc.cancel(cmd.id)
        session.commit()
        assert success is True
        assert cmd.cancel_requested is True
        assert cmd.status == CommandStatus.RUNNING.value  # still running, worker checks flag

    def test_cancel_retry_waiting(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc)
        cmd.status = CommandStatus.RETRY_WAITING.value
        session.commit()

        success, reason = svc.cancel(cmd.id)
        session.commit()
        assert success is True
        assert cmd.status == CommandStatus.CANCELLED.value

    def test_cancel_succeeded_rejected(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc)
        cmd.status = CommandStatus.SUCCEEDED.value
        session.commit()

        success, reason = svc.cancel(cmd.id)
        assert success is False
        assert reason == "terminal_state"

    def test_cancel_not_found(self, session: Session):
        svc = CommandBusService(session)
        success, reason = svc.cancel(uuid.uuid4())
        assert success is False
        assert reason == "not_found"


class TestGetStatus:
    def test_get_existing(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc)
        session.commit()
        found = svc.get_by_id(cmd.id)
        assert found is not None
        assert found.command_type == "start_backtest"

    def test_get_nonexistent(self, session: Session):
        svc = CommandBusService(session)
        assert svc.get_by_id(uuid.uuid4()) is None


class TestStaleRecovery:
    def test_recover_timed_out_commands(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc, timeout_sec=60)
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = "dead-worker"
        cmd.locked_at = _utcnow() - timedelta(seconds=120)
        session.commit()

        recovered = svc.recover_stale_commands(stale_threshold_sec=30)
        session.commit()
        assert recovered == 1
        assert cmd.status == CommandStatus.TIMEOUT.value
        assert cmd.error_code == "WORKER_TIMEOUT"

    def test_skip_healthy_running(self, session: Session):
        svc = CommandBusService(session)
        cmd, _ = _enqueue(svc, timeout_sec=300)
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = "active-worker"
        cmd.locked_at = _utcnow() - timedelta(seconds=10)
        session.commit()

        recovered = svc.recover_stale_commands(stale_threshold_sec=30)
        assert recovered == 0
        assert cmd.status == CommandStatus.RUNNING.value
