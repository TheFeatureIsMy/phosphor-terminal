from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class ExchangeStopResult:
    success: bool
    order_id: Optional[str]
    stop_price: float
    side: str
    error: Optional[str] = None


class ExchangeStopService:
    def __init__(self, freqtrade_client=None, dry_run: bool = True):
        self._client = freqtrade_client
        self._dry_run = dry_run
        self._active_stops: dict[str, str] = {}

    async def place_protective_stop(self, symbol: str, side: str,
                                     amount: float, stop_price: float) -> ExchangeStopResult:
        if self._dry_run:
            order_id = f"dry_stop_{symbol}_{stop_price}"
            self._active_stops[symbol] = order_id
            logger.info("DRY RUN: protective stop %s %s @ %.2f qty=%.4f",
                        side, symbol, stop_price, amount)
            return ExchangeStopResult(
                success=True, order_id=order_id,
                stop_price=stop_price, side=side,
            )

        if not self._client:
            return ExchangeStopResult(
                success=False, order_id=None,
                stop_price=stop_price, side=side,
                error="no_freqtrade_client",
            )

        try:
            resp = await self._client._post("/api/v1/forcesell", {
                "tradeid": symbol,
                "ordertype": "stoploss",
            })
            order_id = str(resp.get("result", "unknown"))
            self._active_stops[symbol] = order_id
            return ExchangeStopResult(
                success=True, order_id=order_id,
                stop_price=stop_price, side=side,
            )
        except Exception as e:
            logger.warning("failed to place protective stop for %s: %s", symbol, e)
            return ExchangeStopResult(
                success=False, order_id=None,
                stop_price=stop_price, side=side,
                error=str(e),
            )

    async def cancel_protective_stop(self, symbol: str, order_id: str) -> bool:
        if self._dry_run:
            self._active_stops.pop(symbol, None)
            logger.info("DRY RUN: cancelled protective stop %s", order_id)
            return True
        return False

    async def update_protective_stop(self, symbol: str, old_order_id: str,
                                      new_stop_price: float, amount: float,
                                      side: str) -> ExchangeStopResult:
        await self.cancel_protective_stop(symbol, old_order_id)
        return await self.place_protective_stop(symbol, side, amount, new_stop_price)
