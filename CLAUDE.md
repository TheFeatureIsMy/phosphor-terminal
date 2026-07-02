# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (backend/)
```bash
cd backend
python3 run.py                          # Start FastAPI on :8000
python3 -m pytest tests/ -q             # Run all tests (~91 files, ~1262 functions)
python3 -m pytest tests/ -q --cov=app   # Tests with coverage (CI gate: ≥30%)
python3 -m pytest tests/test_risk_rules.py -q          # Single file
python3 -m pytest tests/ -q -k "structure"             # Filter by name
```
First-time setup: `scripts/build-backend.sh` installs `backend/requirements.txt` via `pip3 install --user`. Requires Python 3.12 (3.9 has syntax the existing models use).

### macOS App (macos-app/)
```bash
cd macos-app
swift build                                                       # Debug build
swift run                                                         # Build and run
swift test                                                        # Run XCTest target (Tests/)
```
Swift tools version: **6.2**. Target platform: **macOS 26**. No SPM dependencies — pure SwiftUI + Foundation. The executable target is named `AlphaLoop` (product folder: `macos-app/AlphaLoop/`).

**canvas-web bundling**: The built canvas-web output is copied into `macos-app/AlphaLoop/Resources/canvas-web/` and loaded via `Bundle.main` at runtime. `Package.swift` uses `.copy()` (not `.process()`) for this directory — `.process()` flattens the directory structure and breaks `index.html` relative paths (root cause of canvas white-screen bugs). After rebuilding canvas-web, copy the dist output to `Resources/canvas-web/` before building the Swift app.

### Canvas Web (canvas-web/) — strategy graph editor
```bash
cd canvas-web
npm run dev          # Vite dev server
npm run build        # tsc + vite build
npm test             # vitest run
```
Dependencies: React 19, `@xyflow/react`, `dagre`.

### Docker (full stack)
```bash
docker compose up    # postgres :5432, redis :6379, backend :8000, freqtrade :8080
```

## Architecture

AlphaLoop — AI-driven crypto quant trading dashboard. **Three independent codebases** that share no source code, only API contracts:
- `backend/` — Python 3.12, FastAPI, SQLAlchemy, Pydantic v2
- `macos-app/` — Swift 6.2, SwiftUI, no external deps
- `canvas-web/` — React 19 + Vite, embeds `@xyflow/react` for the strategy DAG editor

The product is bilingual (zh-CN default, en-US toggle) and dark cyberpunk themed.

### Backend (`backend/app/`)

FastAPI app with **46 routers** and **~50 service modules** (plus 21 manipulation services and 8 provider categories).

- **`config.py`** — Pydantic `Settings` driven by `.env` (FREQTRADE_URL, DATABASE_URL, REDIS_URL, FREQTRADE_DB_PATH, etc.).
- **`routers/`** — Thin handlers. They unmarshal/validate, delegate, and serialize. Business logic lives in services.
- **`services/`** — Two families:
  1. **Trading services** — `freqtrade_client.py` (async HTTP to Freqtrade REST), `freqtrade_db.py` (direct SQLite reader for trade history), `risk_rules.py`, `mtf_temporal_guard.py` (8-state HTF guard machine), `shadow_window.py`, `structure_matrix_service.py`, `rag_service.py` (PDF→strategy), `code_safety.py` (static analysis), `signal_scoring.py`, `sentiment_finbert.py`, etc.
  2. **Standalone data-structure utilities** — `bloom_filter.py`, `trie.py`, `skip_list.py`, `segment_tree.py`, `lru_cache.py`, `graph.py`, etc. Not trading-specific; consumable from anywhere.
- **`schemas/`** — Pydantic response models (shared between routers).
- **`domain/`** — Enums and pure domain types. `domain/enums.py` is the source of truth for `MTFGuardState` (8 values) and `MTFGuardAction` (6 values).
- **`tests/`** — ~91 pytest files, ~1262 test functions. Naming mirrors service/router. Uses pytest-asyncio.

Freqtrade integration is dual-channel: REST via `freqtrade_client.py` *and* direct SQLite reads via `freqtrade_db.py`. Trade history → SQLite; orders/control → REST. Don't conflate the two.

Redis runtime store (`runtime_redis_store.py`) serves BFF endpoints for live state. When Redis is empty, routers fall back to a service computation, then to mock data — keep this three-tier pattern when adding new BFF endpoints.

