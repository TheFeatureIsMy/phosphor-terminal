---
date: 2026-07-01
topic: Execution & Risk module pages polish
status: approved
supersedes: []
---

# Execution & Risk Module Pages Polish — Design Spec

Optimize 6 pages (Execution: ExecutionCenter / OrdersPositions / ReconciliationBus; Risk: RiskCenter / StopProtection / CircuitBreakers) without major redesign. Unified background, layered hierarchy, state-aware interactions, real-data binding, explicit paper/live distinction, mandatory confirmation on trading & high-risk actions, prominent & safe emergency stop, complete backend functionality, no fake orders/positions/risk events, i18n + docs updated.

## §1 — Cross-module shared components

### 1.1 `EmergencyStopBar` (48pt top bar, shared by all 6 pages)

- **Left**: `ModePill` (compact) showing LIVE / PAPER / DRYRUN / EMERGENCY LOCKED.
- **Center**: status text (e.g. "3 strategies running · 2 positions open").
- **Right**: `Emergency Stop` button (`.danger`, opens `KryptonConfirmDialog`).
  - Dialog body: affected runs count + current mode + "this action stops all strategies".
  - Calls `POST /api/v2/emergency/stop` (the single real endpoint, see §4.5).
- When `emergency_locked == true`, button morphs to `Resume` (`.warning`), calls `POST /api/v2/emergency/resume`.
- Replaces the in-page emergency buttons currently in `ExecutionCenterView` and `RiskCenterView`.

### 1.2 `LiveWireStrip` (2pt full-width gradient strip, above EmergencyStopBar)

- LIVE: red gradient, steady. PAPER: amber. DRYRUN: purple. MOCK: gray.
- EMERGENCY LOCKED: red, 1Hz pulse.
- Signal source: `AppState.isLiveMode` + `liveReadinessState` + `ModePill.Mode.resolve()`.
- Ambient signal (always in peripheral vision), not a corner pill.

### 1.3 `riskAtmosphericBackground()` view modifier

- Extract the inline `atmosphericBackground` (ZStack: `colors.background` + `RadialGradient` + Canvas scanlines) currently duplicated across the 3 risk pages into a reusable modifier in `DesignSystem/`.
- Risk 3 pages: replace inline impl with `.modifier(riskAtmosphericBackground())`.
- Execution 3 pages: apply the same modifier for visual consistency across modules.

### 1.4 Confirmation dialog unification

- All trading & high-risk actions across the 6 pages use `KryptonConfirmDialog` (`.danger` / `.warning`), not native `.alert`.
- Dialog copy template: action name + affected object count + current mode + irreversibility note.

## §2 — Execution module pages

Uniform: each page gets `LiveWireStrip` + `EmergencyStopBar` at top, background via `riskAtmosphericBackground()`.

### 2.1 ExecutionCenter

- **Keep**: `stateBanner`, `summaryCardsRow` (5 KPI cards), `sessionTableSection`.
- **Remove**: in-page `emergencyStopButton` (replaced by top bar).
- Session row mode pill: keep, but color sourced from `ModePill.Mode.color` for signal consistency.
- KPI numbers use `PulseFonts.tabular`.

### 2.2 OrdersPositions

- **Top action row** (below tabHeader): two batch buttons, enabled dynamically by `available_actions`.
  - `cancel_all_orders` — `.danger` + `KryptonConfirmDialog` (lists affected order count).
  - `force_close_all` — `.danger` + `KryptonConfirmDialog` (lists affected position count).
- **Order row inline**: `Cancel` button (only when `status == pending`), with `KryptonConfirmDialog`.
- **Position row inline**: `Close` button, with `KryptonConfirmDialog`.
- Backend single-unit endpoints added (see §4.1, §4.2).
- Status capsules + reasonCodes kept.

### 2.3 ReconciliationBus

- **Top action row**:
  - `refresh_exchange_state` — keep existing.
  - `retry_reconciliation` — new, `.warning` + `KryptonConfirmDialog`.
- **Run row inline**: failed runs get a `Retry` button, with `KryptonConfirmDialog`.
- i18n: migrate all inline `L10n.zh(...)` to the new `L10n.Reconciliation` namespace.

