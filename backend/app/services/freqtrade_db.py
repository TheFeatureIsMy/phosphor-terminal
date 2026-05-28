import os
from datetime import datetime, timedelta, timezone
from sqlalchemy import create_engine, text
from app.config import settings
from typing import List,  Optional
class FreqtradeDB:
    """Read Freqtrade's SQLite database directly."""
    def __init__(self, db_path: Optional[str] = None):
        path = db_path or settings.freqtrade_db_path
        if not os.path.isabs(path):
            path = os.path.join(os.path.dirname(__file__), "..", "..", path)
        self.db_path = os.path.normpath(path)
        self._engine = None
    @property
    def engine(self):
        if self._engine is None:
            if os.path.exists(self.db_path):
                self._engine = create_engine(f"sqlite:///{self.db_path}")
            else:
                return None
        return self._engine

    def is_available(self) -> bool:
        if self.engine is None:
            return False
        try:
            with self.engine.connect() as conn:
                row = conn.execute(
                    text("SELECT name FROM sqlite_master WHERE type='table' AND name='trades'")
                ).fetchone()
                return row is not None
        except Exception:
            return False

    def source_status(self, simulated: bool = False, detail: Optional[str] = None) -> dict:
        if simulated:
            return {
                "source": "simulated",
                "simulated": True,
                "available": False,
                "detail": detail or "Freqtrade trade database is unavailable; deterministic simulated data is shown.",
            }
        if self.is_available():
            return {
                "source": "freqtrade_db",
                "simulated": False,
                "available": True,
                "detail": None,
            }
        return {
            "source": "unavailable",
            "simulated": False,
            "available": False,
            "detail": detail or "Freqtrade trade database is unavailable or has no trades table.",
        }

    def _query(self, sql: str, params: Optional[dict] = None) -> List[dict]:
        if not self.is_available():
            return []
        with self.engine.connect() as conn:
            result = conn.execute(text(sql), params or {})
            columns = result.keys()
            return [dict(zip(columns, row)) for row in result.fetchall()]
    def get_trades(self, limit: int = 50) -> List[dict]:
        sql = """
            SELECT id, pair as symbol, is_open,
                   CASE WHEN is_open = 0 THEN profit ELSE 0 END as profit,
                   CASE WHEN is_open = 0 THEN profit_ratio ELSE 0 END as pnl_pct,
                   open_rate as price, close_rate as filled_price,
                   fee_open as fee, open_date as timestamp,
                   CASE WHEN is_open = 1 THEN 'open'
                        WHEN profit > 0 THEN 'filled'
                        ELSE 'filled' END as status,
                   CASE WHEN is_open = 0 THEN 'SELL' ELSE 'BUY' END as side,
                   amount as quantity, 'market' as order_type,
                   0 as slippage, 1 as strategy_id
            FROM trades ORDER BY open_date DESC LIMIT :limit
        """
        return self._query(sql, {"limit": limit})
    def get_open_trades(self) -> List[dict]:
        sql = """
            SELECT id, pair as symbol, open_rate as avg_price,
                   amount as quantity, profit_ratio as unrealized_pnl,
                   stop_loss as stop_loss_price,
                   'long' as side, 'open' as status,
                   open_date as opened_at, 1 as strategy_id, 1 as user_id
            FROM trades WHERE is_open = 1
        """
        return self._query(sql)
    def get_kpis(self) -> dict:
        total = self._query("SELECT COUNT(*) as cnt FROM trades WHERE is_open = 0")
        wins = self._query("SELECT COUNT(*) as cnt FROM trades WHERE is_open = 0 AND profit > 0")
        total_pnl = self._query("SELECT COALESCE(SUM(profit), 0) as val FROM trades WHERE is_open = 0")
        active = self._query("SELECT COUNT(*) as cnt FROM trades WHERE is_open = 1")
        today = self._query(
            "SELECT COUNT(*) as cnt FROM trades WHERE open_date >= :today",
            {"today": datetime.now(timezone.utc).strftime("%Y-%m-%d")},
        )
        total_count = total[0]["cnt"] if total else 0
        win_count = wins[0]["cnt"] if wins else 0
        return {
            "total_pnl": round(total_pnl[0]["val"] if total_pnl else 0, 2),
            "pnl_change_pct": 0.0,
            "sharpe_ratio": 0.0,
            "max_drawdown": 0.0,
            "win_rate": round((win_count / total_count * 100) if total_count > 0 else 0, 1),
            "active_strategies": active[0]["cnt"] if active else 0,
            "todays_trades": today[0]["cnt"] if today else 0,
            "open_positions": active[0]["cnt"] if active else 0,
        }
    def get_equity_curve(self, days: int = 90) -> List[dict]:
        start = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        sql = """
            SELECT DATE(close_date) as date,
                   SUM(profit) as daily_pnl
            FROM trades
            WHERE is_open = 0 AND close_date >= :start
            GROUP BY DATE(close_date)
            ORDER BY date
        """
        rows = self._query(sql, {"start": start})
        cumulative = 10000.0
        peak = 10000.0
        result = []
        for row in rows:
            cumulative += row["daily_pnl"] or 0
            peak = max(peak, cumulative)
            drawdown = ((cumulative - peak) / peak * 100) if peak > 0 else 0
            result.append({
                "date": row["date"],
                "value": round(cumulative, 2),
                "drawdown": round(drawdown, 2),
            })
        return result
freqtrade_db = FreqtradeDB()