**Provider Adapter Foundation** (sub-project 1, 2026-06-16): New
package `app/services/providers/` holds the `ProviderAdapter` Protocol,
`ProviderRegistry`, `ProviderConfigService`, `ProviderHealthService`,
and `ProviderHealthScheduler` (native asyncio). All 8 provider
categories (`llm/cex/dex/notification/market_data/onchain/social/news`)
register their adapters at import time. Admin API: `/api/admin/providers/*`.
Configuration persists in the `provider_configs` table; credentials are
Fernet-encrypted. See `docs/integrations/api-audit.md` for per-provider
integration details and `docs/settings/configuration-model.md` for the
configuration schema. Dropped files: `services/data_source_manager.py`,
`routers/data_source_bff.py`, `ai_provider_configs` table.

### macOS App (`macos-app/AlphaLoop/`)

SwiftUI app organized by feature domain:

- **`Models/Types.swift`** — All domain models (Strategy, Order, Position, Backtest, AIResearchRun, AgentSignal, ShadowWindowSnapshot, etc.).
- **`Models/Enums.swift`** — Business enums. `SidebarSection` (8 sections: overview, strategy, structure, execution, risk, aiResearch, growth, system) and `AppRoute` (36 routes) drive all navigation.
- **`Services/NetworkClient.swift`** — Protocol-based dual mode: `MockNetworkClient` (mock data + simulated delay) and `LiveNetworkClient` (`http://localhost:8000` + Bearer auth). Swapped via `@Environment(\.networkClient)`.
- **`Services/API*.swift`** — One file per backend domain (40 files). Each adds typed methods on `NetworkClientProtocol` and **must ship a mock generator** (`MockX.something()`) alongside. New endpoint → add `Response` Codable type + method + mock factory in the same file. Notable: `APIStrategiesV2.swift` is the v2.5 strategy API (CRUD + versions + DSL validation + backtest).
- **`ViewModels/`** — `@Observable` `@MainActor` classes (20 files). Prefer parallel fetches with `async let`.
- **`Views/<Feature>/`** — Feature-scoped SwiftUI views (28 feature folders).
- **`Views/AppShell/StrategyLabRootView`** — Shared root that keeps Strategy + AI Research + Growth subviews alive across navigation. Prevents re-initialization when switching between these three sections.
- **`Views/Strategies/Workbench/`** — Strategy Workspace "launch console" (3-column layout): `StrategyWorkspaceConsoleView` → `WorkspaceChrome` (outer frame + lifecycle rail) → `ConsoleCenterStack` → `SectionCards`. Driven by `StrategyWorkspaceViewModel`.
- **`Views/BacktestAndDryrun/BacktestLabView`** — Backtest & simulation page as single-column data-terminal layout (2026-07-01 redesign, supersedes 2026-06-30 three-column layout). 48pt top bar (`BacktestTopBar`: `RunSwitcher` + `Backtest|Dryrun` segmented + New Run + Compare≥2), 360pt `EquityCurveHero` (gradient fill + drawdown + compare overlay), collapsible `StrategyContextStrip` (strategy + risk + promotion gate), `MetricsGrid` (2×4: totalReturn/maxDrawdown/sharpe/winRate/profitFactor/trades/filled/duration), `TradeListTable` (compact foldable table, 20-row pagination). Dryrun tab renders `DryrunStatusPanel` (status/apiUrl/pid/totalTrades/openTrades/totalProfit + Stop/Sync buttons) instead of equity/trades. Right-side drawers: `NewRunDrawer` (strategy Picker + version Picker + date range + capital/slippage/stake/maxOpenTrades — fields aligned with backend `StartBacktestRequest`/`StartDryRunRequest`) + `HistoryDrawer` (run list + compare checkboxes, tab-branched rows) via `DrawerContainer`. Dark terminal style: `surfaceHover.opacity(0.35)` + border, mono `PulseFonts.tabular` numbers, no glass/KryptonCard/serif italic. Driven by `BacktestLabViewModel` (`Phase` state machine, `activeTab`, `currentBacktestRun`, `currentDryrunRun`, `comparedRunIds`, `availableStrategies`/`availableVersions`/`selectedVersion`); key methods: `selectStrategy` (loads versions), `selectVersion`, `startBacktest(timerange:symbols:capital:slippageBps:)` (passes `selectedVersion.ruleDsl`), `startDryrun(symbols:stakeAmount:maxOpenTrades:capital:)`, `selectRun`/`selectDryrunRun`, `toggleCompare`, `switchTab`, `stopDryrun`/`syncDryrun`. Backend contracts: `POST /api/v2/backtest` requires `dsl`+`timerange`(YYYYMMDD-YYYYMMDD)+`symbols`+`initial_capital`; `POST /api/v2/dryrun` requires `dsl`+`symbols`+`stake_amount`+`max_open_trades`+`initial_wallet`+`strategy_id`. DSL source: `StrategyVersionV2.ruleDsl` via `APIStrategiesV2.listVersions(strategyId:)`. Spec: `docs/superpowers/specs/2026-07-01-backtest-lab-terminal-redesign.md`.
- **`Views/LiveReadiness/LiveReadinessView`** — Live-trading readiness gate, driven by `LiveReadinessViewModel`.
- **`Views/Dashboard/DashboardView`** — Bento Command Grid: `DashboardStatusBar` (infrastructure) → `AccountHeroCard` (equity + PnL + sparkline) → `AvailableActionsRow` → 3-column metrics (Runtime + Readiness + Risk) → `PositionRiskTable` → 2-column feeds (Decisions + Alerts) → `EmergencyActionBar` (sticky bottom). Driven by `DashboardViewModel` consuming single `GET /api/overview/dashboard` BFF endpoint.
- **`Views/Execution/ExecutionCenterView`** — Execution command center with top `EmergencyStopBar` + `LiveWireStrip` (mode indicator), batch cancel-all / force-close-all via `KryptonConfirmDialog`, inline single-order cancel and single-position close actions, and single-unit API endpoints (`POST /api/execution/orders/{order_id}/cancel`, `POST /api/execution/positions/{position_id}/close`). Sub-views: `OrdersPositionsView` (order/position tables with per-row inline actions and batch action bar), `ReconciliationBusView` (reconciliation runs with single-run retry `POST /api/reconciliation/runs/{run_id}/retry` and batch retry `POST /api/reconciliation/retry`), `TradeSourceTraceView`. Driven by `ExecutionCenterViewModel`.
- **`Views/Risk/RiskCenterView`** — Risk command center with top `EmergencyStopBar` + `LiveWireStrip`, real block/unblock backend (`POST /api/risk/block-new-entries`, `POST /api/risk/unblock`), hero risk gauge, guards grid (arc gauges). `StopProtectionView` — read-only risk rules section (`GET /api/risk/rules`) with configurable stop-loss/take-profit thresholds. `CircuitBreakersView` — circuit-breaker event list with `KryptonConfirmDialog` for resolve action (`POST /api/risk/circuit-breakers/{event_id}/resolve`, non-kill_switch events only). Driven by `RiskCenterViewModel`.
- **`Views/Manipulation/ManipulationRadarView`** — Market manipulation single-case narrative flow (1280 centered, staggered appearance, aligned with `MarketStructureView` / `StructureMatrixView` family). Nine sections: Masthead + disclaimer → §0 `ActiveCasesStrip` (horizontal focus switcher) → §1 `VerdictPanel` (M-type + stage + confidence ring + data completeness) → §2 `LifecycleTimeline` (horizontal 5-node timeline) → §3 `EvidenceLayerMatrix` (5 layers × n features, per-layer `data_quality` badges, missing-layer "Data unavailable") → §4 `WhaleConcentrationPanel` → §5 `CrossMarketPressurePanel` → §6 `SocialAccelerationPanel` → §7 `DualProfileSignalPanel` (conservative/aggressive side-by-side, affected symbols, strategy-impact list jumping to `.riskCenter` / `.strategyWorkspace`) → §8 `ManipulationAlertFeed` + `SimilarCasesPanel`. Driven by `ManipulationViewModel` consuming `/api/v2/manipulation/radar` + `/cases/{id}` (v2 with `evidence_layers`) + `/cases/{id}/strategy-impact` + `/cases/{id}/similar` + `/alerts` + WS `/api/v2/manipulation/stream` (stage_change / new_case push; falls back to 30s polling on disconnect). Uncertainty contract: probabilistic prefix language ("Likely" / "Evidence consistent with"), per-feature `data_quality` badges, completeness-derived max confidence. Backend engine unchanged: `ManipulationPatternClassifier` (M1-M8 rules), `ManipulationLifecycleTracker` (FSM: suspected→accumulate→markup→distribute→collapse, `generate_dual_signal` returns both profiles), in-memory `ManipulationCaseRepository` (case library + `find_similar` by evidence-vector cosine), `HistoricalManipulationScanner`. DSL filter rule type is `manipulation_score_filter` (`/strategy-impact` scans enabled strategies for this rule type to compute would-block). Spec: `docs/superpowers/specs/2026-07-01-manipulation-radar-refactor-design.md` (supersedes `2026-06-23-manipulation-radar-narrative-refactor-design.md`).
- **`DesignSystem/`** — Design tokens (`DesignTokens.swift`), view modifiers, animated effects. See Design System section below.
- **`Localization/`** — See L10n below.

