# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (backend/)
```bash
cd backend
python3 run.py                          # Start FastAPI on :8000
python3 -m pytest tests/ -q             # Run all tests (~77 files)
python3 -m pytest tests/ -q --cov=app   # Tests with coverage (CI gate: ≥30%)
python3 -m pytest tests/test_risk_rules.py -q          # Single file
python3 -m pytest tests/ -q -k "structure"             # Filter by name
```
First-time setup: `scripts/build-backend.sh` installs `backend/requirements.txt` via `pip3 install --user`.

### macOS App (macos-app/)
```bash
cd macos-app
swift build                                                       # Debug build
swift run                                                         # Build and run
open .build/arm64-apple-macosx/debug/AlphaLoop                    # Run compiled binary
swift test                                                        # Run XCTest target (Tests/)
```
Swift tools version: **6.2**. Target platform: **macOS 26**. No SPM dependencies — pure SwiftUI + Foundation. The executable target is named `AlphaLoop` (the product folder still lives under `macos-app/AlphaLoop/`).

### Canvas Web (canvas-web/) — strategy graph editor
```bash
cd canvas-web
npm run dev          # Vite dev server
npm run build        # tsc + vite build
npm test             # vitest run
```

### Docker (full stack)
```bash
docker compose up    # postgres :5432, redis :6379, backend :8000, freqtrade :8080
```

## Architecture

PulseDesk — AI-driven crypto quant trading dashboard. **Three independent codebases** that share no source code, only API contracts:
- `backend/` — Python 3.11, FastAPI, SQLAlchemy, Pydantic v2
- `macos-app/` — Swift 6.2, SwiftUI, no external deps
- `canvas-web/` — React 19 + Vite, embeds `@xyflow/react` for the strategy DAG editor

The product is bilingual (zh-CN default, en-US toggle) and dark cyberpunk themed by default.

### Backend (`backend/app/`)

FastAPI app with **~43 routers** and **~85 service modules**. The shape is deliberate:

- **`config.py`** — Pydantic `Settings` driven by `.env` (FREQTRADE_URL, DATABASE_URL, REDIS_URL, FREQTRADE_DB_PATH, etc.).
- **`routers/`** — Thin handlers. They unmarshal/validate, delegate, and serialize. Business logic lives in services.
- **`services/`** — Two distinct families inside the same folder:
  1. **Trading services** — e.g. `freqtrade_client.py` (async HTTP to Freqtrade REST), `freqtrade_db.py` (direct SQLite reader for trade history at `FREQTRADE_DB_PATH`), `risk_rules.py`, `mtf_temporal_guard.py` (8-state HTF guard machine), `shadow_window.py`, `structure_matrix_service.py`, `rag_service.py` (PDF→strategy), `code_safety.py` (static analysis for AI-generated code), `tradingagents_adapter.py`, `signal_scoring.py`, `sentiment_finbert.py`.
  2. **Standalone data-structure utilities** — `bloom_filter.py`, `trie.py`, `skip_list.py`, `segment_tree.py`, `lru_cache.py`, `graph.py`, etc. Not trading-specific; consumable from anywhere.
- **`schemas/`** — Pydantic response models (shared between routers).
- **`domain/`** — Enums and pure domain types. `domain/enums.py` is the source of truth for things like `MTFGuardState` (8 values) and `MTFGuardAction` (6 values).
- **`tests/`** — ~77 pytest files. Naming mirrors service/router. Uses pytest-asyncio.

Freqtrade integration is dual-channel: REST via `freqtrade_client.py` *and* direct SQLite reads via `freqtrade_db.py`. Any code that needs trade history reads from SQLite; orders/control go through REST. Don't conflate the two.

There's also a Redis runtime store (`runtime_redis_store.py`) that the BFF endpoints read for live state (e.g. `read_mtf_guard_state`). When Redis is empty, routers fall back to a service computation, and finally to mock data — keep this three-tier pattern when adding new BFF endpoints.

### macOS App (`macos-app/AlphaLoop/`)

SwiftUI app, organized by feature domain. Architecture is layered:

- **`Models/Types.swift`** — All domain models (Strategy, Order, Position, Backtest, AIResearchRun, AgentSignal, ShadowWindowSnapshot, etc.).
- **`Models/Enums.swift`** — Business enums (StrategyType, AppRoute, SidebarSection, MTFGuardState, …).
- **`Services/NetworkClient.swift`** — Protocol-based dual mode: `MockNetworkClient` (returns mock data with simulated delay) and `LiveNetworkClient` (hits `http://localhost:8000` with Bearer auth). Swapped via `@Environment(\.networkClient)`.
- **`Services/API*.swift`** — One file per backend domain. Each adds typed methods on `NetworkClientProtocol` and **must ship a mock generator** (`MockX.something()`) alongside, because the mock client expects it. New endpoint → add `Response` Codable type + method + mock factory in the same file.
- **`ViewModels/`** — `@Observable` `@MainActor` classes that call API services and expose state to views. Prefer parallel fetches with `async let`.
- **`Views/<Feature>/`** — Feature-scoped SwiftUI views. New domain types belong in `Models/Types.swift`, not in view files.
- **`DesignSystem/`** — Design tokens, view modifiers, animated effects. Pure SwiftUI.
- **`Localization/`** — See **L10n** below.

