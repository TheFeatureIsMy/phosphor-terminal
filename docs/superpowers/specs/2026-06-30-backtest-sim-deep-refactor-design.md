---
title: Backtest/Sim Deep Refactor — Three-Column Linked-Flow Design
date: 2026-06-30
status: draft
supersedes: 2026-06-22-backtest-sim-refactor-design.md
---

# Backtest/Sim Deep Refactor — Three-Column Linked-Flow Design

## Context & Motivation

The current BacktestLab page (`Views/BacktestAndDryrun/`) stacks 9 section panels in a VStack with a left Run Rail. Audit surfaced structural problems:

- **Broken data pipeline**: `backtest_handler._handle_success` discards `result.trades` and `result.equity_curve`, writing only `metrics` into `BacktestRun.result`. The `BacktestRunResponse` `model_validator` extracts trades/equity_curve from `result` — so the API returns empty lists for real runs. The UI has been compensating with mock data.
- **Mock-by-default ViewModel**: `BacktestLabViewModel` defaults to `MockNetworkClient`, generating fake `BacktestRunV2` with 2-point equity curves. `startDryrun()` throws 501 — dry-run is dead UX.
- **Config/readback tangle**: `ConfigPanel` reads from `selectedRun` (fetched post-completion) instead of the submitted config, so users can't see what they configured while a run is in flight.
- **Link visibility**: Risk warnings and promotion CTA sit at the bottom of a long scroll. The "config → result → risk → promotion" chain is not visually anchored.
- **Hardcoded symbols**: `NewRunSheet` bakes in 8 crypto pairs with a comment admitting the strategy doesn't expose symbols.
- **Code cruft**: `Types.swift` is 1279 lines; deprecated v1 `APIBacktest.swift` lingers; mock factories scattered across 4 files; two different section-locking mechanisms coexist.

This refactor rebuilds the page around a **three-column linked-flow** layout that keeps the chain's endpoints (risk + promotion) always visible, fixes the backend persistence gap so all results are real, and removes the mock crutch.

## Goals

1. **Real data only**: every rendered metric/equity point/trade comes from a real backend run. No client-side performance fabrication. Honest empty states when data is absent.
2. **Linked flow visibility**: the chain "run params → result → risk → promotion eligibility" must be visually traceable end-to-end, with risk and promotion always reachable.
3. **Unified backtest + dryrun**: one page, two tabs, sharing strategy/symbol selection, with mode-specific fields and Run Rail behavior.
4. **Architectural cleanup**: split `Types.swift`, remove deprecated v1 API, centralize mock factories, fix the config-readback smell.

## Non-Goals

- Adding new backtest engines (Structure backtester stays separate; Qlib factor research untouched).
- Changing the backend execution path (still Freqtrade subprocess via `FreqtradeBacktestRunner`).
- Live trading initiation from this page (promotion CTA navigates to `.liveReadiness`; this page never starts live trading — existing product decision).
- New backend endpoints (all needed APIs exist; only the handler persistence gap is fixed).

## Backend Changes

### Gap 1: Persist `equity_curve` and `trades` in `BacktestRun.result`

**File**: `app/workers/backtest_handler.py`, `_handle_success` (lines 232-256).

**Problem**: Only `metrics` dict and `trade_count` are written. `result.trades` and `result.equity_curve` from the `BacktestResult` object are discarded.

