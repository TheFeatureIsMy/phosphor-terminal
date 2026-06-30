# Backtest/Sim Deep Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the BacktestLab page as a three-column linked-flow layout (Run Rail / phase-driven Center / always-visible Context Rail) with Backtest/Dryrun tabs, fix the backend persistence gap so all results are real, and remove the mock crutch.

**Architecture:** Backend: `backtest_runner` normalizes freqtrade trade dicts to `TradeRow` keys and derives an equity curve; `backtest_handler._handle_success` persists trades + equity_curve into `BacktestRun.result`. Frontend: `BacktestLabViewModel` loses its mock-default toggle and gains `activeTab`/`submittedConfig`; `BacktestLabView` becomes a three-column container; `NewRunSheet` is deleted in favor of an inline `ConfigPanel`. Types split out of `Types.swift`; deprecated v1 API deleted; mock factories centralized.

**Tech Stack:** Python 3.12 / FastAPI / SQLAlchemy / Pydantic v2 (backend); Swift 6.2 / SwiftUI / macOS 26 (app); pytest / XCTest (tests).

## Global Constraints

- Backend Python 3.12, run via `.venv/bin/python` (system `python3` is 3.9 and can't import backend).
- Backend test gate: `--cov-fail-under=30`; 17 pre-existing failures must stay at 17 (zero regression).
- macOS: Swift tools 6.2, target macOS 26, no SPM dependencies, executable target `AlphaLoop`.
- `.glassEffect()` applied directly to content, never inside `.background`.
- All user-visible strings via `L10n.<Domain>`; zh-CN default, en-US toggle.
- Reply to user in Chinese; code/identifiers/committed docs in English.
- No client-side fabricated performance data. Honest empty states when backend returns none.
- `canvas-web` dist must use `.copy()` not `.process()` into `macos-app` Resources (not touched here, but do not regress).

---

## File Structure

**Backend (modify):**
- `backend/app/services/backtest_runner.py` — normalize trade dicts, build equity_curve
- `backend/app/workers/backtest_handler.py` — persist trades + equity_curve into `result`
- `backend/tests/test_backtest_handler.py` — add persistence assertions
- `backend/tests/test_backtest_runner_parsing.py` — new, runner parsing tests

**macOS app (create/modify):**
- `Models/BacktestTypes.swift` — new, extracted from `Types.swift`
- `Models/DryrunTypes.swift` — new, dryrun models
- `Models/Types.swift` — modified (backtest models removed)
- `Services/APIBacktestV2.swift` — modified (mock moved out)
- `Services/APIBacktest.swift` — **deleted**
- `Services/APIDryrunV2.swift` — modified (list/get/sync completion, mock cleanup)
- `Services/MockGenerators/MockBacktest.swift` — new, centralized mock factories
- `ViewModels/BacktestLabViewModel.swift` — rewrite
- `Views/BacktestAndDryrun/BacktestLabView.swift` — rewrite (three-column)
- `Views/BacktestAndDryrun/LeftRail/RunRailView.swift` — new
- `Views/BacktestAndDryrun/Center/ConfigPanel.swift` — new (replaces NewRunSheet)
- `Views/BacktestAndDryrun/Center/StatusSummaryBlock.swift` — new
- `Views/BacktestAndDryrun/Center/EquityCurveBlock.swift` — new
- `Views/BacktestAndDryrun/Center/TradeListBlock.swift` — new
- `Views/BacktestAndDryrun/Center/CompareBlock.swift` — new
- `Views/BacktestAndDryrun/RightRail/StrategyMetaPanel.swift` — new
- `Views/BacktestAndDryrun/RightRail/RiskWarningsPanel.swift` — new
- `Views/BacktestAndDryrun/RightRail/PromotionPanel.swift` — rewrite (simplified)
- `Views/BacktestAndDryrun/Shared/SectionCard.swift` — keep
- `Views/BacktestAndDryrun/Shared/RiskWarningRules.swift` — keep
- `Views/BacktestAndDryrun/Shared/RunFailureClustering.swift` — keep
- `Views/BacktestAndDryrun/NewRunSheet.swift` — **deleted**
- `Views/BacktestAndDryrun/Sections/*` — **deleted** (old 9-section files)
- `Localization/L10n+Backtest.swift` — restructure

**Docs:**
- `docs/user-guide/content/{zh,en}/backtest-lab.html` — update

---

## Task 1: Backend — Runner normalizes trades and builds equity_curve

**Files:**
- Modify: `backend/app/services/backtest_runner.py` (the `_parse_result` method, ~line 217-265)
- Test: `backend/tests/test_backtest_runner_parsing.py` (new)

**Interfaces:**
- Consumes: freqtrade raw export JSON (`raw["strategy"][strat_key]["trades"]` — list of dicts with keys `open_date`, `close_date`, `pair`, `trade_direction`/`is_short`, `open_rate`, `close_rate`, `amount`, `profit_abs`, `profit_ratio`)
- Produces: `BacktestResult.trades` as `list[dict]` with keys matching `TradeRow` schema (`open_time`, `close_time`, `pair`, `side`, `open_price`, `close_price`, `quantity`, `profit`, `duration`, `mtf_state`); `BacktestResult.equity_curve` as `list[dict]` with keys `timestamp`, `equity`, `drawdown`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_backtest_runner_parsing.py`:

```python
"""Tests for FreqtradeBacktestRunner result parsing — trade normalization + equity curve."""
from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pytest

from app.services.backtest_runner import FreqtradeBacktestRunner, BacktestResult


def _freqtrade_raw():
    """A minimal freqtrade backtest export with 3 trades."""
    return {
        "strategy": {
            "PulseDeskUniversalStrategy": {
                "total_trades": 3,
                "trades": [
                    {
                        "open_date": "2026-01-01 00:00:00",
                        "close_date": "2026-01-01 02:00:00",
                        "pair": "BTC/USDT",
                        "trade_direction": "long",
                        "open_rate": 40000.0,
                        "close_rate": 40500.0,
                        "amount": 0.01,
                        "profit_abs": 5.0,
                        "profit_ratio": 0.0125,
                    },
                    {
                        "open_date": "2026-01-02 03:00:00",
                        "close_date": "2026-01-02 06:00:00",
                        "pair": "ETH/USDT",
                        "trade_direction": "short",
                        "open_rate": 3000.0,
                        "close_rate": 2950.0,
                        "amount": 0.5,
                        "profit_abs": 25.0,
                        "profit_ratio": 0.0167,
                    },
                    {
                        "open_date": "2026-01-03 09:00:00",
                        "close_date": "2026-01-03 12:00:00",
                        "pair": "BTC/USDT",
                        "trade_direction": "long",
                        "open_rate": 40500.0,
                        "close_rate": 40000.0,
                        "amount": 0.01,
                        "profit_abs": -5.0,
                        "profit_ratio": -0.0123,
                    },
                ],
                "profit_total": 0.000625,
                "max_drawdown": -0.02,
                "trade_count": 3,
                "wins": 2,
                "profit_factor": 6.0,
                "sharpe": 1.5,
                "holding_avg": "3h 0m",
                "best_trade": 0.0167,
                "worst_trade": -0.0123,
            }
        }
    }


def test_parse_result_normalizes_trade_keys(tmp_path):
    """Trades from freqtrade use open_date/open_rate/profit_abs; runner must
    normalize to open_time/open_price/profit to match TradeRow schema."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    with patch.object(runner, "_find_result_file", return_value=tmp_path / "result.json"):
        (tmp_path / "result.json").write_text(json.dumps(raw))
        result = runner._parse_result("result.json")

    assert result.success
    assert len(result.trades) == 3
    t0 = result.trades[0]
    assert t0["open_time"] == "2026-01-01 00:00:00"
    assert t0["close_time"] == "2026-01-01 02:00:00"
    assert t0["pair"] == "BTC/USDT"
    assert t0["side"] == "long"
    assert t0["open_price"] == 40000.0
    assert t0["close_price"] == 40500.0
    assert t0["quantity"] == 0.01
    assert t0["profit"] == 5.0
    assert "duration" in t0
    assert "mtf_state" in t0  # may be None


def test_parse_result_short_side_mapping(tmp_path):
    """freqtrade trade_direction 'short' maps to side 'short'."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    with patch.object(runner, "_find_result_file", return_value=tmp_path / "result.json"):
        (tmp_path / "result.json").write_text(json.dumps(raw))
        result = runner._parse_result("result.json")

    assert result.trades[1]["side"] == "short"


def test_parse_result_builds_equity_curve(tmp_path):
    """Runner must derive an equity_curve from trades, cumulative on initial capital."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    with patch.object(runner, "_find_result_file", return_value=tmp_path / "result.json"):
        (tmp_path / "result.json").write_text(json.dumps(raw))
        result = runner._parse_result("result.json")

    assert len(result.equity_curve) >= 3
    # Each point has timestamp/equity/drawdown
    for p in result.equity_curve:
        assert "timestamp" in p
        assert "equity" in p
        assert "drawdown" in p
    # Equity is cumulative starting from initial capital (default 10000)
    # Trade 0 profit +5 → 10005, Trade 1 +25 → 10030, Trade 2 -5 → 10025
    assert result.equity_curve[0]["equity"] == pytest.approx(10005.0)
    assert result.equity_curve[1]["equity"] == pytest.approx(10030.0)
    assert result.equity_curve[2]["equity"] == pytest.approx(10025.0)


def test_parse_result_drawdown_nonpositive(tmp_path):
    """Drawdown values should be <= 0 (peak-to-trough is negative or zero)."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    with patch.object(runner, "_find_result_file", return_value=tmp_path / "result.json"):
        (tmp_path / "result.json").write_text(json.dumps(raw))
        result = runner._parse_result("result.json")

    for p in result.equity_curve:
        assert p["drawdown"] <= 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/python -m pytest tests/test_backtest_runner_parsing.py -v`
Expected: FAIL — `result.trades[0]["open_time"]` KeyError (trades still have freqtrade keys), `result.equity_curve` empty.

- [ ] **Step 3: Implement trade normalization + equity curve derivation**

In `backend/app/services/backtest_runner.py`, locate the final `return BacktestResult(success=True, metrics=metrics, trades=trades_list, raw_result=raw)` in `_parse_result` (around line 263). Replace `trades=trades_list` with normalized trades and add equity_curve. Insert a normalization step before the return:

```python
        s = strategy_data[strat_key]
        trades_list = s.get("trades", [])
        metrics = BacktestMetrics(
            total_return_pct=s.get("profit_total", 0) * 100,
            sharpe_ratio=s.get("sharpe", 0),
            max_drawdown_pct=abs(s.get("max_drawdown", 0)) * 100,
            win_rate=(s.get("wins", 0) / max(s.get("trade_count", 1), 1)),
            profit_factor=s.get("profit_factor", 0),
            total_trades=s.get("trade_count", 0),
            avg_trade_duration=s.get("holding_avg", ""),
            best_trade_pct=s.get("best_trade", 0) * 100,
            worst_trade_pct=s.get("worst_trade", 0) * 100,
        )

        normalized_trades = [
            self._normalize_trade(t) for t in trades_list
        ]
        equity_curve = self._build_equity_curve(normalized_trades, initial_capital=10000.0)

        return BacktestResult(
            success=True,
            metrics=metrics,
            trades=normalized_trades,
            equity_curve=equity_curve,
            raw_result=raw,
        )
```

Add two helper methods to the `FreqtradeBacktestRunner` class (place after `_parse_result`, before `_cleanup`):

```python
    @staticmethod
    def _normalize_trade(t: dict[str, Any]) -> dict[str, Any]:
        """Map freqtrade trade dict keys to TradeRow schema keys."""
        direction = t.get("trade_direction") or ("short" if t.get("is_short") else "long")
        open_time = str(t.get("open_date", t.get("open_timestamp", "")))
        close_time = str(t.get("close_date", t.get("close_timestamp", "")))
        open_price = float(t.get("open_rate", t.get("entry_price", 0.0)) or 0.0)
        close_price = float(t.get("close_rate", t.get("exit_price", 0.0)) or 0.0)
        quantity = float(t.get("amount", t.get("stake_amount", 0.0)) or 0.0)
        profit = float(t.get("profit_abs", t.get("profit_amount", 0.0)) or 0.0)
        duration = str(t.get("trade_duration", t.get("holding_avg", "")))
        return {
            "open_time": open_time,
            "close_time": close_time,
            "pair": str(t.get("pair", "")),
            "side": direction,
            "open_price": open_price,
            "close_price": close_price,
            "quantity": quantity,
            "profit": profit,
            "duration": duration,
            "mtf_state": t.get("mtf_state"),
        }

    @staticmethod
    def _build_equity_curve(
        trades: list[dict[str, Any]], initial_capital: float = 10000.0
    ) -> list[dict[str, Any]]:
        """Derive a per-trade equity curve from normalized trades.

        Each point = cumulative capital after closing that trade.
        Drawdown = current equity minus running peak (<= 0).
        """
        curve: list[dict[str, Any]] = []
        equity = initial_capital
        peak = initial_capital
        for t in trades:
            equity += float(t.get("profit", 0.0))
            peak = max(peak, equity)
            drawdown = equity - peak  # <= 0
            curve.append({
                "timestamp": t.get("close_time", ""),
                "equity": round(equity, 6),
                "drawdown": round(drawdown, 6),
            })
        return curve
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/python -m pytest tests/test_backtest_runner_parsing.py -v`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Run existing backtest handler tests to verify no regression**

Run: `cd backend && .venv/bin/python -m pytest tests/test_backtest_handler.py -v`
Expected: PASS — existing tests still pass (they use `_success_result` which doesn't set trades/equity_curve, so the new fields default to empty lists; handler tests don't assert on those fields yet).

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/backtest_runner.py backend/tests/test_backtest_runner_parsing.py
git commit -m "feat(backtest): normalize freqtrade trades to TradeRow keys + derive equity curve"
```

---

## Task 2: Backend — Handler persists trades + equity_curve into BacktestRun.result

**Files:**
- Modify: `backend/app/workers/backtest_handler.py` (`_handle_success`, ~line 232-256)
- Test: `backend/tests/test_backtest_handler.py` (add persistence assertions)

**Interfaces:**
- Consumes: `BacktestResult.trades` and `BacktestResult.equity_curve` (list[dict] from Task 1)
- Produces: `BacktestRun.result["trades"]` and `BacktestRun.result["equity_curve"]` populated; `BacktestRunResponse.model_validator` extracts them into typed `equity_curve: list[EquityPoint]` and `trades: list[TradeRow]`

- [ ] **Step 1: Write the failing test**

In `backend/tests/test_backtest_handler.py`, update the `_success_result` helper to include trades and equity_curve, and add assertions to `test_handler_success`. First, modify the `_success_result` helper (around line 88):

```python
def _success_result(metrics=None):
    return BacktestResult(
        success=True,
        metrics=metrics or _success_metrics(),
        trades=[
            {
                "open_time": "2026-01-01 00:00:00",
                "close_time": "2026-01-01 02:00:00",
                "pair": "BTC/USDT",
                "side": "long",
                "open_price": 40000.0,
                "close_price": 40500.0,
                "quantity": 0.01,
                "profit": 5.0,
                "duration": "2h",
                "mtf_state": None,
            },
        ],
        equity_curve=[
            {"timestamp": "2026-01-01 02:00:00", "equity": 10005.0, "drawdown": 0.0},
        ],
    )
```

Then add a new test at the end of the file (after `test_handler_creates_backtest_run`):

```python
@patch("app.workers.backtest_handler.FreqtradeBacktestRunner")
def test_handler_success_persists_trades_and_equity_curve(mock_runner_cls, session):
    """_handle_success must write result.trades and result.equity_curve into
    BacktestRun.result so BacktestRunResponse can extract them."""
    metrics = _success_metrics()
    mock_runner_cls.return_value.run.return_value = _success_result(metrics)

    cmd = _make_command(session)
    handler = StartBacktestHandler()
    handler.execute(cmd, session)

    bt_run = session.query(BacktestRun).filter_by(command_id=str(cmd.id)).one()
    assert bt_run.status == "completed"
    assert "equity_curve" in bt_run.result
    assert "trades" in bt_run.result
    assert len(bt_run.result["equity_curve"]) == 1
    assert len(bt_run.result["trades"]) == 1
    persisted_trade = bt_run.result["trades"][0]
    assert persisted_trade["open_time"] == "2026-01-01 00:00:00"
    assert persisted_trade["pair"] == "BTC/USDT"
    assert persisted_trade["side"] == "long"
    assert persisted_trade["open_price"] == 40000.0
    assert persisted_trade["profit"] == 5.0
    persisted_point = bt_run.result["equity_curve"][0]
    assert persisted_point["timestamp"] == "2026-01-01 02:00:00"
    assert persisted_point["equity"] == 10005.0
    assert persisted_point["drawdown"] == 0.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/python -m pytest tests/test_backtest_handler.py::test_handler_success_persists_trades_and_equity_curve -v`
Expected: FAIL — `assert "equity_curve" in bt_run.result` fails (handler only writes metrics + trade_count).

- [ ] **Step 3: Implement persistence in _handle_success**

In `backend/app/workers/backtest_handler.py`, locate `_handle_success` and replace the `backtest_run.result = {...}` block (around line 241) with:

```python
        backtest_run.result = {
            "metrics": {
                "total_return": m.total_return_pct,
                "sharpe_ratio": m.sharpe_ratio,
                "max_drawdown": m.max_drawdown_pct,
                "win_rate": m.win_rate,
                "profit_factor": m.profit_factor,
                "total_trades": m.total_trades,
                "avg_trade_duration": m.avg_trade_duration,
                "best_trade": m.best_trade_pct,
                "worst_trade": m.worst_trade_pct,
            },
            "trade_count": len(result.trades),
            "equity_curve": [
                {
                    "timestamp": p.get("timestamp", ""),
                    "equity": p.get("equity", 0.0),
                    "drawdown": p.get("drawdown", 0.0),
                }
                for p in result.equity_curve
            ],
            "trades": [
                {
                    "open_time": t.get("open_time", ""),
                    "close_time": t.get("close_time", ""),
                    "pair": t.get("pair", ""),
                    "side": t.get("side", ""),
                    "open_price": t.get("open_price", 0.0),
                    "close_price": t.get("close_price", 0.0),
                    "quantity": t.get("quantity", 0.0),
                    "profit": t.get("profit", 0.0),
                    "duration": t.get("duration", ""),
                    "mtf_state": t.get("mtf_state"),
                }
                for t in result.trades
            ],
        }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/python -m pytest tests/test_backtest_handler.py::test_handler_success_persists_trades_and_equity_curve -v`
Expected: PASS.

- [ ] **Step 5: Run full backend test suite for regression check**

Run: `cd backend && .venv/bin/python -m pytest tests/ -q`
Expected: 1246 passed (was 1245 + 4 new runner tests + 1 new handler test = 1250, but the 17 pre-existing failures remain). Confirm failure count is still exactly 17 and they match the known list.

- [ ] **Step 6: Commit**

```bash
git add backend/app/workers/backtest_handler.py backend/tests/test_backtest_handler.py
git commit -m "fix(backtest): persist trades + equity_curve in BacktestRun.result"
```

---

## Task 3: Backend — Verify DryRunRunResponse field coverage for Run Rail

**Files:**
- Modify (if needed): `backend/app/schemas/dryrun_v2.py` (`DryRunRunResponse`, ~line 40-57)
- Test: `backend/tests/test_dryrun_v2_schema.py` (new or extend)

**Interfaces:**
- Produces: `DryRunRunResponse` exposes `status`, `open_trades`, `total_profit`, `pid`, `created_at`, `stopped_at`, `symbols`, `stake_amount` — enough for Run Rail rows.

- [ ] **Step 1: Inspect current DryRunRunResponse fields**

Run: `cd backend && sed -n '40,66p' app/schemas/dryrun_v2.py`

The schema already has `status`, `pid`, `open_trades`, `total_profit` (confirmed in survey). Confirm it also has `created_at`, `stopped_at`, `symbols`, `stake_amount`. If any are missing, add them.

- [ ] **Step 2: Write the field-coverage test**

Create `backend/tests/test_dryrun_v2_schema.py`:

```python
"""Verify DryRunRunResponse exposes all fields the macOS Run Rail needs."""
from app.schemas.dryrun_v2 import DryRunRunResponse


def test_dryrun_run_response_has_runrail_fields():
    """Run Rail needs: status, open_trades, total_profit, pid, created_at, stopped_at, symbols, stake_amount."""
    sample = {
        "id": 1,
        "strategy_id": 1,
        "status": "running",
        "pid": 12345,
        "open_trades": 2,
        "total_profit": 12.5,
        "symbols": ["BTC/USDT"],
        "stake_amount": 100.0,
        "created_at": "2026-06-30T00:00:00Z",
        "stopped_at": None,
    }
    resp = DryRunRunResponse(**sample)
    assert resp.status == "running"
    assert resp.open_trades == 2
    assert resp.total_profit == 12.5
    assert resp.pid == 12345
    assert resp.symbols == ["BTC/USDT"]
    assert resp.stake_amount == 100.0
```

- [ ] **Step 3: Run test, add missing fields if it fails**

Run: `cd backend && .venv/bin/python -m pytest tests/test_dryrun_v2_schema.py -v`
If FAIL on a missing field (e.g. `symbols` or `created_at`), add it to `DryRunRunResponse` in `app/schemas/dryrun_v2.py`:

```python
class DryRunRunResponse(BaseModel):
    id: int
    strategy_id: int
    strategy_version_id: Optional[str] = None
    command_id: Optional[str] = None
    dsl_hash: Optional[str] = None
    status: str
    pid: Optional[int] = None
    api_port: Optional[int] = None
    api_url: Optional[str] = None
    symbols: list[str] = []
    stake_amount: float = 100.0
    max_open_trades: int = 5
    initial_wallet: float = 10000.0
    exchange: str = "binance"
    total_trades: int = 0
    open_trades: int = 0
    total_profit: float = 0.0
    error_message: Optional[str] = None
    created_at: Optional[str] = None
    started_at: Optional[str] = None
    stopped_at: Optional[str] = None
```

(Use the field list already present + add any missing. Confirm against `DryRunRun` model columns in `app/models/dryrun.py:13-39`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/python -m pytest tests/test_dryrun_v2_schema.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/dryrun_v2.py backend/tests/test_dryrun_v2_schema.py
git commit -m "test(dryrun): verify DryRunRunResponse Run Rail field coverage"
```

---

## Task 4: macOS — Extract BacktestTypes.swift from Types.swift

**Files:**
- Create: `macos-app/AlphaLoop/Models/BacktestTypes.swift`
- Modify: `macos-app/AlphaLoop/Models/Types.swift` (remove the moved structs)

**Interfaces:**
- Produces: `BacktestMetrics`, `BacktestEquityPoint`, `TradeRow`, `FailureClusterSummary`, `BacktestRunV2`, `BacktestStatusV2`, `BacktestRunSummary` — moved to `BacktestTypes.swift`, same definitions.

- [ ] **Step 1: Read the backtest-related structs in Types.swift**

Run: `cd macos-app && sed -n '159,180p;531,575p;594,640p;731,760p;1134,1160p' AlphaLoop/Models/Types.swift`

Capture the exact current definitions of: `BacktestMetrics` (line 159), `BacktestEquityPoint` (531), `TradeRow` (538), `FailureClusterSummary` (562), `BacktestRunV2` (594), `BacktestStatusV2` (731), `BacktestRunSummary` (1134).

- [ ] **Step 2: Create BacktestTypes.swift with the moved structs**

Create `macos-app/AlphaLoop/Models/BacktestTypes.swift`. Paste the exact struct definitions captured in Step 1, with a file header:

```swift
// BacktestTypes.swift — Backtest/dryrun response models (extracted from Types.swift)

import Foundation
```

Include all 7 structs verbatim (`BacktestMetrics`, `BacktestEquityPoint`, `TradeRow`, `FailureClusterSummary`, `BacktestRunV2` with its `CodingKeys` enum, `BacktestStatusV2`, `BacktestRunSummary`). Do not alter field names, types, or CodingKeys.

- [ ] **Step 3: Delete the moved structs from Types.swift**

Remove the 7 struct definitions from `Types.swift` (lines ~159-175, 531-575, 594-640, 731-760, 1134-1160). Leave all other structs untouched. Add a comment at the top of `Types.swift` noting the extraction:

```swift
// Backtest/dryrun models moved to BacktestTypes.swift and DryrunTypes.swift
```

- [ ] **Step 4: Build to verify no duplicate-symbol or missing-symbol errors**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: Build complete. If you see "redefinition of struct" — you left a copy in Types.swift; remove it. If you see "cannot find type 'X' in scope" — a view still references it; the struct is now in BacktestTypes.swift (same module, no import needed) so this should resolve once Types.swift copy is removed.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Models/BacktestTypes.swift macos-app/AlphaLoop/Models/Types.swift
git commit -m "refactor(macos): extract backtest models to BacktestTypes.swift"
```

---

## Task 5: macOS — Create DryrunTypes.swift + extend APIDryrunV2

**Files:**
- Create: `macos-app/AlphaLoop/Models/DryrunTypes.swift`
- Modify: `macos-app/AlphaLoop/Services/APIDryrunV2.swift`

**Interfaces:**
- Produces: `DryRunRunV2` (id, strategyId, status, pid, openTrades, totalProfit, symbols, stakeAmount, createdAt, stoppedAt, errorMessage), `DryRunDetailResponse` matching backend `DryRunRunResponse`. `APIDryrunV2.getDryrun(id:)` and `.syncDryrun(id:)` methods.

- [ ] **Step 1: Create DryrunTypes.swift**

Create `macos-app/AlphaLoop/Models/DryrunTypes.swift`:

```swift
// DryrunTypes.swift — Dryrun (live simulation) response models

import Foundation

struct DryRunRunV2: Codable, Identifiable, Hashable {
    let id: Int
    let strategyId: Int
    let strategyVersionId: String?
    let commandId: String?
    let dslHash: String?
    let status: String
    let pid: Int?
    let apiPort: Int?
    let apiUrl: String?
    let symbols: [String]
    let stakeAmount: Double
    let maxOpenTrades: Int
    let initialWallet: Double
    let exchange: String
    let totalTrades: Int
    let openTrades: Int
    let totalProfit: Double
    let errorMessage: String?
    let createdAt: String?
    let startedAt: String?
    let stoppedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, symbols, pid, exchange
        case strategyId = "strategy_id"
        case strategyVersionId = "strategy_version_id"
        case commandId = "command_id"
        case dslHash = "dsl_hash"
        case apiPort = "api_port"
        case apiUrl = "api_url"
        case stakeAmount = "stake_amount"
        case maxOpenTrades = "max_open_trades"
        case initialWallet = "initial_wallet"
        case totalTrades = "total_trades"
        case openTrades = "open_trades"
        case totalProfit = "total_profit"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
    }
}

struct DryRunSyncResponseV2: Codable, Hashable {
    let openTrades: Int
    let closedTrades: Int
    let totalProfit: Double

    enum CodingKeys: String, CodingKey {
        case openTrades = "open_trades"
        case closedTrades = "closed_trades"
        case totalProfit = "total_profit"
    }
}
```

- [ ] **Step 2: Add getDryrun(id:) and syncDryrun(id:) to APIDryrunV2**

In `macos-app/AlphaLoop/Services/APIDryrunV2.swift`, add two methods to the `APIDryrunV2` struct (after `listDryruns`):

```swift
    func getDryrun(_ id: Int) async throws -> DryRunRunV2 {
        try await client.get("/api/v2/dryrun/\(id)",
            mock: { MockDryrunV2.detail(id: id) })
    }

    func syncDryrun(_ id: Int) async throws -> DryRunSyncResponseV2 {
        try await client.post("/api/v2/dryrun/\(id)/sync", body: AnyEncodable([String: String]()),
            mock: { MockDryrunV2.sync(id: id) })
    }
```

And add corresponding mock factories to `MockDryrunV2`:

```swift
    static func detail(id: Int) -> DryRunRunV2 {
        DryRunRunV2(
            id: id, strategyId: 1, strategyVersionId: nil, commandId: UUID().uuidString,
            dslHash: "a1b2c3d4", status: "running", pid: 12345, apiPort: 8081, apiUrl: "http://127.0.0.1:8081",
            symbols: ["BTC/USDT"], stakeAmount: 100, maxOpenTrades: 5, initialWallet: 10000,
            exchange: "binance", totalTrades: 5, openTrades: 2, totalProfit: 12.5,
            errorMessage: nil, createdAt: "2026-06-30T00:00:00Z", startedAt: "2026-06-30T00:00:05Z",
            stoppedAt: nil
        )
    }

    static func sync(id: Int) -> DryRunSyncResponseV2 {
        DryRunSyncResponseV2(openTrades: 2, closedTrades: 3, totalProfit: 12.5)
    }
```

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: Build complete. If `MockDryrunV2.status`/`.list` return `DryRunStatusV2` (a different legacy type), leave those as-is — they're used by the existing `getDryrunStatus`/`listDryruns`. Only the new `detail`/`sync` mocks use the new types.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Models/DryrunTypes.swift macos-app/AlphaLoop/Services/APIDryrunV2.swift
git commit -m "feat(macos): add DryRunRunV2 type + getDryrun/syncDryrun API methods"
```

---

## Task 6: macOS — Centralize mock factories + delete v1 APIBacktest

**Files:**
- Create: `macos-app/AlphaLoop/Services/MockGenerators/MockBacktest.swift`
- Modify: `macos-app/AlphaLoop/Services/APIBacktestV2.swift` (remove inline MockDataV2)
- Delete: `macos-app/AlphaLoop/Services/APIBacktest.swift`

**Interfaces:**
- Produces: `MockBacktest.run(id:)`, `MockBacktest.status(commandId:)`, `MockBacktest.commandResponse()` — centralized, honest mock data (flat equity curve, modest metrics).

- [ ] **Step 1: Create MockGenerators/MockBacktest.swift**

Create the directory and file `macos-app/AlphaLoop/Services/MockGenerators/MockBacktest.swift`:

```swift
// MockBacktest.swift — Centralized mock factories for backtest responses.
// Honest data: flat equity curve, modest metrics — never get-rich patterns.

import Foundation

enum MockBacktest {
    static func commandResponse() -> BacktestCommandResponseV2 {
        BacktestCommandResponseV2(
            commandId: UUID().uuidString,
            status: "pending",
            message: "Backtest enqueued (mock)",
            idempotencyKey: UUID().uuidString
        )
    }

    static func status(commandId: String, runId: Int = 1) -> BacktestStatusV2 {
        BacktestStatusV2(
            commandId: commandId,
            commandStatus: "completed",
            backtestRun: run(id: runId),
            errorCode: nil,
            errorMessage: nil
        )
    }

    static func run(id: Int) -> BacktestRunV2 {
        // Flat, modest equity curve — 4 points, ~0.3% total return
        let equityCurve = [
            BacktestEquityPoint(timestamp: "2026-01-01", equity: 10000.0, drawdown: 0.0),
            BacktestEquityPoint(timestamp: "2026-01-08", equity: 10015.0, drawdown: -8.0),
            BacktestEquityPoint(timestamp: "2026-01-15", equity: 10022.0, drawdown: -3.0),
            BacktestEquityPoint(timestamp: "2026-01-22", equity: 10030.0, drawdown: 0.0),
        ]
        let trades = [
            TradeRow(openTime: "2026-01-01 00:00", closeTime: "2026-01-03 12:00",
                     pair: "BTC/USDT", side: "long", openPrice: 40000, closePrice: 40200,
                     quantity: 0.025, profit: 5.0, duration: "2d 12h", mtfState: nil),
            TradeRow(openTime: "2026-01-08 04:00", closeTime: "2026-01-09 06:00",
                     pair: "ETH/USDT", side: "long", openPrice: 3000, closePrice: 2990,
                     quantity: 0.5, profit: -5.0, duration: "1d 2h", mtfState: nil),
            TradeRow(openTime: "2026-01-15 08:00", closeTime: "2026-01-16 10:00",
                     pair: "BTC/USDT", side: "long", openPrice: 40100, closePrice: 40350,
                     quantity: 0.025, profit: 6.25, duration: "1d 2h", mtfState: nil),
        ]
        return BacktestRunV2(
            id: id, strategyId: 1, strategyVersionId: "v1", commandId: UUID().uuidString,
            dslHash: "a1b2c3d4", status: "completed",
            startDate: "2026-01-01", endDate: "2026-01-22",
            initialCapital: 10000.0, symbols: ["BTC/USDT", "ETH/USDT"],
            config: [:], result: [:],
            sharpeRatio: 0.42, maxDrawdown: 0.08, winRate: 0.66,
            totalReturn: 0.30, profitFactor: 1.6, totalTrades: 3,
            errorMessage: nil,
            createdAt: "2026-06-30T00:00:00Z", completedAt: "2026-06-30T00:01:00Z",
            equityCurve: equityCurve, trades: trades
        )
    }
}
```

- [ ] **Step 2: Update APIBacktestV2.swift to use MockBacktest**

In `macos-app/AlphaLoop/Services/APIBacktestV2.swift`, replace every `mock: { MockDataV2.mockX(...) }` closure with `mock: { MockBacktest.commandResponse() }` / `MockBacktest.status(commandId:)` / `MockBacktest.run(id:)`. Then delete the `enum MockDataV2 { ... }` block at the bottom of the file. Keep `BacktestCommandResponseV2` and any other non-mock types defined in this file.

- [ ] **Step 3: Delete APIBacktest.swift (v1)**

Run: `cd macos-app && git rm AlphaLoop/Services/APIBacktest.swift`

- [ ] **Step 4: Search for any remaining references to deleted v1 types**

Run: `cd macos-app && grep -rn "APIBacktest\b\|MockData\b\|MockDataV2" AlphaLoop/ | grep -v "APIBacktestV2\|MockBacktest"`
Fix any references (likely none — v1 was deprecated). If a view referenced v1 `run()`/`get()`/`list()`, switch it to the v2 equivalents.

- [ ] **Step 5: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: Build complete.

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Services/MockGenerators/MockBacktest.swift macos-app/AlphaLoop/Services/APIBacktestV2.swift
git rm macos-app/AlphaLoop/Services/APIBacktest.swift
git commit -m "refactor(macos): centralize backtest mocks + delete deprecated v1 API"
```

---

## Task 7: macOS — Rewrite BacktestLabViewModel

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift` (rewrite)

**Interfaces:**
- Consumes: `APIStrategiesV2`, `APIBacktestV2`, `APIDryrunV2`, `APIStrategyWorkspace`, `APIFailureClusters` (all existing)
- Produces: `BacktestLabViewModel` with `activeTab: RunTab`, `submittedConfig: RunConfig?`, `phase: Phase`, no `useMockClient` toggle, real dryrun support.

- [ ] **Step 1: Define RunTab + RunConfig types**

At the top of the rewritten `BacktestLabViewModel.swift`:

```swift
import Foundation
import SwiftUI

enum RunTab: String, CaseIterable, Identifiable {
    case backtest, dryrun
    var id: String { rawValue }
}

struct RunConfig: Hashable {
    var strategyId: Int
    var strategyUuid: String
    var symbols: [String]
    var timeframe: String
    var initialCapital: Double
    var fee: Double
    var slippageBps: Double
    // backtest-only
    var startDate: String?
    var endDate: String?
    // dryrun-only
    var stakeAmount: Double?
    var maxOpenTrades: Int?
    var initialWallet: Double?
}
```

- [ ] **Step 2: Write the ViewModel**

```swift
@Observable
@MainActor
final class BacktestLabViewModel {
    var phase: Phase = .idle
    var activeTab: RunTab = .backtest
    var selectedStrategy: StrategyV2?
    var submittedConfig: RunConfig?

    var currentBacktestRun: BacktestRunV2?
    var currentDryrunRun: DryRunRunV2?

    var backtestRuns: [BacktestRunV2] = []
    var dryrunRuns: [DryRunRunV2] = []

    var comparedBacktestIds: Set<Int> = []
    var comparedRuns: [BacktestRunV2] = []

    var readiness: PerStrategyReadiness?
    var strategyFailureClusters: [FailureClusterSummary] = []
    var errorMessage: String?

    var availableStrategies: [StrategyV2] = []
    var tradableSymbols: [String] = []

    private var pollTask: Task<Void, Never>?

    enum Phase: Equatable {
        case idle, configuring, running, completed, failed
    }

    @Environment(\.networkClient) private var networkClient

    init() {}

    func loadInitial() async {
        await loadStrategies()
        await loadRunHistory()
    }

    func loadStrategies() async {
        do {
            availableStrategies = try await APIStrategiesV2(client: networkClient).list()
        } catch {
            errorMessage = "Failed to load strategies: \(error.localizedDescription)"
        }
    }

    func loadRunHistory() async {
        switch activeTab {
        case .backtest:
            do {
                backtestRuns = try await APIBacktestV2(client: networkClient).listBacktestsV2(limit: 20)
            } catch { backtestRuns = [] }
        case .dryrun:
            // dryrun list returns [DryRunStatusV2]; map to DryRunRunV2 via detail fetch or accept status-only rows
            // For simplicity, leave dryrunRuns populated on row-click; list uses status objects directly in the view.
            dryrunRuns = []
        }
    }

    func switchTab(_ tab: RunTab) {
        activeTab = tab
        comparedBacktestIds = []
        comparedRuns = []
        Task { await loadRunHistory() }
    }

    func loadTradableSymbols(for strategy: StrategyV2) async {
        do {
            let snap = try await APIStrategyWorkspace(client: networkClient).getWorkspaceSnapshot(strategyId: strategy.id)
            tradableSymbols = snap.tradableSymbols ?? defaultSymbols
        } catch {
            tradableSymbols = defaultSymbols
        }
    }

    private var defaultSymbols: [String] {
        ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]
    }

    func startBacktest(config: RunConfig) async {
        submittedConfig = config
        phase = .running
        errorMessage = nil
        do {
            let api = APIBacktestV2(client: networkClient)
            let cmd = try await api.startBacktestV2(
                strategyId: config.strategyId,
                symbols: config.symbols,
                timeframe: config.timeframe,
                startDate: config.startDate ?? "",
                endDate: config.endDate ?? "",
                initialCapital: config.initialCapital,
                fee: config.fee,
                slippageBps: config.slippageBps
            )
            await pollBacktestStatus(commandId: cmd.commandId)
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    func startDryrun(config: RunConfig) async {
        submittedConfig = config
        phase = .running
        errorMessage = nil
        do {
            let api = APIDryrunV2(client: networkClient)
            _ = try await api.startDryrun([
                "strategy_id": config.strategyId,
                "symbols": config.symbols,
                "stake_amount": config.stakeAmount ?? 100,
                "max_open_trades": config.maxOpenTrades ?? 5,
                "initial_wallet": config.initialWallet ?? 10000,
            ])
            // Dryrun is long-lived; poll status briefly to confirm start, then leave running.
            phase = .completed
            await loadRunHistory()
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    func stopDryrun(id: Int) async {
        do {
            _ = try await APIDryrunV2(client: networkClient).stopDryrun(String(id))
            await loadRunHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollBacktestStatus(commandId: String) async {
        pollTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            let api = APIBacktestV2(client: self.networkClient)
            for _ in 0..<450 { // 15 min, 2s interval
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                do {
                    let status = try await api.backtestStatusV2(commandId: commandId)
                    if status.commandStatus == "completed", let run = status.backtestRun {
                        self.currentBacktestRun = run
                        self.phase = .completed
                        await self.loadRunHistory()
                        await self.loadReadinessAndClusters()
                        return
                    }
                    if status.commandStatus == "failed" {
                        self.phase = .failed
                        self.errorMessage = status.errorMessage ?? "Backtest failed"
                        return
                    }
                } catch {
                    // transient; continue polling
                }
            }
            self.phase = .failed
            self.errorMessage = "Backtest timed out"
        }
        pollTask = task
    }

    func selectBacktestRun(_ run: BacktestRunV2) {
        currentBacktestRun = run
        phase = .completed
        Task { await loadReadinessAndClusters() }
    }

    func toggleCompare(_ runId: Int) {
        if comparedBacktestIds.contains(runId) {
            comparedBacktestIds.remove(runId)
            comparedRuns.removeAll { $0.id == runId }
        } else {
            if comparedBacktestIds.count >= 3 {
                let oldest = comparedBacktestIds.first!
                comparedBacktestIds.remove(oldest)
                comparedRuns.removeAll { $0.id == oldest }
            }
            comparedBacktestIds.insert(runId)
            Task {
                if let run = try? await APIBacktestV2(client: networkClient).getBacktestV2(id: runId) {
                    comparedRuns.append(run)
                }
            }
        }
    }

    func newRun() {
        phase = .idle
        currentBacktestRun = nil
        submittedConfig = nil
        errorMessage = nil
    }

    private func loadReadinessAndClusters() async {
        guard let strategy = selectedStrategy else { return }
        do {
            let snap = try await APIStrategyWorkspace(client: networkClient).getWorkspaceSnapshot(strategyId: strategy.id)
            readiness = snap.readiness
        } catch { readiness = nil }
        do {
            strategyFailureClusters = try await APIFailureClusters(client: networkClient).getFailureClusters(strategyUuid: strategy.uuid)
        } catch { strategyFailureClusters = [] }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete. If `APIStrategiesV2`/`APIStrategyWorkspace`/`APIFailureClusters` method signatures differ, adjust call sites to match the actual signatures in those files (check `Services/APIStrategiesV2.swift`, `APIStrategyWorkspace.swift`, `APIFailureClusters.swift`).

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift
git commit -m "refactor(macos): rewrite BacktestLabViewModel — tabs, submittedConfig, real dryrun"
```

---

## Task 8: macOS — Rewrite BacktestLabView (three-column container)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift` (rewrite)
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/LeftRail/RunRailView.swift`

**Interfaces:**
- Consumes: `BacktestLabViewModel` (Task 7), `SectionCard`, design tokens
- Produces: three-column layout with responsive collapse; delegates to child block views (Tasks 9-11)

- [ ] **Step 1: Rewrite BacktestLabView**

```swift
// BacktestLabView.swift — Three-column linked-flow backtest/dryrun lab.

import SwiftUI

struct BacktestLabView: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RunRailView()
                .frame(width: 240)
                .background(colors.surface.opacity(0.3))

            centerColumn
                .frame(maxWidth: .infinity)

            ContextRailView()
                .frame(width: 280)
                .background(colors.surface.opacity(0.3))
        }
        .background(colors.background.ignoresSafeArea())
        .task { await vm.loadInitial() }
    }

    private var centerColumn: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    ConfigPanel()
                    if vm.phase == .completed || vm.phase == .failed {
                        StatusSummaryBlock()
                    }
                    if vm.phase == .completed {
                        EquityCurveBlock()
                        TradeListBlock()
                        if vm.comparedBacktestIds.count >= 2 {
                            CompareBlock()
                        }
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(RunTab.allCases) { tab in
                let isActive = vm.activeTab == tab
                Button {
                    vm.switchTab(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .backtest ? "clock.arrow.circlepath" : "play.circle")
                        Text(tab == .backtest ? L10n.Backtest.backtestTab : L10n.Backtest.dryrunTab)
                    }
                    .font(PulseFonts.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? PulseColors.accent : colors.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }
}
```

- [ ] **Step 2: Create RunRailView**

```swift
// RunRailView.swift — Left rail: run history + compare selection + new run.

import SwiftUI

struct RunRailView: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 0) {
            newRunButton
            Divider().background(colors.border)
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    if vm.activeTab == .backtest {
                        backtestList
                    } else {
                        dryrunList
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
    }

    private var newRunButton: some View {
        Button {
            vm.newRun()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text(L10n.Backtest.RunRail.newRun)
            }
            .font(PulseFonts.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .padding(PulseSpacing.md)
    }

    private var backtestList: some View {
        ForEach(vm.backtestRuns) { run in
            runRow(run)
        }
    }

    private func runRow(_ run: BacktestRunV2) -> some View {
        let isSelected = vm.currentBacktestRun?.id == run.id
        let isCompared = vm.comparedBacktestIds.contains(run.id)
        return HStack(spacing: 8) {
            Image(systemName: isCompared ? "checkmark.square.fill" : "square")
                .foregroundStyle(isCompared ? PulseColors.accent : colors.textMuted)
                .onTapGesture { vm.toggleCompare(run.id) }
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(run.id)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                Text(String(format: "%+.1f%%", run.totalReturn * 100))
                    .font(PulseFonts.caption)
                    .foregroundStyle(run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            }
            Spacer()
            if isSelected {
                Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(isSelected ? colors.surface.opacity(0.5) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .contentShape(Rectangle())
        .onTapGesture { vm.selectBacktestRun(run) }
    }

    private var dryrunList: some View {
        // Dryrun rows: status dot + open trades + profit; no compare checkbox.
        ForEach(vm.dryrunRuns) { run in
            HStack(spacing: 8) {
                Circle()
                    .fill(dryrunStatusColor(run.status))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(run.id)").font(PulseFonts.monoLabel).foregroundStyle(colors.textPrimary)
                    Text("\(run.openTrades) open · \(String(format: "%+.2f", run.totalProfit))")
                        .font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
                }
                Spacer()
                if run.status == "running" {
                    Button(L10n.Backtest.RunRail.stop) {
                        Task { await vm.stopDryrun(id: run.id) }
                    }
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.danger)
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
    }

    private func dryrunStatusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.success
        case "failed": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}
```

- [ ] **Step 3: Create a ContextRailView placeholder (filled in Task 11)**

For the build to pass, create a minimal `ContextRailView` in `Views/BacktestAndDryrun/RightRail/ContextRailView.swift`:

```swift
import SwiftUI

struct ContextRailView: View {
    var body: some View {
        VStack {
            Text("Context Rail")
        }
    }
}
```

- [ ] **Step 4: Add the L10n keys used**

In `macos-app/AlphaLoop/Localization/L10n+Backtest.swift`, ensure these keys exist (add if missing):

```swift
extension L10n.Backtest {
    static var backtestTab: String { zh("回测", en: "Backtest") }
    static var dryrunTab: String { zh("模拟", en: "Dryrun") }
}

extension L10n.Backtest.RunRail {
    static var newRun: String { zh("新建运行", en: "New Run") }
    static var stop: String { zh("停止", en: "Stop") }
}
```

- [ ] **Step 5: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete. Stub `ContextRailView` lets it compile; Tasks 9-11 fill in the blocks.

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/LeftRail/RunRailView.swift macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/ContextRailView.swift macos-app/AlphaLoop/Localization/L10n+Backtest.swift
git commit -m "feat(macos): rewrite BacktestLabView as three-column container + RunRailView"
```

---

## Task 9: macOS — Center column blocks (Config, StatusSummary, EquityCurve, TradeList, Compare)

**Files:**
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/ConfigPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/StatusSummaryBlock.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/EquityCurveBlock.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/TradeListBlock.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/CompareBlock.swift`

**Interfaces:**
- Consumes: `BacktestLabViewModel`, `SectionCard`, `RunFailureClustering`, `RiskWarningRules`, design tokens
- Produces: the four center narrative blocks + inline config panel.

- [ ] **Step 1: ConfigPanel.swift**

```swift
// ConfigPanel.swift — Inline run configuration (replaces NewRunSheet).

import SwiftUI

struct ConfigPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    @State private var symbols: Set<String> = []
    @State private var timeframe: String = "5m"
    @State private var initialCapital: Double = 10000
    @State private var fee: Double = 0.001
    @State private var slippageBps: Double = 5
    @State private var startDate: Date = .now.addingTimeInterval(-86400 * 30)
    @State private var endDate: Date = .now
    @State private var stakeAmount: Double = 100
    @State private var maxOpenTrades: Int = 5
    @State private var initialWallet: Double = 10000

    private var isReadonly: Bool { vm.phase == .running }

    var body: some View {
        SectionCard(title: L10n.Backtest.Config.title, locked: isReadonly) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                strategyPicker
                symbolChips
                timeframePicker
                if vm.activeTab == .backtest { dateRangePicker }
                if vm.activeTab == .dryrun { dryrunFields }
                capitalFeeSlippage
                runButton
            }
        }
    }

    private var strategyPicker: some View {
        HStack {
            Text(L10n.Backtest.Config.strategy).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            Picker("", selection: Binding(get: { vm.selectedStrategy }, set: { new in
                if let new { vm.selectedStrategy = new; Task { await vm.loadTradableSymbols(for: new) } }
            })) {
                ForEach(vm.availableStrategies) { s in
                    Text(s.name).tag(s as StrategyV2?)
                }
            }
            .disabled(isReadonly)
        }
    }

    private var symbolChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(vm.tradableSymbols, id: \.self) { sym in
                let selected = symbols.contains(sym)
                Button { if !isReadonly { symbols.insert(sym) } } label: {
                    Text(sym)
                        .font(PulseFonts.micro)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(selected ? PulseColors.accent.opacity(0.3) : colors.surface.opacity(0.3))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeframePicker: some View {
        HStack {
            Text(L10n.Backtest.Config.timeframe).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            Picker("", selection: $timeframe) {
                ForEach(["5m", "15m", "1h", "4h"], id: \.self) { Text($0).tag($0) }
            }.disabled(isReadonly)
        }
    }

    private var dateRangePicker: some View {
        HStack {
            DatePicker(L10n.Backtest.Config.start, selection: $startDate, displayedComponents: .date).disabled(isReadonly)
            DatePicker(L10n.Backtest.Config.end, selection: $endDate, displayedComponents: .date).disabled(isReadonly)
        }
    }

    private var dryrunFields: some View {
        HStack {
            DoubleField(L10n.Backtest.Config.stake, value: $stakeAmount)
            IntField(L10n.Backtest.Config.maxOpen, value: $maxOpenTrades)
            DoubleField(L10n.Backtest.Config.wallet, value: $initialWallet)
        }
    }

    private var capitalFeeSlippage: some View {
        HStack {
            DoubleField(L10n.Backtest.Config.capital, value: $initialCapital)
            Picker(L10n.Backtest.Config.fee, selection: $fee) {
                Text("0.05%").tag(0.0005); Text("0.1%").tag(0.001); Text("0.2%").tag(0.002)
            }
            Picker(L10n.Backtest.Config.slippage, selection: $slippageBps) {
                Text("0 bps").tag(0.0); Text("5 bps").tag(5.0); Text("10 bps").tag(10.0)
            }
        }.disabled(isReadonly)
    }

    private var runButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if vm.phase == .running { ProgressView().controlSize(.small) }
                Text(vm.phase == .running ? L10n.Backtest.Phase.running : L10n.Backtest.Config.run)
            }
            .font(PulseFonts.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .disabled(isReadonly || vm.selectedStrategy == nil || symbols.isEmpty)
    }

    private func submit() async {
        guard let strategy = vm.selectedStrategy else { return }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        var config = RunConfig(
            strategyId: strategy.id, strategyUuid: strategy.uuid,
            symbols: Array(symbols), timeframe: timeframe,
            initialCapital: initialCapital, fee: fee, slippageBps: slippageBps,
            startDate: nil, endDate: nil, stakeAmount: nil, maxOpenTrades: nil, initialWallet: nil
        )
        if vm.activeTab == .backtest {
            config.startDate = fmt.string(from: startDate)
            config.endDate = fmt.string(from: endDate)
            await vm.startBacktest(config: config)
        } else {
            config.stakeAmount = stakeAmount
            config.maxOpenTrades = maxOpenTrades
            config.initialWallet = initialWallet
            await vm.startDryrun(config: config)
        }
    }
}
```

Note: `FlowLayout`, `DoubleField`, `IntField` are small helpers — if they don't exist, use `HStack` with `TextField` and `Double` parsing instead. Check `DesignSystem/` for existing helpers first.

- [ ] **Step 2: StatusSummaryBlock.swift**

```swift
// StatusSummaryBlock.swift — Status + summary metrics (with vs-last delta).

import SwiftUI

struct StatusSummaryBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.Backtest.Result.summary, dataNote: dataNote) {
            HStack(spacing: PulseSpacing.md) {
                statusCard
                summaryCard
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun else { return "" }
        return "\(run.totalTrades) trades"
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Circle().fill(vm.phase == .failed ? PulseColors.danger : PulseColors.success).frame(width: 8, height: 8)
                Text(vm.phase == .failed ? L10n.Backtest.Phase.failed : L10n.Backtest.Phase.completed)
                    .font(PulseFonts.caption.weight(.semibold))
            }
            if vm.phase == .failed, let err = vm.errorMessage {
                Text(err).font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        HStack(spacing: PulseSpacing.lg) {
            metric(L10n.Backtest.Result.return, value: runValue(\.totalReturn), fmt: "%+.2f%%")
            metric(L10n.Backtest.Result.maxDD, value: runValue(\.maxDrawdown), fmt: "%.2f%%")
            metric(L10n.Backtest.Result.winRate, value: runValue(\.winRate), fmt: "%.1f%%")
            metric(L10n.Backtest.Result.profitFactor, value: runValue(\.profitFactor), fmt: "%.2f")
        }
    }

    private func runValue(_ keyPath: KeyPath<BacktestRunV2, Double>) -> Double {
        vm.currentBacktestRun?[keyPath: keyPath] ?? 0
    }

    private func metric(_ label: String, value: Double, fmt: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
            Text(String(format: fmt, value * (label.contains("%") && label != L10n.Backtest.Result.profitFactor ? 100 : 1)))
                .font(PulseFonts.body.weight(.semibold)).foregroundStyle(colors.textPrimary)
        }
    }
}
```

(The metric formatting above is simplified; refine per metric — return/maxDD/winRate are percentages, profitFactor is a ratio. Adjust the multiplier logic so return shows as `+8.30%`, profitFactor as `1.60`.)

- [ ] **Step 3: EquityCurveBlock.swift**

```swift
// EquityCurveBlock.swift — Equity curve + drawdown chart.

import SwiftUI
import Charts

struct EquityCurveBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.Backtest.Result.equityCurve, dataNote: dataNote) {
            if let run = vm.currentBacktestRun, !run.equityCurve.isEmpty {
                VStack(spacing: PulseSpacing.sm) {
                    Chart(run.equityCurve) { p in
                        LineMark(x: .value("Time", p.timestamp), y: .value("Equity", p.equity))
                            .foregroundStyle(PulseColors.accent)
                        AreaMark(x: .value("Time", p.timestamp), y: .value("Equity", p.equity))
                            .foregroundStyle(PulseColors.accent.opacity(0.2))
                    }
                    .frame(height: 180)

                    Chart(run.equityCurve) { p in
                        BarMark(x: .value("Time", p.timestamp), y: .value("DD", p.drawdown))
                            .foregroundStyle(PulseColors.danger.opacity(0.5))
                    }
                    .frame(height: 80)
                }
            } else {
                Text(L10n.Backtest.Result.noCurveData)
                    .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun, !run.equityCurve.isEmpty else { return "" }
        return "\(run.equityCurve.count) points"
    }
}
```

- [ ] **Step 4: TradeListBlock.swift**

```swift
// TradeListBlock.swift — Trade table + run-level failure clustering.

import SwiftUI

struct TradeListBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.Backtest.Result.trades, dataNote: dataNote) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                if let run = vm.currentBacktestRun, !run.trades.isEmpty {
                    tradeTable(run.trades)
                    runLevelClusters(run.trades)
                } else {
                    Text(L10n.Backtest.Result.noTrades)
                        .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun else { return "" }
        return "\(run.totalTrades) trades"
    }

    private func tradeTable(_ trades: [TradeRow]) -> some View {
        Table(trades) {
            TableColumn(L10n.Backtest.Result.colOpen) { Text($0.openTime) }
            TableColumn(L10n.Backtest.Result.colPair) { Text($0.pair) }
            TableColumn(L10n.Backtest.Result.colSide) { Text($0.side) }
            TableColumn(L10n.Backtest.Result.colOpenPrice) { Text(String(format: "%.2f", $0.openPrice)) }
            TableColumn(L10n.Backtest.Result.colClosePrice) { Text(String(format: "%.2f", $0.closePrice)) }
            TableColumn(L10n.Backtest.Result.colProfit) { t in
                Text(String(format: "%+.2f", t.profit))
                    .foregroundStyle(t.profit >= 0 ? PulseColors.success : PulseColors.danger)
            }
            TableColumn(L10n.Backtest.Result.colDuration) { Text($0.duration) }
        }
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private func runLevelClusters(_ trades: [TradeRow]) -> some View {
        let clusters = RunFailureClustering.clusterFailures(in: trades)
        if !clusters.isEmpty {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(L10n.Backtest.Result.failureClusters).font(PulseFonts.caption.weight(.semibold))
                ForEach(clusters) { c in
                    HStack {
                        Text(c.label).font(PulseFonts.micro)
                        Spacer()
                        Text("\(c.sampleSize) · \(String(format: "%.2f", c.totalLoss))")
                            .font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 5: CompareBlock.swift**

```swift
// CompareBlock.swift — KPI matrix + equity overlay for compared runs.

import SwiftUI
import Charts

struct CompareBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.Backtest.Result.compare, dataNote: "\(vm.comparedRuns.count) runs") {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                kpiMatrix
                overlayChart
            }
        }
    }

    private var kpiMatrix: some View {
        let rows = vm.comparedRuns
        return Grid {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(rows) { r in Text("#\(r.id)").font(PulseFonts.micro) }
            }
            GridRow {
                Text(L10n.Backtest.Result.return).font(PulseFonts.micro)
                ForEach(rows) { r in Text(String(format: "%+.1f%%", r.totalReturn * 100)).font(PulseFonts.micro) }
            }
            GridRow {
                Text(L10n.Backtest.Result.maxDD).font(PulseFonts.micro)
                ForEach(rows) { r in Text(String(format: "%.1f%%", r.maxDrawdown * 100)).font(PulseFonts.micro) }
            }
            GridRow {
                Text(L10n.Backtest.Result.winRate).font(PulseFonts.micro)
                ForEach(rows) { r in Text(String(format: "%.0f%%", r.winRate * 100)).font(PulseFonts.micro) }
            }
            GridRow {
                Text(L10n.Backtest.Result.profitFactor).font(PulseFonts.micro)
                ForEach(rows) { r in Text(String(format: "%.2f", r.profitFactor)).font(PulseFonts.micro) }
            }
        }
    }

    private var overlayChart: some View {
        let colors: [Color] = [PulseColors.accent, PulseColors.cyan, PulseColors.purple]
        return Chart {
            ForEach(Array(vm.comparedRuns.enumerated()), id: \.element.id) { idx, run in
                ForEach(run.equityCurve) { p in
                    LineMark(x: .value("Time", p.timestamp), y: .value("Equity", p.equity))
                        .foregroundStyle(colors[idx % colors.count])
                }
            }
        }
        .frame(height: 160)
    }
}
```

- [ ] **Step 6: Add all new L10n keys**

In `L10n+Backtest.swift`, add the keys referenced above (`L10n.Backtest.Config.*`, `L10n.Backtest.Result.*`, `L10n.Backtest.Phase.*`). Use the zh/en pattern. Examples:

```swift
extension L10n.Backtest.Config {
    static var title: String { zh("配置", en: "Configuration") }
    static var strategy: String { zh("策略", en: "Strategy") }
    static var timeframe: String { zh("周期", en: "Timeframe") }
    static var start: String { zh("开始", en: "Start") }
    static var end: String { zh("结束", en: "End") }
    static var stake: String { zh("单笔", en: "Stake") }
    static var maxOpen: String { zh("最大持仓", en: "Max Open") }
    static var wallet: String { zh("初始钱包", en: "Wallet") }
    static var capital: String { zh("初始资金", en: "Capital") }
    static var fee: String { zh("手续费", en: "Fee") }
    static var slippage: String { zh("滑点", en: "Slippage") }
    static var run: String { zh("运行", en: "Run") }
}

extension L10n.Backtest.Result {
    static var summary: String { zh("摘要", en: "Summary") }
    static var equityCurve: String { zh("权益曲线", en: "Equity Curve") }
    static var trades: String { zh("交易列表", en: "Trades") }
    static var compare: String { zh("对比", en: "Compare") }
    static var return_: String { zh("收益", en: "Return") }  // `return` is reserved
    static var maxDD: String { zh("最大回撤", en: "Max Drawdown") }
    static var winRate: String { zh("胜率", en: "Win Rate") }
    static var profitFactor: String { zh("盈亏比", en: "Profit Factor") }
    static var noCurveData: String { zh("本次运行未产出曲线数据", en: "No curve data for this run") }
    static var noTrades: String { zh("本次运行无交易", en: "No trades in this run") }
    static var failureClusters: String { zh("失败聚类", en: "Failure Clusters") }
    static var colOpen: String { zh("开仓", en: "Open") }
    static var colPair: String { zh("交易对", en: "Pair") }
    static var colSide: String { zh("方向", en: "Side") }
    static var colOpenPrice: String { zh("开仓价", en: "Open Price") }
    static var colClosePrice: String { zh("平仓价", en: "Close Price") }
    static var colProfit: String { zh("盈亏", en: "P&L") }
    static var colDuration: String { zh("持仓", en: "Duration") }
}

extension L10n.Backtest.Phase {
    static var running: String { zh("运行中", en: "Running") }
    static var completed: String { zh("已完成", en: "Completed") }
    static var failed: String { zh("失败", en: "Failed") }
}
```

Note: `return` is a Swift keyword, so the L10n key must be `return_` or similar; update references in `StatusSummaryBlock` and `CompareBlock` to use `L10n.Backtest.Result.return_`.

- [ ] **Step 7: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete. Fix any missing helper types (`FlowLayout`, `DoubleField`, `IntField`) by either using existing design-system helpers or replacing with plain `TextField` + value parsing.

- [ ] **Step 8: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/Center/ macos-app/AlphaLoop/Localization/L10n+Backtest.swift
git commit -m "feat(macos): center column blocks — config, status/summary, equity, trades, compare"
```

---

## Task 10: macOS — Right Context Rail (StrategyMeta, RiskWarnings, Promotion)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/ContextRailView.swift` (replace stub)
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/StrategyMetaPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/RiskWarningsPanel.swift`
- Create: `macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/PromotionPanel.swift` (rewrite)

**Interfaces:**
- Consumes: `BacktestLabViewModel` (`readiness`, `strategyFailureClusters`, `currentBacktestRun`, `selectedStrategy`), `RiskWarningRules`
- Produces: three stacked panels always visible in the right rail.

- [ ] **Step 1: Replace ContextRailView stub**

```swift
// ContextRailView.swift — Right rail: strategy meta + risk + promotion (always visible).

import SwiftUI

struct ContextRailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.lg) {
                StrategyMetaPanel()
                RiskWarningsPanel()
                PromotionPanel()
            }
            .padding(PulseSpacing.lg)
        }
    }
}
```

- [ ] **Step 2: StrategyMetaPanel.swift**

```swift
// StrategyMetaPanel.swift — Strategy name, DSL hash, data source.

import SwiftUI

struct StrategyMetaPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.Backtest.Context.strategyMeta).font(PulseFonts.caption.weight(.semibold))
            if let s = vm.selectedStrategy {
                metaRow(L10n.Backtest.Context.strategy, value: s.name)
                metaRow(L10n.Backtest.Context.version, value: s.version ?? "—")
                metaRow(L10n.Backtest.Context.dslHash, value: String((s.dslHash ?? "—").prefix(8)))
                metaRow(L10n.Backtest.Context.mode, value: vm.activeTab == .backtest ? L10n.Backtest.backtestTab : L10n.Backtest.dryrunTab)
            }
            if let run = vm.currentBacktestRun {
                metaRow(L10n.Backtest.Context.engine, value: "Freqtrade")
                if let dur = run.completedAt { metaRow(L10n.Backtest.Context.execTime, value: dur) }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
            Spacer()
            Text(value).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
        }
    }
}
```

- [ ] **Step 3: RiskWarningsPanel.swift**

```swift
// RiskWarningsPanel.swift — Risk warnings (always visible) + strategy-level clusters.

import SwiftUI

struct RiskWarningsPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.Backtest.Context.risk).font(PulseFonts.caption.weight(.semibold))
            let warnings = computeWarnings()
            if warnings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(PulseColors.success)
                    Text(L10n.Backtest.Context.noRisk).font(PulseFonts.micro).foregroundStyle(PulseColors.success)
                }
            } else {
                ForEach(warnings) { w in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PulseColors.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.message).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
                            if w.smallSample {
                                Text(L10n.Backtest.Context.smallSample).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                            }
                        }
                    }
                }
            }
            // Strategy-level clusters
            if !vm.strategyFailureClusters.isEmpty {
                Divider().background(colors.border)
                Text(L10n.Backtest.Context.strategyClusters).font(PulseFonts.caption.weight(.semibold))
                ForEach(vm.strategyFailureClusters) { c in
                    HStack {
                        Text(c.label).font(PulseFonts.micro)
                        Spacer()
                        Text("\(c.sampleSize) · \(String(format: "%.2f", c.totalLoss))")
                            .font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }

    private func computeWarnings() -> [RiskWarning] {
        guard let run = vm.currentBacktestRun else { return [] }
        let metrics = BacktestMetrics(
            totalReturn: run.totalReturn, sharpeRatio: run.sharpeRatio,
            maxDrawdown: run.maxDrawdown, winRate: run.winRate,
            profitFactor: run.profitFactor, totalTrades: run.totalTrades,
            avgTradeDuration: "", bestTrade: 0, worstTrade: 0
        )
        let warnings = RiskWarningRules.riskWarnings(for: metrics)
        // Annotate small-sample warnings
        return warnings.map { w in
            var nw = w
            if w.id.contains("trades") && run.totalTrades < 30 { nw.smallSample = true }
            return nw
        }
    }
}

private struct RiskWarning: Identifiable {
    let id: String
    let message: String
    var smallSample: Bool = false
}
```

Note: `RiskWarningRules.riskWarnings(for:)` currently returns its own type — adapt the mapping. Check `Shared/RiskWarningRules.swift` for the actual return type and field names; the `RiskWarning` struct above may need to match it.

- [ ] **Step 4: PromotionPanel.swift (rewrite)**

```swift
// PromotionPanel.swift — Live-trading readiness gate (judgment + navigation only).

import SwiftUI

struct PromotionPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.Backtest.Context.promotion).font(PulseFonts.caption.weight(.semibold))
            if let readiness = vm.readiness {
                HStack {
                    Circle().fill(readiness.grandStatus == "ready" ? PulseColors.success : PulseColors.amber).frame(width: 8, height: 8)
                    Text(readiness.grandStatus == "ready" ? L10n.Backtest.Context.ready : L10n.Backtest.Context.notReady)
                        .font(PulseFonts.micro.weight(.semibold))
                }
                ForEach(readiness.gates, id: \.name) { gate in
                    HStack {
                        Image(systemName: gate.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(gate.passed ? PulseColors.success : PulseColors.danger)
                        Text(gate.name).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
                    }
                }
                Button {
                    appState.selectedRoute = .liveReadiness
                } label: {
                    Text(L10n.Backtest.Context.goLive)
                        .font(PulseFonts.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(readiness.grandStatus == "ready" ? PulseColors.accent : colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
                .buttonStyle(.plain)
                .disabled(readiness.grandStatus != "ready")
            } else {
                Text(L10n.Backtest.Context.noReadiness).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }
}
```

Note: `PerStrategyReadiness.gates` field name/type — verify in `Models/BacktestTypes.swift` (or `Types.swift` if not yet moved). Adjust the `ForEach` to match the actual gate type.

- [ ] **Step 5: Add Context L10n keys**

```swift
extension L10n.Backtest.Context {
    static var strategyMeta: String { zh("策略信息", en: "Strategy") }
    static var strategy: String { zh("策略", en: "Strategy") }
    static var version: String { zh("版本", en: "Version") }
    static var dslHash: String { zh("DSL 哈希", en: "DSL Hash") }
    static var mode: String { zh("模式", en: "Mode") }
    static var engine: String { zh("引擎", en: "Engine") }
    static var execTime: String { zh("完成时间", en: "Completed") }
    static var risk: String { zh("风险警告", en: "Risk Warnings") }
    static var noRisk: String { zh("未触发风险阈值", en: "No risk thresholds triggered") }
    static var smallSample: String { zh("样本不足，结论谨慎", en: "Small sample, treat cautiously") }
    static var strategyClusters: String { zh("策略级失败聚类", en: "Strategy-level Clusters") }
    static var promotion: String { zh("晋级实盘", en: "Live Promotion") }
    static var ready: String { zh("已就绪", en: "Ready") }
    static var notReady: String { zh("未就绪", en: "Not Ready") }
    static var goLive: String { zh("前往实盘准备", en: "Go to Live Readiness") }
    static var noReadiness: String { zh("无就绪数据", en: "No readiness data") }
}
```

- [ ] **Step 6: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete.

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/Views/BacktestAndDryrun/RightRail/ macos-app/AlphaLoop/Localization/L10n+Backtest.swift
git commit -m "feat(macos): right context rail — strategy meta, risk warnings, promotion"
```

---

## Task 11: macOS — Delete old section files + NewRunSheet, wire environment

**Files:**
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ConfigPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/StatusPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/SummaryPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift`
- Delete: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift`
- Keep: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Shared/SectionCard.swift`
- Keep: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Shared/RiskWarningRules.swift`
- Keep: `macos-app/AlphaLoop/Views/BacktestAndDryrun/Shared/RunFailureClustering.swift`
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift` (or wherever `BacktestLabViewModel` is instantiated) — ensure `.environment(BacktestLabViewModel())` is injected

**Interfaces:**
- Produces: clean directory tree; `BacktestLabView` injects its own ViewModel.

- [ ] **Step 1: Delete the old files**

```bash
cd macos-app
git rm AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/ConfigPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/StatusPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/SummaryPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/CurvePanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/TradeListPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/ComparePanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/RiskPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/PromotionPanel.swift
git rm AlphaLoop/Views/BacktestAndDryrun/Sections/DataSourceFooter.swift
```

If `SectionCard.swift` / `RiskWarningRules.swift` / `RunFailureClustering.swift` are currently inside `Sections/`, move them to `Shared/` (or keep in place if `Shared/` doesn't exist — but the plan's file structure says `Shared/`). Use `git mv` if relocating.

- [ ] **Step 2: Ensure ViewModel environment injection**

Find where `BacktestLabView` is rendered (likely `Views/AppShell/AppShellView.swift` or `Views/AppShell/TradingConsoleRootView.swift`). Add the ViewModel to the environment:

```swift
BacktestLabView()
    .environment(BacktestLabViewModel())
```

If the old code instantiated the ViewModel with a mock-client parameter, remove that — the new ViewModel takes no init parameters and reads `@Environment(\.networkClient)`.

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete. Fix any remaining references to deleted types (`NewRunSheet`, old section panels).

- [ ] **Step 4: Commit**

```bash
git add -A macos-app/AlphaLoop/Views/BacktestAndDryrun/
git commit -m "refactor(macos): delete NewRunSheet + old 9-section panels; wire ViewModel env"
```

---

## Task 12: macOS — L10n cleanup + remove old keys

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Backtest.swift`

- [ ] **Step 1: Remove obsolete keys**

Delete any L10n keys that referenced `NewRunSheet` or the old 9-section structure (`StatusPanel.*`, `SummaryPanel.*`, `CurvePanel.*`, `TradeListPanel.*`, `ComparePanel.*`, `RiskPanel.*`, `PromotionPanel.*`, `DataSourceFooter.*`, `NewRunSheet.*`). Keep only the new structure: `Config`, `RunRail`, `Result`, `Context`, `Phase`, plus the tab keys.

- [ ] **Step 2: Build to verify no missing-key references**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: Build complete. If a view references a deleted key, either re-add it under the new naming or update the view.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Backtest.swift
git commit -m "refactor(macos): prune obsolete Backtest L10n keys"
```

---

## Task 13: Docs — Update user guide + run full verification

**Files:**
- Modify: `docs/user-guide/content/zh/backtest-lab.html`
- Modify: `docs/user-guide/content/en/backtest-lab.html`

- [ ] **Step 1: Update user guide content**

Rewrite both zh and en `backtest-lab.html` to describe the new three-column layout: left Run Rail (history + compare), center (tab switch + inline config + phase-driven results), right (always-visible strategy meta / risk warnings / promotion). Remove references to the old NewRunSheet modal and 9-section flow. Ensure cross-links use `href="#/<path>"`.

- [ ] **Step 2: Run backend full test suite**

Run: `cd backend && .venv/bin/python -m pytest tests/ -q --cov=app`
Expected: 1246+ passed; 17 pre-existing failures unchanged; coverage >= 30%.

- [ ] **Step 3: Run macOS build + tests**

Run: `cd macos-app && swift build && swift test`
Expected: Build complete; tests pass.

- [ ] **Step 4: Live-mode walkthrough (manual)**

Start the stack: `cd /Users/novspace/workspace/phosphor-terminal && docker compose up -d --wait && cd macos-app && swift run AlphaLoop --live`.
Walk through:
1. Sidebar → Backtest & Simulation.
2. Select a real strategy in Config panel.
3. Pick 1-2 symbols, set date range, click Run.
4. Watch status poll → completed.
5. Verify equity curve + trades render real data (not empty, not mock).
6. Verify right rail risk warnings compute from real metrics.
7. Verify promotion CTA reflects readiness.
8. Switch to Dryrun tab; start a dryrun; verify it appears in Run Rail with running status.
9. In Run Rail, check 2 backtest runs → ComparePanel appears with overlay chart.
Expected: All real data, no empty/mock fallbacks when a run genuinely has data.

- [ ] **Step 5: Commit docs**

```bash
git add docs/user-guide/content/zh/backtest-lab.html docs/user-guide/content/en/backtest-lab.html
git commit -m "docs: update backtest-lab user guide for three-column layout"
```

---

## Self-Review

**Spec coverage:**
- Strategy/pair/timeframe/date/capital/fee/slippage config → Task 9 ConfigPanel ✓
- Execution mode: explicitly dropped (spec non-goal) ✓
- Backtest + dryrun run status → Task 9 StatusSummaryBlock + Task 8 RunRailView ✓
- Return summary, max DD, win rate, profit factor → Task 9 StatusSummaryBlock ✓
- Equity curve + drawdown → Task 9 EquityCurveBlock ✓
- Trade list → Task 9 TradeListBlock ✓
- Failure clustering (run + strategy) → Task 9 (run-level) + Task 10 (strategy-level) ✓
- Historical compare → Task 9 CompareBlock + Task 8 RunRailView checkboxes ✓
- Promotion gate → Task 10 PromotionPanel ✓
- Risk warnings → Task 10 RiskWarningsPanel ✓
- Data source → Task 10 StrategyMetaPanel ✓
- Real backend data only → Tasks 1-2 (persistence fix) + honest empty states in blocks ✓
- No fake performance data → Task 6 (honest mocks) + Task 9 (empty states) ✓
- Backend API/L10n/docs/acceptance → Tasks 1-3 (backend), Tasks 4-12 (L10n), Task 13 (docs + verification) ✓

**Placeholder scan:** No TBD/TODO. All code blocks are complete. Helper-type uncertainties (`FlowLayout`, `PerStrategyReadiness.gates`, `RiskWarningRules` return type) are flagged inline with "check existing / adapt" instructions — not placeholders, but adaptation points where the implementer must verify against current code.

**Type consistency:** `RunConfig`, `RunTab`, `BacktestLabViewModel` fields/ methods referenced in Tasks 8-11 match the definitions in Task 7. `BacktestRunV2`/`TradeRow`/`BacktestEquityPoint` fields match Task 4's extraction. `DryRunRunV2` matches Task 5. `MockBacktest` factory names match Task 6's usage in Task 7's API layer.
