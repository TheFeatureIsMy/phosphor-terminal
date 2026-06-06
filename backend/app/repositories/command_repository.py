"""Command Bus Repository — lock acquisition, idempotency, status transitions."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, text, and_
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus


class CommandRepository:
    def __init__(self, session: Session):
        self._s = session

    def create(self, command: CommandBusCommand) -> CommandBusCommand:
        self._s.add(command)
        self._s.flush()
        return command

    def get_by_id(self, command_id: uuid.UUID) -> Optional[CommandBusCommand]:
        return self._s.get(CommandBusCommand, command_id)

    def get_by_idempotency_key(self, key: str) -> Optional[CommandBusCommand]:
        stmt = select(CommandBusCommand).where(CommandBusCommand.idempotency_key == key)
        return self._s.scalar(stmt)

    def acquire_next(self, worker_id: str) -> Optional[CommandBusCommand]:
        """Acquire the next pending command using FOR UPDATE SKIP LOCKED."""
        now = datetime.now(timezone.utc)
        stmt = (
            select(CommandBusCommand)
            .where(
                and_(
                    CommandBusCommand.status.in_([
                        CommandStatus.PENDING.value,
                        CommandStatus.RETRY_WAITING.value,
                    ]),
                    CommandBusCommand.next_retry_at.is_(None)
                    | (CommandBusCommand.next_retry_at <= now),
                )
            )
            .order_by(CommandBusCommand.priority, CommandBusCommand.created_at)
            .limit(1)
            .with_for_update(skip_locked=True)
        )
        cmd = self._s.scalar(stmt)
        if cmd is None:
            return None
        cmd.status = CommandStatus.RUNNING.value
        cmd.locked_by = worker_id
        cmd.locked_at = now
        if cmd.started_at is None:
            cmd.started_at = now
        self._s.flush()
        return cmd

    def mark_succeeded(self, command_id: uuid.UUID) -> None:
        cmd = self.get_by_id(command_id)
        if cmd:
            cmd.status = CommandStatus.SUCCEEDED.value
            cmd.completed_at = datetime.now(timezone.utc)
            self._s.flush()

    def mark_failed(self, command_id: uuid.UUID, error_code: str, error_message: str) -> None:
        cmd = self.get_by_id(command_id)
        if cmd is None:
            return
        cmd.error_code = error_code
        cmd.error_message = error_message
        if cmd.retry_count < cmd.max_retries:
            cmd.status = CommandStatus.RETRY_WAITING.value
            cmd.retry_count += 1
            cmd.locked_by = None
            cmd.locked_at = None
        else:
            cmd.status = CommandStatus.FAILED.value
            cmd.completed_at = datetime.now(timezone.utc)
        self._s.flush()

    def cancel(self, command_id: uuid.UUID) -> bool:
        cmd = self.get_by_id(command_id)
        if cmd is None:
            return False
        if cmd.status in (CommandStatus.SUCCEEDED.value, CommandStatus.FAILED.value):
            return False
        cmd.cancel_requested = True
        if cmd.status == CommandStatus.PENDING.value:
            cmd.status = CommandStatus.CANCELLED.value
            cmd.completed_at = datetime.now(timezone.utc)
        self._s.flush()
        return True