**Data flow**: View → ViewModel → API service → NetworkClient (mock or live) → Backend.

**Routing**: `AppRoute` enum drives navigation. `LandingView` → login → `AppShellView` with sidebar (`SidebarSection`).

#### L10n (bilingual UI)
Every user-facing string routes through `L10n.<Domain>.something`. Each string is declared once as `static var foo: String { zh("中文", en: "English") }` in `Localization/L10n+<Domain>.swift` (18 domain files). `L10n.zh(...)` reads `SettingsState.shared.language` on the main actor. For reactive re-rendering on language change, use `L10nText("中文", en: "English")`.

**Never hardcode user-visible strings in views.** When adding a new section, add keys to the matching `L10n+<Domain>.swift` first, then reference them.

### Design System (ProofAlpha)

Dark cyberpunk glass-morphism. All tokens in `DesignSystem/DesignTokens.swift` — never hardcode colors, fonts, spacing, or radii.

- Colors via `PulseColors.*`, type ramp via `PulseFonts.*`, spacing via `PulseSpacing.*`, radii via `PulseRadii.*`. Read `DesignTokens.swift` for the full set.
- Liquid Glass: `.glassEffect()` must be applied directly to the content view — **not** inside a `.background()` modifier.
- Cards: `DepthCard` (3D tilt + spotlight), `SpotlightCard` (cursor glow), `CardModifier` (glass base).
- Background system: 4-layer (mesh gradient, scanlines, dot grid, noise texture).
- Reach for `ViewModifiers.swift` before writing one-off styling.

