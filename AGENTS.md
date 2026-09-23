# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

AlphaLoop (phosphor-terminal) is an AI-driven crypto quant trading dashboard composed of three independent codebases that share no source code and communicate only via HTTP API. Product defaults to Chinese (zh-CN) with a dark cyberpunk theme. Deeper conventions live in `CLAUDE.md` (authoritative working spec) and `docs/README.md` (docs index; architecture docs read 00 → 17).

## Project Structure

```
phosphor-terminal/
├── backend/        Python 3.11 · FastAPI · SQLAlchemy · Pydantic v2
│   ├── app/        routers/, services/, schemas/, domain/, models/, workers/, middleware/
│   ├── alembic/    DB migrations (versions/); alembic.ini at backend root
│   └── tests/      pytest files mirroring service/router names
├── macos-app/      Swift 6.2 · SwiftUI · macOS 26+ (no SPM deps); executable target `AlphaLoop`
│   ├── AlphaLoop/  DesignSystem/, Views/, ViewModels/, Services/, Models/, Localization/
│   └── Tests/      XCTest target
├── canvas-web/     React 19 · Vite · @xyflow/react strategy DAG editor (embedded in macOS WebView)
├── freqtrade/      Freqtrade user_data + start.py (runs as docker-compose service)
├── docs/           architecture/ (v2.5, numbered 00–17), product/, planning/, superpowers/specs/
└── docker-compose.yml  postgres :5432, redis :6379, backend :8000, freqtrade :8080
```

## Build, Test, and Development Commands

**Backend** (`backend/`):
- `pip3 install -r requirements.txt` — first-time setup (also `requirements-ai.txt` / `requirements-ml.txt` for AI/ML extras)
- `python3 run.py` — start FastAPI on `:8000`
- `python3 -m pytest tests/ -q --cov=app` — run tests (CI gate `--cov-fail-under=30`; CI runs Python 3.11)
- `python3 -m pytest tests/test_risk_rules.py -q` — single file; add `-k "pattern"` to filter by name
- DB migrations: alembic (`backend/alembic/versions/`); `init_db()` in `app/main.py` lifespan also runs `create_all`. New ORM models must be imported in the `main.py` lifespan block before `init_db()`.
- `scripts/build-backend.sh` is a legacy PyInstaller/Tauri-sidecar build script — not part of the normal dev loop.

**macOS App** (`macos-app/`):
- `swift build && swift run` — build and launch AlphaLoop
- `swift test` — XCTest (use `run-tests.sh` if framework paths are needed)

**Canvas Web** (`canvas-web/`):
- `npm run dev` — Vite dev server on `:5173`; `npm run build` — `tsc && vite build`; `npm test` — vitest

**Docker full stack**: `docker compose up` (freqtrade runs `--dry-run` with `PulseDeskUniversalStrategy`)

## Backend Architecture (the non-obvious parts)

- **Thin routers, logic in services**: `routers/` only validate/serialize and delegate; business logic lives in `services/`. `schemas/` holds Pydantic v2 response models; `domain/` holds enums and pure domain types (`domain/enums.py` is the source of truth for `MTFGuardState`/`MTFGuardAction`).
- **Command Bus + Worker**: long-running actions (backtest, dryrun, deploy rules, emergency stop, reconciliation, pause, live_small) are enqueued as commands and executed by `workers/command_worker.py` handlers. `main.py` lifespan starts in-process background loops: `CommandWorkerLoop`, `TradeSyncLoop`, provider health scheduler, Binance ticker stream. Contract doc: `docs/architecture/14_command_bus_worker_contract_v2_5.md`.
- **Strategy Rule DSL**: strategies are defined as a rule DSL (`domain/dsl.py`) interpreted/validated/migrated by `services/dsl_interpreter.py` / `dsl_validator.py` / `dsl_migrator.py` (+ `dsl_hasher`, `dsl_patch`). Semantics doc: `docs/architecture/13_strategyruledsl_semantics_v2_5.md`. Backtest/dryrun v2 APIs require the `dsl` payload.
- **Three-tier BFF pattern**: BFF routers (`*_bff.py`, `overview_aggregator`) read Redis runtime store (`runtime_redis_store.py`) → fall back to service computation → fall back to mock data. Preserve this when adding BFF endpoints.
- **Freqtrade dual-channel**: REST via `services/freqtrade_client.py` for control/orders; direct SQLite via `services/freqtrade_db.py` for trade history. Do not conflate.
- **Provider Adapter Foundation**: `services/providers/` holds the `ProviderAdapter` protocol, registry, config/health services; 8 categories (`llm/cex/dex/notification/market_data/onchain/social/news`) register adapters at import time (`providers/categories.register_all()` in lifespan). Config persists in `provider_configs` (Fernet-encrypted credentials); admin API `/api/admin/providers/*`. New provider → subclass `ProviderAdapter` + register in its category `__init__.py`.
- **Emergency stop**: single real endpoint `POST /api/v2/emergency/stop` (`EmergencyStopService`). Old `/api/execution/emergency-stop` and `/api/risk/emergency-stop` are deprecated (return 410).
- **Trading control** (`routers/trading.py`): `POST /api/trading/start-paper` (paper = dry-run via Command Bus), `/start-live-small` (full gate chain: preconditions → approval → human confirm → circuit breaker → `LIVE_SMALL_ENABLED` switch, default off), `/disable-auto`. Run lifecycle: `POST /api/v2/strategy-runs/{id}/pause|resume|stop`. Reconciliation holds a state lease (`state_leases` table, `StateLeaseService`, `GET /api/state-leases`).
- Config: `app/config.py` Pydantic `Settings` from `.env` (see `.env.example`): `DATABASE_URL`, `REDIS_URL`, `FREQTRADE_URL`, `FREQTRADE_DB_PATH`, `LIVE_SMALL_ENABLED`, etc.

