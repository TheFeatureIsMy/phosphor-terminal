"""Price + decision trace for the replay chart.

Reads the latest Freqtrade backtest export and the local BTC 5m candles.
This is a replay of a finished backtest, not a live order stream.
"""
from __future__ import annotations

import base64
import json
import zipfile
from pathlib import Path

import pandas as pd
from fastapi import APIRouter, HTTPException

from app.config import settings

router = APIRouter(prefix="/api/v2/trace", tags=["trace"])

_ROOT = Path(__file__).resolve().parents[3]
_DATA = _ROOT / "freqtrade" / "user_data" / "data" / "binance" / "BTC_USDT-5m.feather"
_RESULTS = _ROOT / "freqtrade" / "user_data" / "backtest_results"


def _latest_export() -> Path:
    zips = sorted(_RESULTS.glob("backtest-result-*.zip"))
    if not zips:
        raise HTTPException(status_code=404, detail="no backtest export")
    return zips[-1]


def _rsi(closes: list[float], period: int = 14) -> float | None:
    if len(closes) <= period:
        return None
    gain = 0.0
    loss = 0.0
    for i in range(1, period + 1):
        delta = closes[i] - closes[i - 1]
        gain += max(delta, 0.0)
        loss += max(-delta, 0.0)
    avg_gain = gain / period
    avg_loss = loss / period
    alpha = 1 / period
    for price_prev, price in zip(closes[period:-1], closes[period + 1 :]):
        delta = price - price_prev
        avg_gain = avg_gain + alpha * (max(delta, 0.0) - avg_gain)
        avg_loss = avg_loss + alpha * (max(-delta, 0.0) - avg_loss)
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return round(100 - (100 / (1 + rs)), 2)


_price_cache: dict = {"price": None, "at": 0.0}
_price_thread_started = False


def _price_loop() -> None:
    import time
    while True:
        price = _binance_last()
        if price is not None:
            _price_cache["price"] = price
            _price_cache["at"] = time.time()
        time.sleep(0.5)


def _ensure_price_thread() -> None:
    global _price_thread_started
    if _price_thread_started:
        return
    import threading
    _price_thread_started = True
    threading.Thread(target=_price_loop, name="binance-ticker", daemon=True).start()


_BARS = {
    "1m": 60,
    "5m": 300,
    "15m": 900,
    "30m": 1800,
    "1h": 3600,
    "4h": 14400,
    "12h": 43200,
    "1d": 86400,
}
_kline_cache: dict[str, tuple[float, list]] = {}


def _curl_json(url: str):
    import subprocess
    out = subprocess.check_output(["curl", "-fsS", "--max-time", "4", url], timeout=5)
    return json.loads(out)


def _binance_last(symbol: str = "BTCUSDT") -> float | None:
    # This machine's Python trust store rejects the TLS intercept cert.
    # curl uses the system keychain and reaches Binance.
    try:
        return float(_curl_json(f"https://api.binance.com/api/v3/ticker/price?symbol={symbol}")["price"])
    except Exception:
        return None


def _ft_headers() -> dict[str, str]:
    credentials = (
        f"{settings.freqtrade_username}:{settings.freqtrade_password}".encode()
    )
    return {"Authorization": "Basic " + base64.b64encode(credentials).decode()}


def _ft_url(path: str) -> str:
    return settings.freqtrade_url.rstrip("/") + path


def _ft_get(path: str) -> dict | list | None:
    import urllib.request
    req = urllib.request.Request(_ft_url(path), headers=_ft_headers())
    try:
        with urllib.request.urlopen(req, timeout=2) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return None


def _paper() -> dict:
    import urllib.request
    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                _ft_url("/api/v1/count"),
                headers=_ft_headers(),
            ),
            timeout=1.5,
        ) as resp:
            count = json.loads(resp.read().decode())
        return {
            "running": True,
            "open_trades": count.get("current", 0),
            "max_open_trades": count.get("max", 0),
        }
    except Exception:
        return {"running": False, "open_trades": 0, "max_open_trades": 0}


