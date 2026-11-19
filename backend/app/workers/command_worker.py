"""Command Bus Worker — polls pending commands, dispatches to handlers, writes Ledger."""
import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository
from app.workers.handlers import get_handler

logger = logging.getLogger(__name__)

_RECONCILIATION_BYPASS_TYPES = frozenset({"emergency_stop"})
# Commands that are safe to re-run after a worker crash / timeout. Anything
# that can move money (live start, dry-run launch, agent task) stays terminal.
_TIMEOUT_RETRY_SAFE_TYPES = frozenset({
    "deploy_rules",
    "start_backtest",
    "stop_dryrun",
    "pause_strategy",
    "resume_strategy",
    "emergency_stop",
    "start_reconciliation",
})
_MAX_ACQUIRE_SCAN = 20


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _naive_utc(value: datetime | None) -> datetime | None:
    """Normalize DB timestamps (PostgreSQL returns aware datetimes) to naive UTC."""
    if value is None:
        return None
    if value.tzinfo is not None:
        # Preserve the stored wall-clock; app datetimes are naive UTC.
        return value.replace(tzinfo=None)
    return value


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
        running_per_tenant = (
            select(
                CommandBusCommand.tenant_id.label("tenant_id"),
                func.count().label("running"),
            )
            .where(CommandBusCommand.status == CommandStatus.RUNNING.value)
            .group_by(CommandBusCommand.tenant_id)
            .subquery()
        )
        for _ in range(_MAX_ACQUIRE_SCAN):
            stmt = (
                select(CommandBusCommand)
                .outerjoin(
                    running_per_tenant,
                    func.coalesce(CommandBusCommand.tenant_id, -1)
                    == func.coalesce(running_per_tenant.c.tenant_id, -1),
                )
                .where(and_(
                    CommandBusCommand.status.in_([
                        CommandStatus.PENDING.value,
                        CommandStatus.RETRY_WAITING.value,
                    ]),
                    (CommandBusCommand.next_retry_at.is_(None))
                    | (CommandBusCommand.next_retry_at <= now),
                ))
                .order_by(
                    func.coalesce(running_per_tenant.c.running, 0),
                    CommandBusCommand.priority,
                    CommandBusCommand.created_at,
                )
                .limit(1)
                .with_for_update(skip_locked=True, of=CommandBusCommand)
            )
            cmd = self._s.scalar(stmt)
            if cmd is None:
                return None

            if self._is_blocked_by_reconciliation(cmd):
                # Defer this command and keep looking: returning None here
                # would starve every lower-priority command for the whole tick.
                cmd.next_retry_at = now + timedelta(seconds=settings.command_blocked_retry_s)
                logger.info(
                    "Command %s deferred %ss: reconciliation in progress",
                    cmd.id, settings.command_blocked_retry_s,
                )
                self._s.flush()
                continue

            cmd.status = CommandStatus.RUNNING.value
            cmd.locked_by = self._worker_id
            cmd.locked_at = now
            if cmd.started_at is None:
                cmd.started_at = now
            self._s.flush()
            return cmd
        return None

    def _is_blocked_by_reconciliation(self, cmd: CommandBusCommand) -> bool:
        """Block commands targeting a FreqtradeRun in reconciliating state.
        emergency_stop always bypasses."""
        if cmd.command_type in _RECONCILIATION_BYPASS_TYPES:
            return False
        if cmd.aggregate_id is None:
            return False

        from app.domain.execution import FreqtradeRun
        # Check if any FreqtradeRun linked to this aggregate is reconciliating
        ft_run = self._s.scalars(
            select(FreqtradeRun).where(and_(
                FreqtradeRun.strategy_run_id == cmd.aggregate_id,
                FreqtradeRun.status == "reconciliating",
            )).limit(1)
        ).first()
        if ft_run:
            logger.info(
                "Command %s blocked: FreqtradeRun %s is reconciliating",
                cmd.id, ft_run.id,
            )
            return True

        # Also check payload for explicit freqtrade_run_id
        ft_run_id = (cmd.payload or {}).get("freqtrade_run_id")
        if ft_run_id:
            try:
                ft_run = self._s.get(FreqtradeRun, uuid.UUID(str(ft_run_id)))
                if ft_run and ft_run.status == "reconciliating":
                    logger.info(
                        "Command %s blocked: payload FreqtradeRun %s is reconciliating",
                        cmd.id, ft_run_id,
                    )
                    return True
            except (ValueError, TypeError):
                pass

        return False

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
            # A failed flush leaves the session unusable. Reload the row
            # before recording the failure, or the command stays pending forever.
            cmd_id = cmd.id
            self._s.rollback()
            cmd = self._s.get(CommandBusCommand, cmd_id)
            if cmd is not None:
                self._mark_failed(cmd, "HANDLER_ERROR", str(exc)[:2000])

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
            locked = _naive_utc(cmd.locked_at)
            if not locked or (now - locked).total_seconds() <= timeout:
                continue

            can_retry = (
                settings.command_timeout_retry_enabled
                and cmd.command_type in _TIMEOUT_RETRY_SAFE_TYPES
                and cmd.retry_count < cmd.max_retries
            )
            cmd.error_code = "WORKER_TIMEOUT"
            cmd.error_message = f"Worker {cmd.locked_by} exceeded {timeout}s timeout"
            if can_retry:
                cmd.retry_count += 1
                cmd.status = CommandStatus.RETRY_WAITING.value
                cmd.locked_by = None
                cmd.locked_at = None
                cmd.next_retry_at = now + timedelta(seconds=self._retry_delay(cmd.retry_count))
            else:
                cmd.status = CommandStatus.TIMEOUT.value
                cmd.completed_at = now
                cmd.locked_by = None
                cmd.locked_at = None
            self._write_ledger_event(
                cmd, "PULSEDESK_COMMAND_FAILED",
                extra={
                    "error_code": "WORKER_TIMEOUT",
                    "retry_scheduled": can_retry,
                    "retry_count": cmd.retry_count,
                },
            )
            recovered += 1
        if recovered:
            self._s.flush()
        return recovered

    def _mark_succeeded(self, cmd: CommandBusCommand, result: dict | None = None) -> None:
        cmd.status = CommandStatus.SUCCEEDED.value
        cmd.completed_at = _utcnow()
        self._s.flush()
        self._write_ledger_event(cmd, "PULSEDESK_COMMAND_SUCCEEDED", extra=result)

    @staticmethod
    def _retry_delay(retry_count: int) -> int:
        """Exponential backoff: 30s, 60s, 120s, ... capped at 5 minutes."""
        return min(30 * (2 ** max(retry_count - 1, 0)), 300)

    def _mark_failed(self, cmd: CommandBusCommand, error_code: str, error_message: str) -> None:
        cmd.error_code = error_code
        cmd.error_message = error_message
        if cmd.retry_count < cmd.max_retries:
            cmd.status = CommandStatus.RETRY_WAITING.value
            cmd.retry_count += 1
            cmd.locked_by = None
            cmd.locked_at = None
            cmd.next_retry_at = _utcnow() + timedelta(seconds=self._retry_delay(cmd.retry_count))
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