### Specs and design docs

Design specs live in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. When redesigning a page, check whether a prior spec exists and explicitly **supersede** it in the frontmatter. Specs are committed before implementation. Full docs index: `docs/README.md`.

### User Guide

End-user documentation lives in `docs/user-guide/` — a static HTML site (10 concept chapters + 25 page chapters + 5 walkthroughs, bilingual zh+en). The macOS app's `Services/UserGuide.swift` spawns `python3 -m http.server 4178 --bind 127.0.0.1` in `docs/user-guide/` on first click, polls until ready, then opens `http://localhost:4178/#/<anchor>`. The server is killed via `NSApplication.willTerminateNotification`. Entry points: sidebar footer link + Dashboard `LearnAlphaLoopCard` + Settings "Help" section.

When adding chapters: write the HTML file under `content/{zh,en}/...`, register its path in `assets/app.js` `NAV` array, and optionally seed it in `assets/search-index.json`. Internal cross-links use `href="#/<path>"`.

### CI

GitHub Actions (`.github/workflows/ci.yml`):
- **backend** job: `pytest backend/tests/` with `--cov-fail-under=30`.
- **macos-app** job: `swift build` on `macos-latest`.

## Conventions

- **Backend**: thin routers, logic in services. Tests mirror service/router names. New BFF endpoints follow the Redis → service → mock fallback pattern.
- **ProviderAdapter**: New domain types under `app/services/providers/`. New API endpoint → register a `ProviderAdapter` subclass + add to the category's `__init__.py`. Health/test/scheduler handle the rest.
- **Emergency stop**: single real endpoint `POST /api/v2/emergency/stop` (EmergencyStopService). Old `/api/execution/emergency-stop` and `/api/risk/emergency-stop` are deprecated (410).
- **macOS app**:
  - New domain types → `Models/Types.swift`. New enums → `Models/Enums.swift`.
  - New API endpoint → add Codable response + method + mock factory in `Services/API<Domain>.swift` (all three in one file).
  - Views grouped by feature domain under `Views/<Feature>/`.
  - Use `@Environment(\.networkClient)` to get the client; never instantiate `LiveNetworkClient` directly in a view.
  - Design tokens in `DesignSystem/DesignTokens.swift`; reach for `ViewModifiers.swift` before writing one-off styling.
  - All user-visible copy must go through `L10n.<Domain>` keys — see L10n section above.
- **Reply language**: respond to the user in Chinese; keep code, identifiers, and committed docs in English.
