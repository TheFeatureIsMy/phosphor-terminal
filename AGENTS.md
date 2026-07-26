# Repository Guidelines

AlphaLoop (phosphor-terminal) is an AI-driven crypto quant trading dashboard composed of three independent codebases that communicate only via HTTP API. The product defaults to Chinese (zh-CN) with a dark cyberpunk theme.

## Project Structure & Module Organization

```
phosphor-terminal/
├── backend/        Python 3.11 · FastAPI · SQLAlchemy · Pydantic v2
│   ├── app/        routers/, services/, schemas/, domain/, models/, workers/
│   └── tests/      ~91 pytest files mirroring service/router names
├── macos-app/      Swift 6.2 · SwiftUI · macOS 26+ (no SPM deps)
│   ├── AlphaLoop/  DesignSystem/, Views/, ViewModels/, Services/, Localization/
│   └── Tests/      XCTest target
├── canvas-web/     React 19 · Vite · @xyflow/react strategy DAG editor
│   └── src/        nodes/, edges/, hooks/, converters/
├── docs/           architecture/, product/, planning/, integrations/
├── scripts/        build-backend.sh
└── docker-compose.yml
```

## Build, Test, and Development Commands

**Backend** (`backend/`):
- `python3 run.py` — start FastAPI on `:8000`
- `python3 -m pytest tests/ -q --cov=app` — run tests with coverage (CI gate ≥ 30%)
- `python3 -m pytest tests/test_risk_rules.py -q -k "structure"` — single file / name filter

**macOS App** (`macos-app/`):
- `swift build && swift run` — build and launch AlphaLoop
- `swift test` — run XCTest target (use `run-tests.sh` if framework paths are needed)

**Canvas Web** (`canvas-web/`):
- `npm run dev` — Vite dev server on `:5173`
- `npm run build` — `tsc && vite build`
- `npm test` — run vitest

**Docker full stack**: `docker compose up` (postgres, redis, backend, freqtrade)

## Coding Style & Naming Conventions

- **Backend**: Python 3.11+ (CI runs 3.11). Use async/await with pytest-asyncio. Routers are thin handlers — delegate business logic to `services/`. Pydantic v2 schemas in `schemas/`; domain enums in `domain/enums.py`.
- **Canvas**: TypeScript strict mode (`tsconfig.json`), React 19, functional components.
- **macOS**: Pure SwiftUI + Foundation, no third-party SPM dependencies.

## Testing Guidelines

- Backend tests live in `backend/tests/`; filenames mirror the module under test (`test_<module>.py`). CI enforces `--cov-fail-under=30`.
- macOS tests use XCTest in `macos-app/Tests/`.
- Canvas tests use vitest with `@testing-library/react` and `happy-dom`.

## Commit & Pull Request Guidelines

This project uses **Conventional Commits** with scopes:

```
feat(macos): add circuit breakers view
fix(backend): source risk rules from DB table
refactor(macos): extract atmosphericBackground modifier
docs: update CLAUDE.md
```

Common scopes: `backend`, `macos`, and top-level types `feat`, `fix`, `refactor`, `docs`, `test`, `chore`. PRs should target `main` and include a clear description; CI runs backend tests + coverage and macOS `swift build` on every push.

## Agent-Specific Instructions

- **canvas-web bundling**: `Package.swift` uses `.copy()` (not `.process()`) for the `canvas-web` resource directory — `.process()` flattens the structure and breaks `index.html` relative paths. After rebuilding canvas-web, copy dist output to `macos-app/AlphaLoop/Resources/canvas-web/` before building the Swift app.
- **Three-tier BFF pattern**: routers fall back Redis → service computation → mock data. Preserve this when adding BFF endpoints.
- **Freqtrade dual-channel**: REST (`freqtrade_client.py`) for control, direct SQLite (`freqtrade_db.py`) for trade history. Do not conflate.
- See `CLAUDE.md` and `docs/README.md` for deeper architecture and conventions.
