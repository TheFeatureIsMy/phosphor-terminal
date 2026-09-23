"""OrderMaterializerService — materializes Ledger events into execution_orders/trades/positions."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.ledger import ExecutionLedgerEvent
from app.domain.order import ExecutionOrder, ExecutionTrade, ExecutionPosition

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _dec(val) -> Decimal | None:
    if val is None:
        return None
    return Decimal(str(val))


class OrderMaterializerService:
    """Processes unprocessed Ledger events and upserts materialized order/trade/position rows."""

    def __init__(self, db: Session):
        self._db = db

    def materialize_for_run(self, strategy_run_id: uuid.UUID) -> int:
        """Materialize all trade events for a given strategy run. Returns count of changes."""
        events = list(self._db.scalars(
            select(ExecutionLedgerEvent)
            .where(and_(
                ExecutionLedgerEvent.strategy_run_id == strategy_run_id,
                ExecutionLedgerEvent.event_type.in_([
                    "FREQTRADE_TRADE_OPENED",
                    "FREQTRADE_TRADE_CLOSED",
                    "FREQTRADE_ORDER_OPENED",
                    "FREQTRADE_ORDER_FILLED",
                    "FREQTRADE_ORDER_CANCELLED",
                ]),
            ))
            .order_by(ExecutionLedgerEvent.event_time.asc())
        ).all())

        changes = 0
        for evt in events:
            if evt.event_type in ("FREQTRADE_TRADE_OPENED", "FREQTRADE_TRADE_CLOSED"):
                changes += self._materialize_trade(evt)
            elif evt.event_type in ("FREQTRADE_ORDER_OPENED", "FREQTRADE_ORDER_FILLED", "FREQTRADE_ORDER_CANCELLED"):
                changes += self._materialize_order(evt)

        if changes:
            self._db.flush()  # ensure trade status updates are visible
            self._update_positions(strategy_run_id)
            self._db.flush()

        return changes

    def _materialize_trade(self, evt: ExecutionLedgerEvent) -> int:
        payload = evt.normalized_payload or {}
        trade_id = str(payload.get("trade_id", ""))
        if not trade_id:
            return 0

        source_trade_id = f"ft-{trade_id}"

        existing = self._db.scalars(
            select(ExecutionTrade).where(
                ExecutionTrade.source_trade_id == source_trade_id
            ).limit(1)
        ).first()

        now = _utcnow()
        is_open = payload.get("is_open", True)

        if existing:
            # Update
            existing.latest_ledger_event_id = evt.id
            existing.status = "open" if is_open else "closed"
            existing.close_rate = _dec(payload.get("close_rate"))
            existing.profit_abs = _dec(payload.get("profit_abs"))
            existing.profit_pct = _dec(payload.get("profit_ratio"))
            if not is_open and not existing.closed_at:
                existing.closed_at = now
            existing.last_synced_at = now
            existing.raw_payload = payload
            return 1
        else:
            # Insert
            trade = ExecutionTrade(
                latest_ledger_event_id=evt.id,
                strategy_run_id=evt.strategy_run_id,
                freqtrade_run_id=evt.freqtrade_run_id,
                source_system="freqtrade",
                source_trade_id=source_trade_id,
                exchange="binance",
                symbol=payload.get("pair", "UNKNOWN"),
                side="long",
                open_rate=_dec(payload.get("open_rate")),
                close_rate=_dec(payload.get("close_rate")),
                amount=_dec(payload.get("amount") or payload.get("stake_amount")),
                profit_abs=_dec(payload.get("profit_abs")),
                profit_pct=_dec(payload.get("profit_ratio")),
                status="open" if is_open else "closed",
                opened_at=now,
                closed_at=None if is_open else now,
                last_synced_at=now,
                raw_payload=payload,
            )
            self._db.add(trade)
            self._db.flush()
            return 1

    def _materialize_order(self, evt: ExecutionLedgerEvent) -> int:
        payload = evt.normalized_payload or {}
        order_id = str(payload.get("order_id", payload.get("ft_order_id", "")))
        if not order_id:
            return 0

        source_order_id = f"ft-{order_id}"

        existing = self._db.scalars(
            select(ExecutionOrder).where(
                ExecutionOrder.source_order_id == source_order_id
            ).limit(1)
        ).first()

        now = _utcnow()

        if evt.event_type == "FREQTRADE_ORDER_CANCELLED":
            status = "cancelled"
        elif evt.event_type == "FREQTRADE_ORDER_FILLED":
            status = "filled"
        else:
            status = "open"

        if existing:
            existing.latest_ledger_event_id = evt.id
            existing.status = status
            existing.filled_amount = _dec(payload.get("filled_amount") or payload.get("amount"))
            if status in ("filled", "cancelled"):
                existing.closed_at = now
            existing.last_synced_at = now
            existing.raw_payload = payload
            return 1
        else:
            order = ExecutionOrder(
                latest_ledger_event_id=evt.id,
                strategy_run_id=evt.strategy_run_id,
                freqtrade_run_id=evt.freqtrade_run_id,
                source_system="freqtrade",
                source_order_id=source_order_id,
                freqtrade_trade_id=str(payload.get("trade_id", "")),
                exchange="binance",
                symbol=payload.get("pair", payload.get("symbol", "UNKNOWN")),
                side=payload.get("side", "buy"),
                order_type=payload.get("order_type", "market"),
                price=_dec(payload.get("price")),
                amount=_dec(payload.get("amount")),
                filled_amount=_dec(payload.get("filled_amount")),
                status=status,
                opened_at=now,
                closed_at=now if status in ("filled", "cancelled") else None,
                last_synced_at=now,
                raw_payload=payload,
            )
            self._db.add(order)
            self._db.flush()
            return 1

    def _update_positions(self, strategy_run_id: uuid.UUID) -> None:
        """Rebuild positions from open trades."""
        open_trades = list(self._db.scalars(
            select(ExecutionTrade).where(and_(
                ExecutionTrade.strategy_run_id == strategy_run_id,
                ExecutionTrade.status == "open",
            ))
        ).all())

        # Group by symbol
        by_symbol: dict[str, list[ExecutionTrade]] = {}
        for t in open_trades:
            by_symbol.setdefault(t.symbol, []).append(t)

        now = _utcnow()
        for symbol, trades in by_symbol.items():
            existing_pos = self._db.scalars(
                select(ExecutionPosition).where(and_(
                    ExecutionPosition.strategy_run_id == strategy_run_id,
                    ExecutionPosition.symbol == symbol,
                    ExecutionPosition.status == "open",
                )).limit(1)
            ).first()

            total_amount = sum(float(t.amount or 0) for t in trades)
            avg_entry = sum(float(t.open_rate or 0) * float(t.amount or 0) for t in trades)
            avg_entry = avg_entry / total_amount if total_amount > 0 else 0
            total_pnl = sum(float(t.profit_abs or 0) for t in trades)

            if existing_pos:
                existing_pos.amount = _dec(total_amount)
                existing_pos.entry_price = _dec(avg_entry)
                existing_pos.unrealized_pnl = _dec(total_pnl)
                existing_pos.latest_ledger_event_id = trades[-1].latest_ledger_event_id
                existing_pos.updated_at = now
            else:
                pos = ExecutionPosition(
                    latest_ledger_event_id=trades[-1].latest_ledger_event_id,
                    strategy_run_id=strategy_run_id,
                    exchange="binance",
                    symbol=symbol,
                    position_side="long",
                    amount=_dec(total_amount),
                    entry_price=_dec(avg_entry),
                    unrealized_pnl=_dec(total_pnl),
                    status="open",
                    opened_at=trades[0].opened_at,
                    updated_at=now,
                )
                self._db.add(pos)

        # Close positions for symbols with no open trades
        all_open_positions = list(self._db.scalars(
            select(ExecutionPosition).where(and_(
                ExecutionPosition.strategy_run_id == strategy_run_id,
                ExecutionPosition.status == "open",
            ))
        ).all())
        for pos in all_open_positions:
            if pos.symbol not in by_symbol:
                pos.status = "closed"
                pos.updated_at = now
