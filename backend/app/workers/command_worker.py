"""Command Bus Worker — polls pending commands, dispatches to handlers, writes Ledger."""
import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository
from app.workers.handlers import get_handler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class CommandWorker:
    def __init__(self, session: Session, worker_id: str | None = None):
        self._s = session
        self._worker_id = worker_id or f"worker-{uuid.uuid4().hex[:8]}"
        self._ledger = LedgerRepository(session)

    @property
    def worker_id(self) -> str:
        return self._worker_id

    def acquire_next(self) -> Optional[CommandBusCommand]:
        now = _utcnow()
        stmt = (
            select(CommandBusCommand)
            .where(and_(
                CommandBusCommand.status.in_([
                    CommandStatus.PENDING.value,
                    CommandStatus.RETRY_WAITING.value,
                ]),
                (CommandBusCommand.next_retry_at.is_(None))
                | (CommandBusCommand.next_retry_at <= now),
            ))
            .order_by(CommandBusCommand.priority, CommandBusCommand.created_at)
            .limit(1)
            .with_for_update(skip_locked=True)
        )
        cmd = self._s.scalar(stmt)
        if cmd is None:
            return None
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = self._worker_id
        cmd.locked_at = now
        if cmd.started_at is None:
            cmd.started_at = now
        self._s.flush()
        return cmd

    def execute_command(self, cmd: CommandBusCommand) -> None:
        if cmd.cancel_requested:
            self._mark_cancelled(cmd)
            return

        self._write_ledger_event(cmd, "PULSEDESK_COMMAND_STARTED")

        handler = get_handler(cmd.command_type)
        if handler is None:
            self._mark_failed(cmd, "NO_HANDLER", f"No handler for {cmd.command_type}")
            return

        try:
            result = handler.execute(cmd, self._s)
            self._mark_succeeded(cmd, result)
        except Exception as exc:
            self._mark_failed(cmd, "HANDLER_ERROR", str(exc))

    def poll_once(self) -> bool:
        cmd = self.acquire_next()
        if cmd is None:
            return False
        self.execute_command(cmd)
        self._s.commit()
        return True

    def recover_stale(self, stale_threshold_sec: int = 600) -> int:
        now = _utcnow()
        stmt = (
            select(CommandBusCommand)
            .where(and_(
                CommandBusCommand.status == CommandStatus.RUNNING.value,
                CommandBusCommand.locked_at.isnot(None),
            ))
        )
        candidates = list(self._s.scalars(stmt).all())
        recovered = 0
        for cmd in candidates:
            timeout = cmd.timeout_sec or 300
            locked = cmd.locked_at
            if locked and (now - locked).total_seconds() > timeout:
                cmd.status = CommandStatus.TIMEOUT.value
                cmd.completed_at = now
                cmd.error_code = "WORKER_TIMEOUT"
                cmd.error_message = f"Worker {cmd.locked_by} exceeded {timeout}s timeout"
                self._write_ledger_event(cmd, "PULSEDESK_COMMAND_FAILED",
                                         extra={"error_code": "WORKER_TIMEOUT"})
                recovered += 1
        if recovered:
            self._s.flush()
        return recovered

    def _mark_succeeded(self, cmd: CommandBusCommand, result: dict | None = None) -> None:
        cmd.status = CommandStatus.SUCCEEDED.value
        cmd.completed_at = _utcnow()
        self._s.flush()
        self._write_ledger_event(cmd, "PULSEDESK_COMMAND_SUCCEEDED", extra=result)

    def _mark_failed(self, cmd: CommandBusCommand, error_code: str, error_message: str) -> None:
        cmd.error_code = error_code
        cmd.error_message = error_message
        if cmd.retry_count < cmd.max_retries:
            cmd.status = CommandStatus.RETRY_WAITING.value
            cmd.retry_count += 1
            cmd.locked_by = None
            cmd.locked_at = None
            delay = min(30 * (2 ** (cmd.retry_count - 1)), 300)
            cmd.next_retry_at = _utcnow() + timedelta(seconds=delay)
        else:
            cmd.status = CommandStatus.FAILED.value
            cmd.completed_at = _utcnow()
        self._s.flush()
        self._write_ledger_event(cmd, "PULSEDESK_COMMAND_FAILED",
                                 extra={"error_code": error_code, "error_message": error_message})

    def _mark_cancelled(self, cmd: CommandBusCommand) -> None:
        cmd.status = CommandStatus.CANCELLED.value
        cmd.completed_at = _utcnow()
        cmd.locked_by = None
        cmd.locked_at = None
        self._s.flush()
        self._write_ledger_event(cmd, "PULSEDESK_COMMAND_FAILED",
                                 extra={"error_code": "CANCELLED"})

    def _write_ledger_event(self, cmd: CommandBusCommand, event_type: str,
                            extra: dict | None = None) -> None:
        now = _utcnow()
        payload = {
            "command_id": str(cmd.id),
            "command_type": cmd.command_type,
            "aggregate_type": cmd.aggregate_type,
            "aggregate_id": str(cmd.aggregate_id) if cmd.aggregate_id else None,
            **(extra or {}),
        }
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", str(cmd.id), event_type, payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now,
            event_type=event_type, source_system="pulsedesk",
            source_event_id=str(cmd.id), event_hash=event_hash,
            command_id=cmd.id, strategy_run_id=cmd.aggregate_id,
            correlation_id=cmd.correlation_id, causation_id=cmd.id,
            normalized_payload=payload,
        )
        self._ledger.append(evt)
