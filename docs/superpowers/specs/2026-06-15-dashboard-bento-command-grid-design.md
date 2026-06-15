---
title: Dashboard — Bento Command Grid Redesign
status: approved
date: 2026-06-15
authors: claude (frontend-design + brainstorming skills)
supersedes: docs/architecture/03_app_ia_and_ui_layouts.md (Dashboard section only)
related:
  - docs/product/ia_backend_redesign.md (§1 Dashboard, §2 OverviewAggregatorService)
  - docs/superpowers/specs/2026-06-07-krypton-pro-ui-overhaul-design.md
  - docs/superpowers/specs/2026-06-11-strategy-workbench-launch-console-design.md
mockup: docs/ui-references/mockups/dashboard-v3-refined.html
---

# Dashboard — Bento Command Grid

## 1. Problem

The current Dashboard follows the v2.1 "AI 总控台" (AI Control Tower) vision — centered on AI market judgment, agent signal distribution, and AI cost tracking. The PRD (`ia_backend_redesign.md`) explicitly states: "Dashboard 是交易运行总控台。它不是 AI 总控台，也不是普通首页。" The current implementation has:

- **Identity mismatch**: AI-centric framing vs PRD's trading-operation framing.
- **Missing PRD components**: No EquityCard, PnLCardGroup, LiveReadinessMiniCard, GlobalRiskCard, RecentDecisionFeed, AlertTimeline, EmergencyActionBar, or AvailableActions.
- **No reason_codes**: PRD mandates every card shows `reason_codes`; current implementation shows none.
- **No BFF endpoint**: Dashboard aggregates data from 7 services ad-hoc; PRD requires `GET /api/overview/dashboard` with `OverviewAggregatorService`.
- **Duplicate data**: The old AIStatusBar overlaps with metrics shown elsewhere.

## 2. Goals

1. Rebuild Dashboard as a **trading operation control tower** per PRD spec — 10 core components.
2. Implement `GET /api/overview/dashboard` BFF endpoint with `OverviewAggregatorService`.
3. Show `reason_codes` on every card. Show `availableActions` as contextual quick actions.
4. Eliminate all data duplication between StatusBar and cards.
5. Maintain ProofAlpha/Krypton dark cyberpunk visual language with KryptonCard system.
6. 30-second polling refresh for live state.

## 3. Non-Goals

- Not changing the GlobalStatusBar component used by other pages (we create a Dashboard-specific variant).
- Not implementing the full Command Bus for EmergencyStop (wire to existing `APIEmergency` for now; Command Bus is a backend phase).
- Not adding new backend domain services — only aggregating existing ones.
- Not changing Sidebar, AppShell, or navigation.

## 4. Layout — Bento Command Grid

```
┌─────────────────────────────────────────────────────────────────┐
│ GLOBAL STATUS BAR (sticky top)                                   │
│ SYS ● | FREQTRADE 12ms | REDIS 3ms | EXCHANGE ● | [reason_codes]│
├─────────────────────────────────┬───────────────────────────────┤
│ ACCOUNT OVERVIEW (Hero)         │  Today   │  Week   │  DD   │  SR │
│ 124,850.32 USDT                 │  +1.97%  │ +4.32%  │ -6.8% │ 1.82│
│ ▲ +2,415.80 (+1.97%) 24H       │          │         │       │     │
│ ░░░░░░ equity sparkline ░░░░░░  │          │         │       │     │
├─────────────────────────────────┴───────────────────────────────┤
│ SUGGESTED ACTIONS: [▶ Deploy ETH v2] [◉ Review 3 signals] [⚡ ...]│
├───────────────────┬───────────────────┬─────────────────────────┤
│ STRATEGY RUNTIME  │ LIVE READINESS    │ GLOBAL RISK STATE       │
│ 5 running         │ ◉ LIVE READY      │ ● NORMAL                │
│ ● 4 pos ● 2 pend │ All 7 gates pass  │ Daily ████████░░ 72%    │
│ [reason_codes]    │ [reason_codes]    │ Weekly █████████░ 85%    │
├───────────────────┴───────────────────┴─────────────────────────┤
│ POSITION RISK · 4 OPEN                                           │
│ ▌ BTC/USDT  LONG  0.15  67,420  +1,830  +2.71%  LOW  [reason]  │
│ ▌ ETH/USDT  LONG  2.5   3,680   +425    +4.62%  MED  [reason]  │
│ ▌ SOL/USDT  SHORT 20    168.50  -180    -0.53%  MED  [reason]  │
│ ▌ AVAX/USDT LONG  50    38.20   +340    +1.78%  LOW  [reason]  │
├─────────────────────────────────┬───────────────────────────────┤
│ RECENT DECISIONS                │ ALERT TIMELINE                │
│ 14:32 BTC EXECUTE LONG          │ ● Daily loss at 28%           │
│   [htf_bullish] [signal_strong] │ ● ETH near resistance $3,860  │
│ 14:15 SOL REDUCE SIZE           │ ● SOL vol expanding           │
│   [daily_loss_warning]          │ ● BTC Momentum v3 new pos     │
│ 13:48 ETH HOLD                  │ ● Binance API 450ms spike     │
├─────────────────────────────────┴───────────────────────────────┤
│ ⚠ EMERGENCY: HALT ALL TRADING (sticky bottom)                   │
└─────────────────────────────────────────────────────────────────┘
```

