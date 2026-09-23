"""Tests for CommandWorkerLoop background task."""
import asyncio
import uuid

import pytest
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.services.command_bus import CommandBusService
from app.workers.command_worker import CommandWorker
from app.workers.handlers import register_handler, CommandHandler, _registry
from app.workers.worker_loop import CommandWorkerLoop


class SuccessHandler(CommandHandler):
    def execute(self, command, session):
        return {"result": "ok"}


@pytest.fixture(autouse=True)
def _register_handler():
    _registry.clear()
    register_handler("test_cmd", SuccessHandler)
    yield
    _registry.clear()


class TestCommandWorkerLoop:
    def test_tick_processes_pending_command(self, session: Session):
        """A single tick should process one pending command."""
        svc = CommandBusService(session)
        cmd, _ = svc.enqueue(
            command_type="test_cmd",
            aggregate_type="test",
            payload={"x": 1},
            idempotency_key=str(uuid.uuid4()),
            requested_by="test",
        )
        session.commit()
        assert cmd.status == CommandStatus.PENDING.value

        # Directly test _tick via sync wrapper
        worker = CommandWorker(session)
        processed = worker.poll_once()
        assert processed is True

        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.SUCCEEDED.value

    def test_tick_does_nothing_when_empty(self, session: Session):
        worker = CommandWorker(session)
        processed = worker.poll_once()
        assert processed is False

    @pytest.mark.asyncio
    async def test_loop_starts_and_stops(self):
        """Loop should start and stop gracefully."""
        loop = CommandWorkerLoop(poll_interval_s=0.1, stale_recovery_interval_s=1.0, enabled=True)
        await loop.start()
        assert loop._task is not None
        assert not loop._task.done()

        await asyncio.sleep(0.25)

        await loop.stop()
        assert loop._task is None

    @pytest.mark.asyncio
    async def test_loop_disabled(self):
        """Loop should not start when disabled."""
        loop = CommandWorkerLoop(enabled=False)
        await loop.start()
        assert loop._task is None

    @pytest.mark.asyncio
    async def test_stop_is_idempotent(self):
        """Calling stop when not started should be safe."""
        loop = CommandWorkerLoop(enabled=True)
        await loop.stop()  # Should not raise