## §3 — Risk module pages

Uniform: each page gets `LiveWireStrip` + `EmergencyStopBar` at top, background via `riskAtmosphericBackground()` (extracted).

### 3.1 RiskCenter

- **Keep**: hero arc gauge + 4 quickStats + 3-column guard grid.
- **Remove**: bottom `emergencyPanel` (replaced by top bar).
- **block-new-entries / unblock buttons**: wire to real backend (see §4.6).
  - Both with `KryptonConfirmDialog` (`.warning`).
  - Enable state driven by `active_locks` (when locked, unblock enabled, block disabled).
- Arc gauge `emergency_locked` reflects real backend state.

### 3.2 StopProtection

- **Keep**: Header + StateBanner + position card list (price ladder + 4-level stop hierarchy).
- **New "Risk Rules" collapsible section** (below StateBanner, above position list):
  - Read-only display of `risk_rules.py` thresholds: daily loss / weekly loss / consecutive losses / max drawdown / correlation threshold / kill_switch.
  - Source: new `GET /api/risk/rules` (real data, see §4.7).
  - Collapsed: one-line summary + expand chevron. Expanded: full rule table.
- **Position card buttons**: refresh / force-close wire to real backend (single-position force-close reuses §4.2 endpoint).
- Stop-loss numbers use `PulseFonts.tabular`.

### 3.3 CircuitBreakers

- **Keep**: Header + total badge + filter chips + Timeline.
- **Default filter**: "unresolved" highlighted on entry (if any unresolved exist), so traders see actionable items first.
- **Run row inline action** (only for unresolved + non-kill_switch/non-emergency_stop types):
  - `Mark resolved` button — `.warning` + `KryptonConfirmDialog`.
  - Backend: new `POST /api/risk/circuit-breakers/{event_id}/resolve` (see §4.8).
- kill_switch / emergency_stop records do **not** show the resolve button (those require resume, avoid misuse).
- total_count badge kept.

## §4 — Backend completions

### 4.1 Single-order cancel — `POST /api/execution/orders/{order_id}/cancel`

- Impl: `FreqtradeClient.cancel_order(order_id)` (fallback to cancel_all if Freqtrade lacks single-unit, with reason in response).
- Returns: `{status, cancelled_order_id, reason_codes}`.

### 4.2 Single-position close — `POST /api/execution/positions/{position_id}/close`

- Impl: `FreqtradeClient.forceexit(trade_id)`.
- Returns: `{status, closed_position_id, reason_codes}`.

### 4.3 Batch cancel all — `POST /api/execution/orders/cancel-all`

- `available_actions` already returns `cancel_all_orders`; backend lacks the handler.
- Impl: iterate Freqtrade cancel or use Freqtrade batch endpoint.
- Returns: `{status, affected_count, reason_codes}`.

### 4.4 Batch force-close all — `POST /api/execution/positions/force-close-all`

- `available_actions` already returns `force_close_all`; backend lacks the handler.
- Impl: iterate `FreqtradeClient.forceexit` for all open trades.
- Returns: `{status, affected_count, reason_codes}`.

### 4.5 Emergency stop endpoint convergence

- **Deprecate** `POST /api/execution/emergency-stop` and `POST /api/risk/emergency-stop` (BFF stub).
- **Keep** `POST /api/v2/emergency/stop` (real `EmergencyStopService`: stops all StrategyRun + FreqtradeRun, writes `ExecutionLedgerEvent`).
- Frontend 6 pages all call `/api/v2/emergency/stop`.
- Deprecated endpoints return 410 with redirect hint; removed next release.

### 4.6 Risk block / unblock — real impl

- `POST /api/risk/block-new-entries` → `AccountRiskFirewall.activate_manual_block(reason="manual")`, writes `active_locks`.
- `POST /api/risk/unblock` → `AccountRiskFirewall.deactivate_manual_block()`.
- Returns: `{status, active_locks, reason_codes}`.

### 4.7 Risk rules query — `GET /api/risk/rules`

