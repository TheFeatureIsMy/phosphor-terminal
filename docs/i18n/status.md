# i18n Status

> Last updated: 2026-07-10
> Auditor: automated sweep

## Summary

The macOS app uses a custom `L10n` system with `zh()` / `en()` helper functions.
Two patterns coexist:

1. **Centralized keys** (preferred): `L10n.Growth.title`, `L10n.Settings.tabGeneral`, etc.
   Defined in `macos-app/AlphaLoop/Localization/L10n+*.swift` files.
2. **Inline `L10n.zh("中文", en: "English")`**: Used in 50+ view files. Functionally
   correct (supports both languages) but bypasses the centralized key system.

## L10n Extension Files

| File | Scope | Key Count (approx) |
|---|---|---|
| `L10n+Navigation.swift` | Sidebar, routes | 40+ |
| `L10n+Dashboard.swift` | Dashboard, live readiness | 50+ |
| `L10n+Growth.swift` | Growth engine (reports, candidates, SHAP, signal validity, evidence) | 35+ |
| `L10n+Settings.swift` | Settings tabs, trading, risk, notifications, API keys, MCP, data, danger | 50+ |
| `L10n+System.swift` | System status, data source unavailable, service management | 20+ |
| `L10n+Common.swift` | Shared labels (refresh, retry, cancel, confirm, etc.) | 30+ |
| `L10n+Strategies.swift` | Strategy workspace, DSL, backtest | 40+ |
| `L10n+Structure.swift` | Market structure, MTF guard | 25+ |
| `L10n+LiveReadiness.swift` | Live readiness checks, launch console | 30+ |
| `L10n+Backtest.swift` | Backtest lab, dryrun | 20+ |
| `L10n+AIStudio.swift` | AI research room | 15+ |
| `L10n+AgentPlatform.swift` | Agent platform | 10+ |
| `L10n+Signals.swift` | Signal center | 15+ |

## Inline L10n.zh() Usage

Views with significant inline `L10n.zh()` counts (potential candidates for extraction):

| File | Inline Count | Notes |
|---|---|---|
| `Views/Risk/RiskView.swift` | 57 | Legacy risk view - many section labels inline |
| `Views/Growth/StrategyOptimizationView.swift` | 38 | Workflow steps, candidate cards |
| `Views/Growth/FailureClusteringView.swift` | 34 | Cluster labels, regime matrix |
| `Views/ExecutionRecords/ExecutionRecordsView.swift` | 15 | Execution log labels |
| `Views/Risk/RiskCenterView.swift` | 14 | Risk guard labels |
| `Views/Risk/CircuitBreakersView.swift` | 7 | Breaker labels |
| Other views | <5 each | Minor inline usage |

## Issues Found & Fixed (2026-07-10)

1. **`NotificationSettingsView.swift`**: Hardcoded "Bot Token" / "Chat ID" labels → replaced with `L10n.Settings.telegramBotToken` / `L10n.Settings.telegramChatId`.
2. **`GrowthView.swift`**: Hardcoded summary stats ("156", "63.2%", "AI Research", "KOL") → replaced with real computed values from ViewModel.
3. **`StrategyOptimizationView.swift`**: Hardcoded confidence pill → replaced with DSL validity pill using i18n keys.
4. **`CandidateCard.swift`**: All labels now use `L10n.zh()` pattern for evidence source, rationale, DSL validity.
5. **`GrowthReportCard.swift`**: All labels now use `L10n.zh()` pattern for metrics, findings, suggestions.

## Remaining Work

- Extract inline `L10n.zh()` calls in `RiskView.swift` (57), `StrategyOptimizationView.swift` (38),
  `FailureClusteringView.swift` (34) into centralized `L10n+*.swift` files.
- These are functionally i18n-complete (both zh/en supported) but should be centralized for maintainability.