**Fix**: Extend the `result` dict written to the DB:

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
        {"timestamp": p.timestamp, "equity": p.equity, "drawdown": p.drawdown}
        for p in result.equity_curve
    ],
    "trades": [
        {
            "open_time": t.open_time,
            "close_time": t.close_time,
            "pair": t.pair,
            "side": t.side,
            "open_price": t.open_price,
            "close_price": t.close_price,
            "quantity": t.quantity,
            "profit": t.profit,
            "duration": t.duration,
            "mtf_state": t.mtf_state,
        }
        for t in result.trades
    ],
}
```

Field names align with the `EquityPoint` and `TradeRow` Pydantic models in `app/schemas/backtest_v2.py`, so the existing `BacktestRunResponse.model_validator` extracts them without change.

**Verification**: `BacktestResult` (returned by `FreqtradeBacktestRunner.run`) must actually populate `.trades` and `.equity_curve`. Confirm in `services/backtest_runner.py` result-parsing path; if gaps exist, fix there too.

### Gap 2: DryRunRunResponse field coverage for Run Rail

**File**: `app/schemas/dryrun*.py` + `app/routers/dryrun.py`.

Confirm `DryRunRunResponse` exposes `status`, `open_trades`, `total_profit`, `pid`, `created_at`, `stopped_at` for Run Rail display. The `DryRunRun` model already has these columns (`app/models/dryrun.py:13-39`); ensure the response schema maps them. Add missing fields if absent.

### No new endpoints

All needed APIs exist:
- Backtest: `POST /api/v2/backtest`, `GET /api/v2/backtest/status/{command_id}`, `GET /api/v2/backtest`, `GET /api/v2/backtest/{id}`
- Dryrun: `POST /api/v2/dryrun`, `POST /api/v2/dryrun/{id}/stop`, `GET /api/v2/dryrun/status/{command_id}`, `GET /api/v2/dryrun`, `GET /api/v2/dryrun/{id}`, `POST /api/v2/dryrun/{id}/sync`
- Failure clusters (strategy-level): `GET /api/growth/failure-clusters?strategy_uuid=`
- Promotion readiness: `GET /api/v2/strategies/{id}/workspace`
- Strategy list: `GET /api/v2/strategies`

Compare is client-side composition from multiple `GET /api/v2/backtest/{id}` calls.

### Backend tests

- `test_backtest_handler_persists_trades_equity`: after `_handle_success`, assert `result["equity_curve"]` and `result["trades"]` are non-empty and structurally correct.
- `test_backtest_run_response_extracts_trades_equity`: assert `BacktestRunResponse` model_validator extracts trades/equity_curve from a realistic `result` dict.
- Confirm dryrun response schema field coverage test.
- Zero regression on the 17 pre-existing failures.

## Frontend Architecture

### Three-Column Layout

```
┌─────────────┬───────────────────────────────┬──────────────────┐
│ Run Rail    │  Center (phase-driven)        │  Context Rail    │
│ (240pt)     │                               │ (280pt)          │
│             │  [Tab: Backtest | Dryrun]     │                  │
│ □ run #42   │  ┌─ Config ──────────────┐   │  Strategy meta   │
│ ▣ run #41   │  │ strategy/pairs/...    │   │  DSL hash        │
│ □ run #40   │  └───────────────────────┘   │  Data source     │
│             │  ┌─ Status ┐ ┌─ Summary ┐    │                  │
│ + New Run   │  └─────────┘ └──────────┘    │  Risk warnings   │
│             │  ┌─ Equity + Drawdown ──┐    │  ⚠ DD>25%        │
│             │  └──────────────────────┘    │  ⚠ PF<1          │
│             │  ┌─ Trades + Clusters ──┐    │                  │
│             │  └──────────────────────┘    │  Promotion       │
│             │  ┌─ Compare (≥2 sel) ───┐    │  [→ Live Readiness]│
│             │  └──────────────────────┘    │                  │
└─────────────┴───────────────────────────────┴──────────────────┘
```

**Responsiveness**:
- `>= 1100pt`: three columns side-by-side.
- `< 1100pt`: right Context Rail collapses into a bottom drawer (still always reachable; risk + promotion never disappear).
- `< 900pt`: left Run Rail collapses into a top horizontal strip.

### Tab Mechanism

Center top has a `Backtest` / `Dryrun` segmented control. Switching tab:
- Left Run Rail reloads with that mode's history list.
- Center Config panel swaps mode-specific fields.
- Right Rail risk/promotion logic is shared (both based on strategy readiness).
- Run Rail selection state is independent per tab (backtest selections vs dryrun selections don't bleed).

### Phase State Machine (unchanged enum, clarified behavior)

`idle → configuring → running → completed | failed`

- `idle`: only Config panel is editable; center shows empty-state hint.
- `configuring` / `running`: Config panel becomes read-only, showing `submittedConfig` (the snapshot of what was submitted, not a readback from `selectedRun`); Status panel live; result blocks show skeletons.
- `completed`: all result blocks render real data; right rail risk/promotion unlock.
- `failed`: Config read-only + error status + retry entry.

### Config Panel (replaces NewRunSheet)

No more modal sheet. Config is an inline block at the top of the center column.

**Shared fields** (both tabs):

| Field | Control | Source |
|---|---|---|
| Strategy | dropdown (name + version) | `APIStrategiesV2.list()` |
| Trading pairs | multi-select chips (dynamic) | strategy's `tradable_symbols` via workspace snapshot; fallback to default majors with "strategy didn't declare pairs" note |
| Timeframe | dropdown (5m/15m/1h/4h) | DSL `timeframe` |
| Initial capital | numeric input | default 10000 |
| Fee model | dropdown (0.05%/0.1%/0.2%/custom) | maps to `fee` |
| Slippage model | dropdown (0bps/5bps/10bps/custom) | maps to `slippage_bps` |

**Backtest-only**: date range (dual DatePicker).

**Dryrun-only**: stake amount, max open trades, initial wallet.

**Behavior**:
- Always visible and editable unless running (then read-only).
- "Run" button bottom-right of config; calls `startBacktestV2` or `startDryrun` per tab.
- Validation: strategy required, ≥1 pair, valid date range (backtest), capital > 0.
- On submit, snapshot config into `submittedConfig` before the run; read-only state renders from this snapshot (fixes the readback smell).
- Pairs load dynamically from workspace snapshot; if strategy declares no pairs, fall back to default majors with explicit "strategy didn't declare pairs, using defaults" note.

### Center Result Narrative (completed phase)

Four blocks top-to-bottom, each wrapped in `SectionCard`, each with a "data completeness" annotation in its header (e.g. `42 trades · 90d`) so every number is traceable to its source — a key anti-"AI flavor" measure.

**Block 1: Status + Summary** (one row, two cards)
- Status card: status dot + error message (failed) + execution duration + retry (failed).
- Summary card: 4 core metrics — total return, max drawdown, win rate, profit factor — each with "vs last same-strategy run" delta in small text.

**Block 2: Equity Curve + Drawdown** (one chart)
- Upper: equity curve line+area (180pt).
- Lower: drawdown bars (80pt), shared X-axis time.
- Empty state: "this run produced no curve data" (no mock).

**Block 3: Trade List + Run-level Failure Clustering**
- Trade table: open/close time, pair, side, open/close price, quantity, P&L, duration (10 columns).
- Below: run-level failure clustering via existing `RunFailureClustering.clusterFailures` on this run's losing trades; ≤5 clusters, each showing label / sample size / total loss / avg loss / common features.
- Empty state: "this run has no trades" (no mock).

**Block 4: ComparePanel** (conditional)
- Renders only when left Run Rail has ≥2 checked runs.
- Upper: KPI matrix table (return / DD / win rate / PF / trades across checked runs).
- Lower: equity curve overlay (≤3 curves, distinct colors).
- Data: client-side composition from `getBacktestV2(id:)` per checked run.

### Right Context Rail (always visible)

Three blocks stacked vertically, never scroll away.

**Block 1: Strategy Meta + Data Source**
- Strategy name + version, DSL hash (8-char prefix, copyable), current tab mode.
- Data source: engine, OHLCV source, execution duration. From `BacktestRunV2.config` and `data_source`.

**Block 2: Risk Warnings** (always visible, prominent)
- Computed via `RiskWarningRules.riskWarnings(for:)` — 5 rules: max DD > 25%, PF < 1, trades < 30, win rate < 35%, Sharpe < 0.
- Each warning: icon + message + current value (e.g. `DD 32% > 25% threshold`).
- No warnings → green "no risk thresholds triggered".
- Data-completeness awareness: if a warning fires due to small sample (e.g. `totalTrades < 30`), annotate "small sample, treat cautiously" — avoid misreading sample-size artifacts as real risk.

**Block 3: Promotion Eligibility** (bottom, CTA)
- `PerStrategyReadiness` grand status (ready / not_ready) + per-gate status (strategy-level: backtest pass, dryrun pass, DSL validation; system-level: dependency services, config).
- CTA "前往实盘准备" (Go to Live Readiness): highlighted-clickable when grand status = ready (navigates to `.liveReadiness`); disabled when not ready, with tooltip listing blocking gates.
- Page never starts live trading — judgment + navigation only.

### Left Run Rail

**Structure**:
```
┌─ Run Rail ──────────────┐
│ [+ New Run]             │
│ ▼ Recent Backtests (12) │
│ ▣ #42  +8.3%  3m ago    │
│ □ #41  -2.1%  1h ago    │
│ ...                     │
│ [Load more]             │
└─────────────────────────┘
```

**Per row**: checkbox (compare, max 3) + run number + total return (green/red) + relative time. Selected-for-viewing vs checked-for-compare are visually distinct (dot vs checkbox highlight).

**Behavior**:
- Click row (not checkbox): switch to view that run; center loads its detail, enters `completed` phase.
- Checkbox: add to compare set; ≥2 expands ComparePanel; >3 disables earliest.
- `New Run`: return to `idle`, clear config.

**Backtest Tab**: `listBacktestsV2(strategyUuid:limit:20)`, paginated.

**Dryrun Tab differences**:
- Rows show live status dot (running/stopped/failed) + open_trades + total_profit (no equity curve — dryrun is a live process, not historical).
- Click row: center shows that dryrun's live state (open positions, in-flight trades), not an equity curve.
- Row supports "Stop" action → `POST /api/v2/dryrun/{id}/stop`.
- No ComparePanel (dryrun has no equity curve; compare is meaningless). Checkboxes hidden in dryrun tab.

### ViewModel Rewrite

**File**: `ViewModels/BacktestLabViewModel.swift` (rewrite).

**State**:
```swift
@Observable @MainActor
final class BacktestLabViewModel {
    var phase: Phase
    var activeTab: RunTab                      // .backtest / .dryrun
    var selectedStrategy: StrategyV2?
    var submittedConfig: RunConfig?            // snapshot of submitted config
    var currentBacktestRun: BacktestRunV2?
    var currentDryrunRun: StrategyRunV2?
    var backtestRuns: [BacktestRunV2]
    var dryrunRuns: [StrategyRunV2]
    var comparedBacktestIds: Set<Int>          // backtest tab only
    var comparedRuns: [BacktestRunV2]
    var readiness: PerStrategyReadiness?
    var strategyFailureClusters: [FailureClusterSummary]
    var errorMessage: String?
    var availableStrategies: [StrategyV2]
    var tradableSymbols: [String]
}
```

**Key changes**:
1. **No mock toggle in ViewModel**: remove `useMockClient` default-true. ViewModel uses `@Environment(\.networkClient)` uniformly. Live vs mock is decided globally in `AlphaLoopApp` (live/mock/`--live`/`--mock` flags), not per-ViewModel. Mock mode surfaces via the existing `MOCK` badge.
2. **`submittedConfig` snapshot**: on submit, capture config; read-only state renders from this, not from `selectedRun` (fixes readback smell).
3. **`activeTab` drives**: tab switch reloads left rail list + swaps config fields + isolates compare set.
4. **Dryrun actually wired**: implement `startDryrun()` (currently throws 501) + poll dryrun status + stop dryrun, via `APIDryrun`.

### API Service Layer

- `APIBacktestV2.swift`: keep; remove inline `MockDataV2` (move to centralized mock file).
- `APIBacktest.swift` (v1): **delete** (deprecated, unused).
- `APIDryrun.swift`: new/complete — full `/api/v2/dryrun/*` (start/stop/status/list/get/sync) + mock factory.
- All mock factories centralized under `Services/MockGenerators/` by domain.

### Mock Policy

- Mock generators retained (graceful degradation when live unavailable), with explicit `MOCK` badge.
- Mock data is "honest": flat equity curves (not get-rich), realistic trade counts, modest metrics — so mock-mode UI walks don't mislead design judgment.
- `MockNetworkClient` mode dry-runs UI flow; never produces real runs.

### Types.swift Split

- Extract backtest models (`BacktestRunV2`, `BacktestStatusV2`, `BacktestEquityPoint`, `TradeRow`, `BacktestMetrics`, `BacktestRunSummary`, `FailureClusterSummary`) → `Models/BacktestTypes.swift`.
- New dryrun models → `Models/DryrunTypes.swift`.
- Other-domain models in `Types.swift` untouched.

## File Structure

```
Views/BacktestAndDryrun/
├── BacktestLabView.swift              ← rewrite: three-column container + Tab
├── LeftRail/
│   └── RunRailView.swift
├── Center/
│   ├── ConfigPanel.swift              ← inline config (replaces NewRunSheet)
│   ├── StatusSummaryBlock.swift
│   ├── EquityCurveBlock.swift
│   ├── TradeListBlock.swift
│   └── CompareBlock.swift
├── RightRail/
│   ├── StrategyMetaPanel.swift
│   ├── RiskWarningsPanel.swift
│   └── PromotionPanel.swift           ← rewrite (simplified)
├── Shared/
│   ├── SectionCard.swift              ← keep
│   ├── RiskWarningRules.swift         ← keep
│   └── RunFailureClustering.swift     ← keep
└── (delete NewRunSheet.swift)

Models/
├── BacktestTypes.swift                ← extracted from Types.swift
└── DryrunTypes.swift                  ← new

Services/
├── APIBacktestV2.swift                ← keep, mock moved out
├── APIDryrun.swift                    ← new/complete
└── MockGenerators/
    └── MockBacktest.swift             ← centralized mock factories

Localization/
└── L10n+Backtest.swift                ← restructure (see below)

backend/
├── app/workers/backtest_handler.py    ← fix _handle_success persistence
├── app/schemas/backtest_v2.py         ← confirm model_validator (likely no change)
├── app/schemas/dryrun*.py             ← confirm field coverage
└── tests/test_backtest_handler_*.py   ← new persistence test
```

## L10n Restructuring

Current 136 strings are organized by the old 9-section layout. Restructure by new three-column structure:

- `L10n.Backtest.Config.*` — config panel fields
- `L10n.Backtest.RunRail.*` — left rail
- `L10n.Backtest.Result.*` — center four blocks (status/summary/curve/trades/compare)
- `L10n.Backtest.Context.*` — right rail (meta/risk/promotion)
- `L10n.Backtest.Phase.*` — phase hints
- Delete `NewRunSheet` keys (sheet removed).

Bilingual zh-CN (default) / en-US as always. No hardcoded user-visible strings in views.

## Documentation

- This spec: `docs/superpowers/specs/2026-06-30-backtest-sim-deep-refactor-design.md`.
- Supersedes `2026-06-22-backtest-sim-refactor-design.md` (noted in frontmatter).
- User guide: update `docs/user-guide/content/{zh,en}/backtest-lab.html` to describe the new three-column layout and tab mechanism.

## Acceptance Checklist

### Backend
- [ ] `backtest_handler._handle_success` writes `result["equity_curve"]` and `result["trades"]`.
- [ ] `BacktestRunResponse` returns non-empty equity_curve and trades for a real run.
- [ ] `DryRunRunResponse` exposes `status`, `open_trades`, `total_profit` (and other Run Rail fields).
- [ ] `test_backtest_handler_persists_trades_equity` passes.
- [ ] Backend test suite zero regression (17 pre-existing failures still 17).

### macOS App
- [ ] Three-column layout renders correctly at 1200pt; right rail collapses <1100pt; left rail collapses <900pt.
- [ ] Backtest/Dryrun tab switches left rail list + config fields correctly.
- [ ] Config panel becomes read-only on submit, showing `submittedConfig` (not readback from run).
- [ ] Completed phase renders all four result blocks with real data.
- [ ] Empty data states show honest messages, no mock.
- [ ] Right rail risk warnings: 5 rules + data-completeness awareness.
- [ ] Promotion CTA: highlighted when ready, disabled with blocking-gate tooltip when not.
- [ ] Run Rail: ≥2 checked triggers ComparePanel; checkboxes hidden in dryrun tab.
- [ ] Dryrun: can start / poll status / stop.
- [ ] `swift build` passes; `swift test` passes.
- [ ] L10n bilingual complete; no hardcoded user-visible strings.

### Data Truthfulness
- [ ] Full live-mode walkthrough: real strategy → real backtest run → real equity/trades → real risk assessment.
- [ ] No client-side fabricated performance data anywhere.

## Open Questions

None at spec time. Implementation may surface details that return here for clarification.
