"""DryRunSyncService — sync Freqtrade dry-run trades into Execution Ledger."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository
from app.services.freqtrade_client import FreqtradeClient

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class SyncResult:
    def __init__(self) -> None:
        self.new_events: int = 0
        self.open_trades: int = 0
        self.closed_trades: int = 0
        self.errors: list[str] = []

    @property
    def success(self) -> bool:
        return len(self.errors) == 0


class DryRunSyncService:
    def __init__(self, session: Session, api_url: str | None = None):
        self._session = session
        self._ledger = LedgerRepository(session)
        self._client = FreqtradeClient(base_url=api_url)

    async def sync_trades(
        self,
        dryrun_run_id: int,
        correlation_id: uuid.UUID | None = None,
    ) -> SyncResult:
        result = SyncResult()

        status_data = await self._client.get_status()
        if not FreqtradeClient.is_success(status_data):
            result.errors.append(f"failed to get status: {status_data.get('error')}")
            return result

        if isinstance(status_data, list):
            open_trades = status_data
        else:
            open_trades = status_data.get("result", []) if isinstance(status_data, dict) else []

        result.open_trades = len(open_trades)

        for trade in open_trades:
            trade_id = trade.get("trade_id") or trade.get("id")
            if trade_id is None:
                continue
            source_event_id = f"dryrun-{dryrun_run_id}-trade-{trade_id}"
            is_open = trade.get("is_open", True)

            if is_open:
                event_type = "FREQTRADE_TRADE_OPENED"
            else:
                event_type = "FREQTRADE_TRADE_CLOSED"
                result.closed_trades += 1

            created = self._write_trade_event(
                event_type=event_type,
                source_event_id=source_event_id,
                trade_data=trade,
                dryrun_run_id=dryrun_run_id,
                correlation_id=correlation_id,
            )
            if created:
                result.new_events += 1

        trades_data = await self._client.get_trades()
        if FreqtradeClient.is_success(trades_data):
            closed_trades = trades_data.get("trades", [])
            if isinstance(closed_trades, list):
                for trade in closed_trades:
                    trade_id = trade.get("trade_id") or trade.get("id")
                    if trade_id is None:
                        continue
                    if not trade.get("is_open", True):
                        source_event_id = f"dryrun-{dryrun_run_id}-closed-{trade_id}"
                        created = self._write_trade_event(
                            event_type="FREQTRADE_TRADE_CLOSED",
                            source_event_id=source_event_id,
                            trade_data=trade,
                            dryrun_run_id=dryrun_run_id,
                            correlation_id=correlation_id,
                        )
                        if created:
                            result.new_events += 1
                            result.closed_trades += 1

        return result

    def _write_trade_event(
        self,
        event_type: str,
        source_event_id: str,
        trade_data: dict[str, Any],
        dryrun_run_id: int,
        correlation_id: uuid.UUID | None = None,
    ) -> bool:
        now = _utcnow()
        payload = {
            "dryrun_run_id": dryrun_run_id,
            "trade_id": trade_data.get("trade_id") or trade_data.get("id"),
            "pair": trade_data.get("pair"),
            "is_open": trade_data.get("is_open"),
            "open_rate": trade_data.get("open_rate"),
            "close_rate": trade_data.get("close_rate"),
            "profit_ratio": trade_data.get("profit_ratio"),
            "profit_abs": trade_data.get("profit_abs"),
            "stake_amount": trade_data.get("stake_amount"),
            "amount": trade_data.get("amount"),
            "open_date": trade_data.get("open_date"),
            "close_date": trade_data.get("close_date"),
            "stoploss_current_dist_ratio": trade_data.get("stoploss_current_dist_ratio"),
        }
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", source_event_id, event_type, payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="freqtrade",
            source_event_id=source_event_id,
            event_hash=event_hash,
            symbol=trade_data.get("pair"),
            correlation_id=correlation_id,
            normalized_payload=payload,
        )
        _, created = self._ledger.append(evt)
        return created