**Data flow**: View → ViewModel → API service → NetworkClient (mock or live) → Backend.

**Routing**: `AppRoute` enum drives navigation. `LandingView` → login → `AppShellView` with sidebar (`SidebarSection`).

#### L10n (bilingual UI)
Every user-facing string must route through `L10n.Structure.something` (or the appropriate `L10n.<Domain>`). Each string is declared once as `static var foo: String { zh("中文", en: "English") }` in `Localization/L10n+<Domain>.swift`. `L10n.zh(...)` reads `SettingsState.shared.language` on the main actor. For views that should reactively re-render on language change, use the `L10nText("中文", en: "English")` view (it observes `SettingsState`).

**Never hardcode user-visible strings in views.** When adding a new section, add keys to the matching `L10n+<Domain>.swift` first, then reference them.

### Design System (ProofAlpha)

Dark cyberpunk glass-morphism. All tokens in `DesignSystem/DesignTokens.swift` — never hardcode colors, fonts, spacing, or radii.

- Color namespace: `PulseColors.*` (accent green `#00FF9D`, `StateColors.{yellow,orange,red}`, `cardBackground`, `border`, `textPrimary/Secondary/Muted`).
- Type ramp: `PulseFonts.*` (`displayHeading`, `headline`, `tabular`, `tabularLarge`, `monoLabel`, `caption`, `micro`).
- Spacing: `PulseSpacing.{xxs:4, xs:8, sm:12, md:16, lg:24, xl:32, xxl:48}`.
- Radii: `PulseRadii.{xs, sm, md, card, lg, badge, button, circle}`.
- Liquid Glass: `.glassEffect()` must be applied directly to the content view — **not** inside a `.background()` modifier. See `memory/feedback_glass_effect_approach.md`.
- Cards: `DepthCard` (3D tilt + spotlight), `SpotlightCard` (cursor glow), `CardModifier` (glass base).
- Background system: 4-layer (mesh gradient, scanlines, dot grid, noise texture).

### Specs and design docs

Design specs for non-trivial UI work live in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. When redesigning a page, check whether a prior spec exists and explicitly **supersede** it in the frontmatter rather than silently writing over it. Specs are committed before implementation.

### User Guide

End-user documentation lives in `docs/user-guide/` — a static HTML site (10 concept chapters + 25 page chapters + 5 walkthroughs, bilingual zh+en). The site uses `fetch()` to load chapters, which browsers block under `file://`, so the macOS app's `Services/UserGuide.swift` spawns `python3 -m http.server 4178 --bind 127.0.0.1` in `docs/user-guide/` on first click, polls until ready, then opens `http://localhost:4178/#/<anchor>`. The server is killed via `NSApplication.willTerminateNotification`. Entry points: sidebar footer link + Dashboard `LearnAlphaLoopCard` + Settings "Help" section.

When adding chapters: write the HTML file under `content/{zh,en}/...`, register its path in `assets/app.js` `NAV` array, and optionally seed it in `assets/search-index.json`. Internal cross-links use `href="#/<path>"` matching a NAV entry.

### CI

GitHub Actions (`.github/workflows/ci.yml`):
- **backend** job: `pytest backend/tests/` with `--cov-fail-under=30`.
- **macos-app** job: `swift build` on `macos-latest`.

## Conventions

- **Backend**: thin routers, logic in services. Tests mirror service/router names. New BFF endpoints follow the Redis → service → mock fallback pattern.
- **macOS app**:
  - New domain types → `Models/Types.swift`. New enums → `Models/Enums.swift`.
  - New API endpoint → add Codable response + method + mock factory in `Services/API<Domain>.swift` (all three in one file).
  - Views grouped by feature domain under `Views/<Feature>/`.
  - Use `@Environment(\.networkClient)` to get the client; never instantiate `LiveNetworkClient` directly in a view.
  - Design tokens in `DesignSystem/DesignTokens.swift`; reach for `ViewModifiers.swift` before writing one-off styling.
  - All user-visible copy must go through `L10n.<Domain>` keys — see L10n section above.
- **Reply language**: respond to the user in Chinese; keep code, identifiers, and committed docs in English. See `memory/user_language.md`.
