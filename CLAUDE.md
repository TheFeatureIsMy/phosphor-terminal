# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (backend/)
```bash
cd backend
python3 run.py                          # Start FastAPI on :8000
python3 -m pytest tests/ -q             # Run all tests
python3 -m pytest tests/ -q --cov=app   # Tests with coverage (CI threshold: 30%)
python3 -m pytest tests/test_risk_rules.py -q  # Single test file
```

### macOS App (macos-app/)
```bash
cd macos-app
swift build                             # Build debug binary
swift run                               # Build and run
open .build/arm64-apple-macosx/debug/PulseDesk  # Run compiled binary
```

### Docker (full stack)
```bash
docker compose up                       # Starts backend API (:8000) + Freqtrade (:8080)
```

## Architecture

PulseDesk — AI-driven crypto quant trading dashboard. macOS native SwiftUI app + Python/FastAPI backend. All UI is Chinese (zh-CN), dark cyberpunk theme by default.

**Two independent codebases** share no code:
- `backend/` — Python 3.11, FastAPI, SQLAlchemy, Pydantic v2
- `macos-app/` — Swift 5.9, SwiftUI, macOS 14+, no external dependencies (SPM only)

### Backend

FastAPI app with 18 routers and ~40 service modules. Key architectural patterns:

- **`config.py`** — Pydantic Settings from `.env` (FREQTRADE_URL, DATABASE_URL, etc.)
- **`routers/`** — Thin route handlers, delegate to services
- **`services/`** — Business logic. Notable: `freqtrade_client.py` (async HTTP to Freqtrade API), `freqtrade_db.py` (direct SQLite reader for trade history), `risk_rules.py` (stop-loss/drawdown/correlation), `rag_service.py` (PDF→strategy generation), `code_safety.py` (static analysis for AI-generated code), `tradingagents_adapter.py` (multi-agent research), `signal_scoring.py` (agent signal quality), `sentiment_finbert.py` (FinBERT sentiment)
- **`services/` also contains data structure utilities** (bloom_filter, trie, skip_list, segment_tree, lru_cache, graph, etc.) — these are standalone implementations, not trading-specific
- **Tests** in `tests/` — 7 test files, run with pytest-asyncio

The backend talks to **Freqtrade** in two ways: REST API via `freqtrade_client.py` and direct SQLite reads via `freqtrade_db.py` (path configured by `FREQTRADE_DB_PATH`).

### macOS App

SwiftUI app with no third-party dependencies. Key patterns:

- **`Models/Types.swift`** — All domain models (Strategy, Order, Position, Backtest, AIResearchRun, AgentSignal, etc.)
- **`Models/Enums.swift`** — Business enums (StrategyType, AppRoute, SidebarSection, etc.)
- **`Services/NetworkClient.swift`** — Protocol-based dual-mode: `MockNetworkClient` (returns mock data with delay) and `LiveNetworkClient` (hits `http://localhost:8000` with Bearer auth)
- **`Services/API*.swift`** — Domain-specific API extensions on `NetworkClientProtocol`, each with mock data generators
- **`ViewModels/`** — `@Observable` classes calling API services, exposing state to views
- **`DesignSystem/`** — Design tokens, view modifiers, animated effects (all in SwiftUI, no external libs)

**Data flow**: View → ViewModel → API service → NetworkClient (mock or live) → Backend

**Routing**: `AppRoute` enum drives navigation. Landing page (`LandingView`) → login → `AppShellView` with sidebar.

### Design System (ProofAlpha)

Dark cyberpunk glass-morphism theme. All design tokens in `DesignSystem/DesignTokens.swift` — never hardcode colors.

- Neon green accent (#00FF9D), profit/loss color semantics
- Cards: `DepthCard` (3D tilt + spotlight), `SpotlightCard` (cursor glow), `CardModifier` (glass base)
- Backgrounds: 4-layer system (mesh gradient, scanlines, dot grid, noise texture)

### CI

GitHub Actions (`.github/workflows/ci.yml`): backend pytest with 30% coverage threshold + macOS `swift build`.

## Conventions

- New domain types → `macos-app/PulseDesk/Models/Types.swift`. New enums → `Models/Enums.swift`.
- New API endpoints → add mock data in `Services/API*.swift`, add domain types in `Types.swift`.
- Views organized by feature domain under `Views/`.
- Backend: thin routers, logic in services. Tests mirror service/router structure.
- Design tokens in `DesignSystem/DesignTokens.swift` — use view modifiers from `ViewModifiers.swift`.
