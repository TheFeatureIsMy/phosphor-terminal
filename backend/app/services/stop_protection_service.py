"""Stop Protection Service — 止损保护"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.services.freqtrade_client import FreqtradeClient
from app.services.freqtrade_db import FreqtradeDB
from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)


@dataclass
class StopLevels:
    raw_structure_stop: float | None = None
    last_known_good_stop: float | None = None
    secure_runtime_stop: float | None = None
    exchange_protective_stop: float | None = None
    volatility_locked: bool = False


@dataclass
class PositionStopState:
    position_id: str
    symbol: str
    side: str
    entry_price: float
    current_price: float
    stops: StopLevels = field(default_factory=StopLevels)
    stop_update_allowed: bool = True
    reason_codes: list[str] = field(default_factory=list)


@dataclass
class StopProtectionResult:
    state: str = "healthy"
    reason_codes: list[str] = field(default_factory=list)
    positions: list[PositionStopState] = field(default_factory=list)
    volatility_locks: list[dict] = field(default_factory=list)


class StopProtectionService:
    def __init__(
        self,
        redis_store: RuntimeRedisStore | None = None,
        freqtrade_client: FreqtradeClient | None = None,
        freqtrade_db: FreqtradeDB | None = None,
    ):
        self._store = redis_store
        self._ft_client = freqtrade_client or FreqtradeClient()
        self._ft_db = freqtrade_db or FreqtradeDB()

    async def get_all(self) -> StopProtectionResult:
        """Get stop protection state for all active positions from real data sources.

        Queries open trades from FreqtradeDB and current prices from FreqtradeClient.
        Structure-based stop levels (raw_structure_stop, last_known_good_stop) are
        left as None pending a full OHLCV-based calculation via StructureEngine.
        """
        try:
            db_trades = self._ft_db.get_open_trades()

            if not db_trades:
                # No open trades or DB unavailable — healthy empty result
                return StopProtectionResult(
                    state="healthy", reason_codes=[], positions=[], volatility_locks=[],
                )

            # Fetch current prices from Freqtrade performance endpoint
            perf_prices: dict[str, float] = {}
            try:
                perf = await self._ft_client.get_performance()
                if FreqtradeClient.is_success(perf):
                    entries = perf if isinstance(perf, list) else perf.get("result", [])
                    for p in entries:
                        if isinstance(p, dict):
                            pair = p.get("pair", "")
                            rate = p.get("current_rate") or p.get("profit_factor")
                            if rate is not None:
                                perf_prices[pair] = float(rate)
            except Exception as e:
                logger.debug("Could not fetch current prices from Freqtrade: %s", e)

            positions: list[PositionStopState] = []
            overall_state = "healthy"
            overall_reasons: list[str] = []

            for trade in db_trades:
                symbol = str(trade.get("symbol", ""))
                position_id = str(trade.get("id", ""))
                entry_price = float(trade.get("avg_price", 0) or 0)
                side = str(trade.get("side", "long"))
                current_price = perf_prices.get(symbol, entry_price)

                stop_loss_price = trade.get("stop_loss_price")
                if stop_loss_price is not None:
                    try:
                        stop_loss_price = float(stop_loss_price)
                    except (TypeError, ValueError):
                        stop_loss_price = None

                stops = StopLevels()
                reason_codes: list[str] = []

                if stop_loss_price is not None:
                    stops.exchange_protective_stop = stop_loss_price
                    stops.secure_runtime_stop = stop_loss_price
                    reason_codes.append("exchange_stop_available")
                else:
                    reason_codes.append("stop_calculation_pending")

                pos = PositionStopState(
                    position_id=position_id,
                    symbol=symbol,
                    side=side,
                    entry_price=entry_price,
                    current_price=current_price,
                    stops=stops,
                    stop_update_allowed=True,
                    reason_codes=reason_codes,
                )
                positions.append(pos)

                if self._store:
                    await self._store.write_stop_protection(pos.position_id, {
                        "symbol": pos.symbol, "side": pos.side,
                        "entry_price": pos.entry_price, "current_price": pos.current_price,
                        "raw_structure_stop": pos.stops.raw_structure_stop,
                        "last_known_good_stop": pos.stops.last_known_good_stop,
                        "secure_runtime_stop": pos.stops.secure_runtime_stop,
                        "exchange_protective_stop": pos.stops.exchange_protective_stop,
                        "volatility_locked": pos.stops.volatility_locked,
                        "stop_update_allowed": pos.stop_update_allowed,
                        "reason_codes": pos.reason_codes,
                    }, ttl=5)

            return StopProtectionResult(
                state=overall_state, reason_codes=overall_reasons,
                positions=positions, volatility_locks=[],
            )

        except Exception as e:
            logger.exception("StopProtectionService.get_all failed: %s", e)
            return StopProtectionResult(
                state="data_source_unavailable",
                reason_codes=["data_source_unavailable", type(e).__name__],
                positions=[],
                volatility_locks=[],
            )

    async def refresh_position(self, position_id: str) -> PositionStopState | None:
        """Refresh stop levels for a single position."""
        result = await self.get_all()
        for pos in result.positions:
            if pos.position_id == position_id:
                return pos
        return None
