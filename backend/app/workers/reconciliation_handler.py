"""StartReconciliationHandler — compare DB run state with actual process state."""
from __future__ import annotations

import asyncio
import logging
import uuid as uuid_mod
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.services.reconciliation_service import ReconciliationService
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _to_uuid(val: Any) -> uuid_mod.UUID:
    return val if isinstance(val, uuid_mod.UUID) else uuid_mod.UUID(str(val))


def _fetch_freqtrade_positions() -> list[dict]:
    """Attempt to get open positions from Freqtrade via REST API."""
    try:
        from app.services.freqtrade_client import FreqtradeClient

        client = FreqtradeClient()
        result = asyncio.run(client.get_status())
        if isinstance(result, list):
            return result
        if isinstance(result, dict) and not result.get("error"):
            return result.get("result", []) if "result" in result else []
    except Exception as exc:
        logger.warning("Could not fetch Freqtrade positions: %s", exc)
    return []


class StartReconciliationHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload

        raw_strategy_run_id = payload.get("strategy_run_id")
        raw_freqtrade_run_id = payload.get("freqtrade_run_id")

        if not raw_strategy_run_id or not raw_freqtrade_run_id:
            raise ValueError(
                "reconciliation requires both strategy_run_id and freqtrade_run_id in payload"
            )

        strategy_run_id = _to_uuid(raw_strategy_run_id)
        freqtrade_run_id = _to_uuid(raw_freqtrade_run_id)

        service = ReconciliationService(session)

        # Step 1: Start reconciliation (creates event + ledger entry)
        event = service.start_reconciliation(strategy_run_id, freqtrade_run_id)
        event_id = event.id

        try:
            # Step 2: Fetch Freqtrade positions (best-effort)
            freqtrade_positions = _fetch_freqtrade_positions()

            # Step 3: Execute reconciliation (compare positions, compute drift)
            drift_summary = service.execute(event_id, freqtrade_positions)

            # Step 4: Mark complete
            service.complete(event_id, success=True)

            return {
                "reconciliation_event_id": str(event_id),
                "strategy_run_id": str(strategy_run_id),
                "freqtrade_run_id": str(freqtrade_run_id),
                "drift_summary": drift_summary,
                "status": "completed",
            }
        except Exception as exc:
            logger.error("Reconciliation failed for event %s: %s", event_id, exc)
            try:
                service.complete(event_id, success=False)
            except Exception as complete_exc:
                logger.error("Failed to mark reconciliation as failed: %s", complete_exc)
            return {
                "reconciliation_event_id": str(event_id),
                "strategy_run_id": str(strategy_run_id),
                "freqtrade_run_id": str(freqtrade_run_id),
                "status": "failed",
                "error": str(exc),
            }