- Returns current effective thresholds from `risk_rules.py` config / `risk_policy_versions` DB table.
- Fields: daily_loss_limit, weekly_loss_limit, consecutive_losses_limit, max_drawdown, correlation_threshold, kill_switch {threshold, active}.
- Real data, not mock.

### 4.8 Circuit breaker resolve — `POST /api/risk/circuit-breakers/{event_id}/resolve`

- Impl: `CircuitBreakerEvent.resolved = True, resolved_at = now()`, write DB.
- Rejects kill_switch / emergency_stop types (return 409 + reason).
- Returns: `{status, resolved_event_id, reason_codes}`.

### 4.9 Reconciliation retry

- `POST /api/reconciliation/runs/{run_id}/retry` (single).
- `POST /api/reconciliation/retry` (batch, triggered by `retry_reconciliation` action).
- Impl: re-invoke `ReconciliationService.run_reconciliation()`.

### 4.10 Anti-fake constraints

- All endpoints read real data from `FreqtradeClient` / `FreqtradeDB` / DB.
- Mock data exists **only** at the `MockNetworkClient` layer (frontend mock channel); backend never returns mock.
- BFF three-tier fallback (Redis → service → mock) preserved; mock layer adds `data_source: "mock"` field, frontend shows a `MOCK` badge next to `ModePill`.

## §5 — i18n & docs

### 5.1 i18n

- **`L10n+Reconciliation.swift`** (new): migrate ReconciliationBus inline `L10n.zh(...)`. Keys: `title`, `refreshExchangeState`, `retryReconciliation`, `commandBus`, `reconciliationRuns`, `discrepancies`, `status`, `runId`, `startedAt`, `completedAt`, `retry`, `confirmRetry`, `confirmRetryMessage`, `noRuns`, `refreshing`.
- **`L10n+Execution.swift`** (extend): add `cancelAllOrders`, `forceCloseAll`, `cancelOrder`, `closePosition`, `confirmCancelAll`, `confirmCancelAllMessage`, `confirmForceCloseAll`, `confirmForceCloseAllMessage`, `confirmCancelOrder`, `confirmCancelOrderMessage`, `confirmClosePosition`, `confirmClosePositionMessage`, `affectedOrders`, `affectedPositions`.
- **`L10n+Risk.swift`** (new): `blockNewEntries`, `unblock`, `confirmBlock`, `confirmUnblock`, `riskRules`, `riskRulesSummary`, `dailyLossLimit`, `weeklyLossLimit`, `consecutiveLosses`, `maxDrawdown`, `correlationThreshold`, `killSwitch`, `markResolved`, `confirmMarkResolved`, `unresolved`, `resolved`, `cannotResolveKillSwitch`.
- **`L10n+EmergencyStop.swift`** (new, shared by 6 pages): `emergencyStop`, `resume`, `confirmStop`, `confirmStopMessage`, `confirmResume`, `confirmResumeMessage`, `affectedRuns`, `thisActionIrreversible`, `liveModeWarning`, `paperModeNote`.
- Rule: all user-visible strings in the 6 pages go through `L10n.<Domain>.<key>`; no inline `L10n.zh(...)`.

### 5.2 Docs

- This spec: `docs/superpowers/specs/2026-07-01-execution-risk-pages-polish-design.md`.
- CLAUDE.md updates:
  - Execution module paragraph: top EmergencyStopBar + LiveWireStrip + batch/single action buttons + single-unit endpoints.
  - Risk module paragraph: real block/unblock backend + read-only risk rules section + circuit breaker resolve.
  - Emergency stop: mark `/api/v2/emergency/stop` as the single real endpoint; old endpoints deprecated.
- Backend API docs: update `docs/integrations/api-audit.md` (or router docstrings) for the 8 new endpoints (§4.1, §4.2, §4.3, §4.4, §4.6, §4.7, §4.8, §4.9).

## Non-goals

- No major layout redesign of any of the 6 pages.
- No editable risk rules form (read-only display only).
- No enable/disable toggle for circuit breakers (only mark-resolved for non-kill_switch types).
- No runtime hot-swap of mock/live NetworkClient (still requires restart).
- No new BFF Redis runtime store beyond what existing endpoints already use.

## Open items

- None at spec approval time.