## 5. Component Specifications

### 5.1 GlobalStatusBar (Dashboard variant)

Infrastructure-only — no business metrics that duplicate cards below.

| Cell | Source | Color logic |
|------|--------|-------------|
| SYS state | `system.live_readiness_state` mapped to healthy/warning/blocked | green/amber/red dot |
| FREQTRADE latency | `system.fast_track_latency_ms` | value + green dot if < 100ms |
| REDIS RTT | `system.redis_rtt_ms` | value + green dot if < 50ms |
| EXCHANGE state | `system.exchange_state` | state label + dot |

Right-aligned: top-level `reasonCodes` from BFF response as `ReasonChipCluster`.

### 5.2 Account Overview (Hero Card)

Merges old EquityCard + PnLCardGroup. No duplication.

**Left panel (420px)**:
- `// ACCOUNT OVERVIEW` label
- Equity: large IBM Plex Mono 40px bold, CountUp animation
- 24h change: absolute + percentage, green/red
- Background: SVG sparkline of equity curve (48px tall, 12% opacity)

**Right panel (4 equal columns, dividers)**:
- Today P&L % + absolute
- Week P&L % + absolute
- Max Drawdown % + absolute
- Sharpe Ratio (30d rolling)

Emphasis: `.bold` KryptonCard. Gradient outline (accent → cyan).

### 5.3 Available Actions Row

Not a card — a horizontal button row below the Hero. Maps to `availableActions` from BFF.

Each action is a ghost button styled by severity:
- `primary` (accent green): deploy, approve
- `secondary` (cyan): review, inspect
- `warn` (amber): tighten, reduce

Max 3 actions shown. If none, row is hidden.

### 5.4 Strategy Runtime Card

| Field | Source |
|-------|--------|
| Running count | `runtime.running_strategies` |
| Positions | `runtime.open_positions` |
| Pending orders | `runtime.pending_orders` |
| Reconciling | `runtime.reconciling_count` |

Emphasis: `.balanced`. Large number (28px) + detail dots below.

### 5.5 Live Readiness Mini Card

| Field | Source |
|-------|--------|
| State | `system.live_readiness_state` |
| Gate count | derived from readiness check |

Visual: 36px pulsing lamp (green = LIVE_READY, amber = PAPER_ONLY, red = RISK_LOCKED/NOT_READY). Ambient radial glow behind lamp. `reason_codes` as chips.

### 5.6 Global Risk Card

| Field | Source |
|-------|--------|
| State | `risk.global_state` |
| Daily loss remaining | `risk.daily_loss_remaining_pct` |
| Weekly loss remaining | `risk.weekly_loss_remaining_pct` |
| Emergency locked | `risk.emergency_locked` |

Visual: Status pill (green/amber/red) + two horizontal gauge bars. Gauge color transitions from green → amber at 40% remaining.

### 5.7 Position Risk Card

Full-width table. Each row has a 3px left color stripe (green = long, red = short).

Columns: Symbol, Direction, Size, Entry, P&L, P&L%, Risk (dot + label), Reason (chips).

Risk levels map to: LOW = accent green, MED = amber, HIGH = danger red.

Data source: open positions from ExecutionService, risk annotation from RiskService.

### 5.8 Recent Decision Feed

Scrollable feed (max-height 280px). Each item:
- Time (HH:mm)
- Symbol + Decision verb (colored: EXECUTE = green, HOLD = cyan, REDUCE = amber, REJECT = red)
- Description text
- `reason_codes` chips

Data source: `recent_decisions` from BFF (last 10).

### 5.9 Alert Timeline

Scrollable timeline (max-height 280px). Vertical dotted connector between items.

Each item:
- Level dot (info = cyan, warning = amber, error = red)
- Title
- Meta: scope (symbol or SYSTEM/PORTFOLIO) + time

Data source: `alerts` from BFF (last 10).

### 5.10 Emergency Action Bar (sticky bottom)

Fixed to viewport bottom. Contains:
- Label: "EMERGENCY CONTROL"
- Button: "⚠ HALT ALL TRADING" — danger-styled
- Note: "Stops all strategies · Cancels pending orders · Preserves positions"

On click: `KryptonConfirmDialog(style: .danger)` → calls `APIEmergency.triggerEmergencyStop()`.

## 6. Backend: BFF Endpoint

### `GET /api/overview/dashboard`

New router: `routers/overview_dashboard.py`
New service: `services/overview_aggregator.py`

Response schema (matches PRD exactly):

