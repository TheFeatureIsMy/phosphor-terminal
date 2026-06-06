"""StartDryRunHandler / StopDryRunHandler — Command Bus handlers for dry-run lifecycle."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.models.dryrun import DryRunRun
from app.repositories.ledger_repository import LedgerRepository
from app.services.dryrun_manager import DryRunProcessManager
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class StartDryRunHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        dsl = payload["dsl"]
        symbols = payload.get("symbols", ["BTC/USDT"])
        stake_amount = payload.get("stake_amount", 100)
        max_open_trades = payload.get("max_open_trades", 5)
        initial_wallet = payload.get("initial_wallet", 10000)
        exchange = payload.get("exchange", "binance")
        api_port = payload.get("api_port", 8080)

        run_id = str(command.id).replace("-", "")[:16]

        run = DryRunRun(
            strategy_id=payload.get("strategy_id", 0),
            strategy_version_id=payload.get("strategy_version_id"),
            command_id=str(command.id),
            dsl_hash=payload.get("dsl_hash", ""),
            status="starting",
            symbols=symbols,
            stake_amount=stake_amount,
            max_open_trades=max_open_trades,
            initial_wallet=initial_wallet,
            exchange=exchange,
            api_port=api_port,
        )
        session.add(run)
        session.flush()

        ledger = LedgerRepository(session)

        manager = DryRunProcessManager()
        try:
            result = manager.start(
                dsl=dsl,
                symbols=symbols,
                stake_amount=stake_amount,
                max_open_trades=max_open_trades,
                initial_wallet=initial_wallet,
                exchange=exchange,
                api_port=api_port,
                run_id=run_id,
            )
        except Exception as exc:
            run.status = "failed"
            run.error_message = str(exc)[:2000]
            session.flush()
            self._write_ledger(
                ledger, command, "FREQTRADE_RUN_STOPPED",
                {"dryrun_run_id": run.id, "error": run.error_message},
            )
            raise RuntimeError(f"dry-run start failed: {exc}") from exc

        now = _utcnow()
        run.status = "running"
        run.pid = result.pid
        run.api_port = result.api_port
        run.api_url = result.api_url
        run.config_path = result.config_path
        run.rules_path = result.rules_path
        run.started_at = now
        session.flush()

        self._write_ledger(
            ledger, command, "FREQTRADE_RUN_STARTED",
            {
                "dryrun_run_id": run.id,
                "pid": result.pid,
                "api_port": result.api_port,
                "symbols": symbols,
            },
        )

        return {
            "dryrun_run_id": run.id,
            "pid": result.pid,
            "api_url": result.api_url,
            "status": "running",
        }

    def _write_ledger(
        self,
        ledger: LedgerRepository,
        command: CommandBusCommand,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        now = _utcnow()
        full_payload = {
            "command_id": str(command.id),
            "command_type": command.command_type,
            **payload,
        }
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", str(command.id), event_type, full_payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="freqtrade",
            source_event_id=str(command.id),
            event_hash=event_hash,
            command_id=command.id,
            strategy_run_id=command.aggregate_id,
            correlation_id=command.correlation_id,
            causation_id=command.id,
            normalized_payload=full_payload,
        )
        ledger.append(evt)


class StopDryRunHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        dryrun_run_id = payload["dryrun_run_id"]

        run = session.query(DryRunRun).filter(DryRunRun.id == dryrun_run_id).first()
        if run is None:
            raise RuntimeError(f"DryRunRun {dryrun_run_id} not found")

        if run.status in ("stopped", "failed"):
            return {"dryrun_run_id": run.id, "status": run.status, "already_stopped": True}

        ledger = LedgerRepository(session)
        manager = DryRunProcessManager()

        stopped = False
        if run.pid and manager.is_running(run.pid):
            stopped = manager.stop(
                pid=run.pid,
                config_path=run.config_path,
                api_url=run.api_url,
            )
        else:
            stopped = True

        now = _utcnow()
        run.status = "stopped"
        run.stopped_at = now
        session.flush()

        self._write_ledger(
            ledger, command, "FREQTRADE_RUN_STOPPED",
            {
                "dryrun_run_id": run.id,
                "pid": run.pid,
                "reason": payload.get("reason", "user_requested"),
            },
        )

        return {
            "dryrun_run_id": run.id,
            "status": "stopped",
            "process_killed": stopped,
        }

    def _write_ledger(
        self,
        ledger: LedgerRepository,
        command: CommandBusCommand,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        now = _utcnow()
        full_payload = {
            "command_id": str(command.id),
            "command_type": command.command_type,
            **payload,
        }
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", str(command.id), event_type, full_payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="freqtrade",
            source_event_id=str(command.id),
            event_hash=event_hash,
            command_id=command.id,
            correlation_id=command.correlation_id,
            causation_id=command.id,
            normalized_payload=full_payload,
        )
        ledger.append(evt)