@router.get("/replay")
def replay() -> dict:
    if not _DATA.exists():
        raise HTTPException(status_code=404, detail="candle file missing")
    export = _latest_export()
    frame = pd.read_feather(_DATA)
    candles = [
        {
            "time": int(ts.timestamp()),
            "open": float(o),
            "high": float(h),
            "low": float(l),
            "close": float(c),
            "volume": float(v),
        }
        for ts, o, h, l, c, v in zip(
            frame["date"], frame["open"], frame["high"], frame["low"], frame["close"], frame["volume"]
        )
    ]

    with zipfile.ZipFile(export) as zf:
        name = next(n for n in zf.namelist() if n.endswith(".json") and "config" not in n)
        payload = json.loads(zf.read(name))
    strat = payload["strategy"]["PulseDeskUniversalStrategy"]
    trades = []
    for i, t in enumerate(strat.get("trades") or []):
        open_ts = int(t["open_timestamp"] // 1000)
        close_ts = int(t["close_timestamp"] // 1000) if t.get("close_timestamp") else open_ts
        profit_pct = round(float(t.get("profit_ratio") or 0) * 100, 3)
        exit_reason = t.get("exit_reason") or "open"
        trades.append({
            "id": i + 1,
            "open_time": open_ts,
            "close_time": close_ts,
            "open_rate": t["open_rate"],
            "close_rate": t.get("close_rate"),
            "profit_pct": profit_pct,
            "exit_reason": exit_reason,
            "stake": t.get("stake_amount"),
            "chain": [
                {"step": "signal", "label": "5m RSI(14) 跌破 30"},
                {"step": "strategy", "label": "RSI 14 示例 v1 允许开多"},
                {"step": "command", "label": "回测撮合，不是实盘命令"},
                {"step": "order", "label": f"买入 {t.get('stake_amount')} USDT @ {t['open_rate']}"},
                {"step": "fill", "label": f"{exit_reason} @ {t.get('close_rate')}  {profit_pct}%"},
                {"step": "ledger", "label": "记在回测导出里，未写入实盘账本"},
            ],
        })

    return {
        "pair": "BTC/USDT",
        "timeframe": "5m",
        "source": export.name,
        "summary": {
            "trades": strat.get("total_trades"),
            "wins": strat.get("wins"),
            "losses": strat.get("losses"),
            "winrate": strat.get("winrate"),
            "profit_abs": strat.get("profit_total_abs"),
            "profit_pct": strat.get("profit_total"),
            "sharpe": strat.get("sharpe"),
            "max_drawdown_abs": strat.get("max_drawdown_abs"),
            "timerange": strat.get("timerange"),
            "market_change": strat.get("market_change"),
        },
        "candles": candles,
        "trades": trades,
        "paper": _paper(),
    }


@router.get("/live")
def live() -> dict:
    """What the running strategy is doing on the latest candle."""
    raw = _ft_get("/api/v1/pair_candles?pair=BTC/USDT&timeframe=5m&limit=240")
    status = _ft_get("/api/v1/status")
    show = _ft_get("/api/v1/show_config")
    if not isinstance(raw, dict) or not raw.get("data"):
        raise HTTPException(status_code=503, detail="strategy bot is not publishing candles")

    columns = list(raw["columns"])
    idx = {name: i for i, name in enumerate(columns)}
    candles = []
    for row in raw["data"]:
        ts = row[idx["__date_ts"]]
        candles.append({
            "time": int(ts // 1000),
            "open": row[idx["open"]],
            "high": row[idx["high"]],
            "low": row[idx["low"]],
            "close": row[idx["close"]],
            "volume": row[idx["volume"]],
            "enter": int(row[idx["enter_long"]] or 0),
            "exit": int(row[idx["exit_long"]] or 0),
        })
    last = candles[-1]
    rsi = _rsi([c["close"] for c in candles])
    hit = bool(last["enter"])
    exiting = bool(last["exit"])
    open_trades = status if isinstance(status, list) else []
    bot_state = (show or {}).get("state") if isinstance(show, dict) else None
    if hit:
        decision = "enter"
        strategy_text = "RSI 跌破 30，规则通过，准备开多"
    elif exiting and open_trades:
        decision = "exit"
        strategy_text = "RSI 高于 70，规则要求平仓"
    else:
        decision = "wait"
        strategy_text = "规则未命中，保持空仓" if not open_trades else "持仓中，出场条件未到"
    return {
        "pair": raw.get("pair") or "BTC/USDT",
        "timeframe": "5m",
        "analyzed_at": raw.get("last_analyzed"),
        "bot_state": bot_state or "unknown",
        "dry_run": bool((show or {}).get("dry_run")) if isinstance(show, dict) else True,
        "last_price": last["close"],
        "rsi": rsi,
        "decision": decision,
        "strategy_text": strategy_text,
        "candle": last,
        "candles": candles,
        "open_trades": [
            {
                "id": t.get("trade_id"),
                "pair": t.get("pair"),
                "open_rate": t.get("open_rate"),
                "current_rate": t.get("current_rate"),
                "profit_pct": round(float(t.get("profit_pct") or 0), 3),
                "stake": t.get("stake_amount"),
                "open_time": int(t["open_timestamp"] // 1000) if t.get("open_timestamp") and t["open_timestamp"] > 10_000_000_000 else t.get("open_timestamp"),
            }
            for t in open_trades
        ],
    }


@router.get("/candles")
def candles(timeframe: str = "5m") -> dict:
    """Closed and forming Binance klines. Cached so a timeframe is not re-downloaded every tick."""
    import time
    if timeframe not in _BARS:
        raise HTTPException(status_code=400, detail="unknown timeframe")
    hit = _kline_cache.get(timeframe)
    if hit and time.time() - hit[0] < 30:
        return {"timeframe": timeframe, "candles": hit[1]}
    try:
        raw = _curl_json(
            f"https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval={timeframe}&limit=300"
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail="klines unavailable") from exc
    parsed = [
        {
            "time": int(row[0] // 1000),
            "open": float(row[1]),
            "high": float(row[2]),
            "low": float(row[3]),
            "close": float(row[4]),
            "volume": float(row[5]),
        }
        for row in raw
    ]
    _kline_cache[timeframe] = (time.time(), parsed)
    return {"timeframe": timeframe, "candles": parsed}


@router.get("/tick")
def tick(timeframe: str = "5m") -> dict:
    """Latest public trade. Served from a cache so the page does not wait on Binance."""
    import time
    if timeframe not in _BARS:
        raise HTTPException(status_code=400, detail="unknown timeframe")
    _ensure_price_thread()
    deadline = time.time() + 2
    price = _price_cache["price"]
    while price is None and time.time() < deadline:
        time.sleep(0.05)
        price = _price_cache["price"]
    if price is None:
        raise HTTPException(status_code=503, detail="ticker unavailable")
    now = int(time.time())
    seconds = _BARS[timeframe]
    return {"price": price, "bar_time": now - (now % seconds), "timeframe": timeframe, "now": now}