## macOS App Architecture

- **Data flow**: View → ViewModel (`@Observable` `@MainActor`) → `Services/API<Domain>.swift` → `LiveNetworkClient` (`http://localhost:8000` + Bearer auth). Get the client via `@Environment(\.networkClient)`; never instantiate `LiveNetworkClient` in a view. `MockNetworkClient` is a test/preview stub that `fatalError`s — there is no runtime mock fallback and the bundled mock dataset was deleted.
- **Navigation**: `Models/Enums.swift` `SidebarSection` + `AppRoute` drive everything; `Views/AppShell/StrategyLabRootView` keeps Strategy/AI Research/Growth subviews alive across navigation.
- **New API endpoint** → add a typed `Response` Codable + method in the matching `Services/API<Domain>.swift`. New domain types → `Models/Types.swift`; new enums → `Models/Enums.swift`.
- **L10n**: every user-visible string goes through `L10n.<Domain>` keys in `Localization/L10n+<Domain>.swift` (`static var foo: String { zh("中文", en: "English") }`). Never hardcode UI strings; use `L10nText(...)` for reactive re-render on language switch.
- **Design system (ProofAlpha)**: all colors/fonts/spacing/radii from `DesignSystem/DesignTokens.swift` (`PulseColors/PulseFonts/PulseSpacing/PulseRadii`); check `ViewModifiers.swift` before writing one-off styling. `.glassEffect()` must be applied directly to content, not inside `.background()`.
- **canvas-web bundling**: built dist is copied to `macos-app/AlphaLoop/Resources/canvas-web/` and loaded via `Bundle.main`. `Package.swift` uses `.copy()` (NOT `.process()` — it flattens the tree and breaks `index.html` relative paths, root cause of canvas white-screen bugs). Rebuild canvas-web → copy dist → then build Swift app.
- **User guide**: `Services/UserGuide.swift` serves `docs/user-guide/` via a local `python3 -m http.server 4178`. New chapters: HTML under `content/{zh,en}/`, register in `assets/app.js` `NAV`, optionally seed `assets/search-index.json`.

## Testing Guidelines

- Backend: `backend/tests/`, filenames mirror the module under test (`test_<module>.py`), pytest-asyncio for async code. CI enforces coverage ≥ 30%.
- macOS: XCTest in `macos-app/Tests/`. Canvas: vitest + `@testing-library/react` + `happy-dom`.
- CI (`.github/workflows/ci.yml`): backend pytest w/ coverage on Python 3.11 + `swift build` on `macos-latest`.

## Commit & PR Conventions

Conventional Commits with scopes — `feat(macos): ...`, `fix(backend): ...`, `docs: ...`. Common scopes: `backend`, `macos`, `canvas`. PRs target `main`.

Page redesigns get a spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, committed before implementation; supersede old specs via a `Supersedes:` frontmatter line instead of deleting them.

**Reply language**: respond to the user in Chinese; keep code, identifiers, and committed docs in English.