```python
class DashboardBFFResponse(BaseModel):
    state: str                              # "healthy" | "warning" | "blocked" | ...
    reason_codes: list[str]
    available_actions: list[AvailableAction]
    account: AccountOverview                # equity, currency, today_pnl_pct, week_pnl_pct, max_drawdown_pct, sharpe_ratio
    runtime: RuntimeOverview                # running_strategies, open_positions, pending_orders, reconciling_count
    risk: RiskOverview                      # global_state, daily_loss_remaining_pct, weekly_loss_remaining_pct, emergency_locked
    system: SystemOverview                  # live_readiness_state, fast_track_latency_ms, redis_rtt_ms, freqtrade_state, exchange_state
    recent_decisions: list[RecentDecision]  # time, symbol, decision, reason_codes
    alerts: list[Alert]                     # level, title, symbol, time

class AvailableAction(BaseModel):
    action_type: str     # "deploy_strategy" | "review_signals" | "tighten_stop" | ...
    label: str
    severity: str        # "primary" | "secondary" | "warn"
    target_id: str | None
```

`OverviewAggregatorService` calls existing services in parallel:
- `freqtrade_client` → account balance, positions
- `runtime_redis_store` → strategy runtime state
- risk service → global risk state, loss budgets
- system health check → latency, connection states
- decision snapshot → recent decisions
- alert service → recent alerts

Falls back to mock data per the three-tier pattern (Redis → service → mock).

### Tests

`tests/test_overview_dashboard.py` — test the aggregator with mocked sub-services. Test the three-tier fallback. Test response schema conformance.

## 7. Frontend: File Changes

### Delete
- `Views/Dashboard/DashboardView.swift` (replaced entirely)
- `Views/Dashboard/Cards/AgentSignalDistributionCard.swift`
- `Views/Dashboard/Cards/BentoEquityCard.swift`
- `Views/Dashboard/Cards/RecentRiskEventsCard.swift`
- `Views/Dashboard/Cards/ServiceHealthCard.swift`
- `Views/Dashboard/TickerTapeView.swift`
- `Views/Dashboard/TradingWorkflowRailView.swift`
- `Views/Dashboard/UnifiedToolbar.swift`

### Keep
- `Views/Dashboard/EquityCurveChart.swift` (reuse sparkline data)
- `Views/Dashboard/LearnAlphaLoopCard.swift` (onboarding, show when no data)

### New
- `Views/Dashboard/DashboardView.swift` — new Bento grid layout
- `Views/Dashboard/AccountHeroCard.swift` — equity + PnL + sparkline
- `Views/Dashboard/DashboardStatusBar.swift` — infrastructure-only status bar
- `Views/Dashboard/AvailableActionsRow.swift` — contextual action buttons
- `Views/Dashboard/StrategyRuntimeCard.swift`
- `Views/Dashboard/LiveReadinessCard.swift`
- `Views/Dashboard/GlobalRiskCard.swift`
- `Views/Dashboard/PositionRiskTable.swift`
- `Views/Dashboard/RecentDecisionFeed.swift`
- `Views/Dashboard/AlertTimeline.swift`
- `Views/Dashboard/EmergencyActionBar.swift`

### Modify
- `ViewModels/DashboardViewModel.swift` — rewrite to consume single BFF endpoint
- `Services/APIDashboard.swift` — replace endpoints with single `getDashboardBFF()`
- `Localization/L10n+Dashboard.swift` — update string keys for new components

## 8. Data Flow

```
DashboardView
  └── .task { viewModel.load() }
        └── APIDashboard.getDashboardBFF()
              └── GET /api/overview/dashboard
                    └── OverviewAggregatorService
                          ├── freqtrade_client (account + positions)
                          ├── runtime_redis_store (strategies)
                          ├── risk_service (risk state)
                          ├── system_health (latency, connections)
                          ├── decision_snapshot (recent decisions)
                          └── alert_service (alerts)
```

Polling: 30s interval via `viewModel.startPolling()`. EmergencyStop: `APIEmergency.triggerEmergencyStop()` with `KryptonConfirmDialog`.

## 9. Visual Tokens

All from ProofAlpha/Krypton system — no new tokens.

- Cards: `KryptonCard(emphasis:)` — Hero = `.bold`, Runtime/Readiness/Risk = `.balanced`, Table/Feed/Timeline = `.subtle`
- Numbers: `CountUp` spring animation
- Entry: `.staggeredAppearance(index:)` at 35ms intervals
- Hover: `.hoverGlassStyle()` with accent border
- Reason chips: info (cyan), warn (amber), block (red)
- Position stripes: 3px left border, profit green / loss red

## 10. Removed Components

The following v2.1 "AI 总控台" components are removed:
- `AIStatusBar` (AI provider, GPU, AI cost, pending AI jobs)
- `AIMarketJudgmentCard` (direction, confidence, source agent)
- `PendingConfirmationsCard` (approve/reject workflow)
- `AgentSignalDistributionView` (long/short bar chart per agent)
- `StrategyStatusOverviewCard` (draft/active/dry-run/paused counts)
- `RiskInterceptionStatsCard` (rejected/reduced/paper-only/allowed)
- `TradingWorkflowRailView` (9-step sinusoidal pipeline)
- `TickerTapeView` (market ticker)

These features are available on their respective dedicated pages (Signal Center, Risk Center, Strategy Workspace, etc.).
