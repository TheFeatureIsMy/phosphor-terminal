"""Command Bus Service — enqueue, idempotency, status query, stale recovery."""
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus


def _utcnow() -> datetime:
    """Naive UTC datetime for cross-db compatibility (SQLite stores naive)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


TERMINAL_STATUSES = {CommandStatus.SUCCEEDED.value, CommandStatus.FAILED.value,
                     CommandStatus.CANCELLED.value, CommandStatus.TIMEOUT.value}


class CommandBusService:
    def __init__(self, session: Session):
        self._s = session

    def enqueue(
        self, *, command_type: str, aggregate_type: str,
        payload: dict, idempotency_key: str, requested_by: str,
        aggregate_id: uuid.UUID | None = None,
        priority: int = 100, max_retries: int = 3, timeout_sec: int = 300,
        correlation_id: uuid.UUID | None = None,
        causation_id: uuid.UUID | None = None,
    ) -> tuple[CommandBusCommand, bool]:
        existing = self._get_by_key(idempotency_key)
        if existing:
            if existing.status in (CommandStatus.SUCCEEDED.value, CommandStatus.RUNNING.value,
                                   CommandStatus.PENDING.value, CommandStatus.RETRY_WAITING.value):
                return existing, False
            if existing.status == CommandStatus.FAILED.value:
                if existing.retry_count < existing.max_retries:
                    existing.status = CommandStatus.RETRY_WAITING.value
                    existing.locked_by = None
                    existing.locked_at = None
                    self._s.flush()
                return existing, False
            return existing, False

        cmd = CommandBusCommand(
            command_type=command_type, aggregate_type=aggregate_type,
            aggregate_id=aggregate_id, payload=payload,
            idempotency_key=idempotency_key, requested_by=requested_by,
            priority=priority, max_retries=max_retries, timeout_sec=timeout_sec,
            correlation_id=correlation_id, causation_id=causation_id,
        )
        self._s.add(cmd)
        self._s.flush()
        return cmd, True

    def get_by_id(self, command_id: uuid.UUID) -> Optional[CommandBusCommand]:
        return self._s.get(CommandBusCommand, command_id)

    def cancel(self, command_id: uuid.UUID) -> tuple[bool, str]:
        cmd = self.get_by_id(command_id)
        if cmd is None:
            return False, "not_found"
        if cmd.status in TERMINAL_STATUSES:
            return False, "terminal_state"
        cmd.cancel_requested = True
        if cmd.status in (CommandStatus.PENDING.value, CommandStatus.RETRY_WAITING.value):
            cmd.status = CommandStatus.CANCELLED.value
            cmd.completed_at = _utcnow()
        self._s.flush()
        return True, "ok"

    def recover_stale_commands(self, stale_threshold_sec: int = 600) -> int:
        now = _utcnow()
        cutoff = now - timedelta(seconds=stale_threshold_sec)
        stmt = (
            select(CommandBusCommand)
            .where(and_(
                CommandBusCommand.status == CommandStatus.RUNNING.value,
                CommandBusCommand.locked_at.isnot(None),
                CommandBusCommand.locked_at < cutoff,
            ))
        )
        stale = list(self._s.scalars(stmt).all())
        for cmd in stale:
            timeout = cmd.timeout_sec or 300
            deadline = cmd.locked_at + timedelta(seconds=timeout)
            if now > deadline:
                cmd.status = CommandStatus.TIMEOUT.value
                cmd.completed_at = now
                cmd.error_code = "WORKER_TIMEOUT"
                cmd.error_message = f"Worker {cmd.locked_by} exceeded {timeout}s timeout"
        self._s.flush()
        return len([c for c in stale if c.status == CommandStatus.TIMEOUT.value])

    def _get_by_key(self, key: str) -> Optional[CommandBusCommand]:
        stmt = select(CommandBusCommand).where(CommandBusCommand.idempotency_key == key)
        return self._s.scalar(stmt)
