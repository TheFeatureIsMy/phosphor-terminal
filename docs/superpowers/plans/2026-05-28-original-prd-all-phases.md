# Original PRD All Phases Implementation Plan (Remaining Work)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the original PulseDesk/CyberQuant quantitative trading PRD before continuing the AI Research Committee and Agent Signal Hub work.

**Architecture:** Finish the system from the bottom up: first remove fake data from the Phase 1 trading loop, then add risk/event automation, then add attribution/sentiment/RAG/forecast/factor/learning modules behind explicit services and persisted outputs. All LLM or AI outputs must remain advisory until the Freqtrade execution, risk, audit, and user-confirmation layers are reliable.

**Tech Stack:** FastAPI, SQLAlchemy, SQLite first with PostgreSQL-ready models, Freqtrade REST and SQLite integration, CCXT/Freqtrade strategies, React/Tauri frontend, React Query, SHAP/FinBERT/LangChain/TimesFM/Chronos/Qlib/FreqAI as optional phase dependencies.

---

## Priority Rule

Do not implement `docs/superpowers/plans/2026-05-28-ai-research-and-agent-signal-hub.md` until this plan reaches Phase 1-4 acceptance. TradingAgents and AI-Trader integration remain deferred.

## Phase 1: Core MVP Trading Loop

**Acceptance:**
- [x] `VITE_USE_MOCK=false` can run the app against FastAPI.
- [x] FastAPI can detect Freqtrade availability honestly.
- [x] Dashboard, orders, positions, and equity curve use Freqtrade DB when available and expose mock fallback explicitly.
- [x] Strategy create/update can map to a Freqtrade strategy identifier.
- [x] Backtest endpoint returns real Freqtrade result when available and marks fallback as simulated.
- [x] System status never reports `connected` when Freqtrade is unavailable.
- [x] **Strategy can be deployed to Freqtrade and transition to `active` status.** — `POST /{id}/deploy` calls `freqtrade_client.start_bot()`, sets status. Error handling: sets "error" on failure.
- [x] **Backtest results are persisted to DB and retrievable by ID.** — `BacktestRun` model + `POST /api/backtest` persists + `GET /{id}` retrieves.

**Implementation tasks:**
- [x] Add backend pytest infrastructure and isolated test database.
- [x] Add `DataSourceStatus` metadata to dashboard/orders/backtest/system responses.
- [x] Fix `/api/system/status` to report disconnected when Freqtrade is unavailable.
- [x] Harden `FreqtradeClient` with auth from config, timeout, typed status helpers, and no silent success.
- [x] Harden `FreqtradeDB` with schema detection for missing `trades` table.
- [x] Add strategy-to-Freqtrade adapter service for strategy names and generated strategy files.
- [x] Replace random backtest fallback with deterministic simulated fallback and an explicit `simulated=true` field.
- [x] Add frontend display of simulated/real data badges where backend reports source metadata.
- [x] Add `POST /api/strategies/{id}/deploy` endpoint — transitions status, calls `freqtrade_client.start_bot()`. Sets "error" on failure.
- [x] Add `BacktestResult` model + persist backtest runs to DB. Fix `GET /backtest/{id}` to retrieve real results.
- [x] Add `submit_backtest()` + `poll_backtest(job_id)` async methods to FreqtradeClient.
- [x] Add frontend `deployStrategy()` action — APIStrategies.deploy() wired via StrategiesViewModel.
- [x] Add `DataSourceBadge` component to Dashboard, Backtest, Orders, Positions views.
- [x] Add `MarketSelector` (crypto/us_stock/a_share) to StrategyCreateSheet with constraint notes.

## Phase 2: Risk, SHAP, Execution Attribution, Sentiment

**Acceptance:**
- [x] Risk events are persisted from rules, not only mocked.
- [x] Basic stop-loss, take-profit, max-drawdown, correlation warning, and API error rules create `risk_events`.
- [x] SHAP attribution can persist per-trade attribution reports.
- [x] Slippage attribution separates signal price, fill price, spread, impact, latency, and diagnosis.
- [x] Sentiment endpoints can store and serve scored sentiment records.
- [x] Telegram notification remains optional and disabled by default unless configured.
- [x] **Correlation endpoint returns real computed data from trade history.** — `freqtrade_db.compute_correlations()` with real Pearson, persisted to `correlation_snapshots`. Falls back to mock only when no trade data.
- [x] **Notifications are DB-persisted and survive restarts.** — `NotificationRecord` model + notifications.py router uses DB.
- [x] **Risk evaluation runs on real portfolio positions.** — `_periodic_risk_evaluation` uses `freqtrade_db.get_open_trades()`.

**Implementation tasks:**
- [x] Add attribution, slippage, sentiment, and stress-test models.
- [x] Add risk rules service with deterministic unit tests.
- [x] Add risk evaluator endpoint and scheduled evaluation hook.
- [x] Add SHAP attribution persistence API.
- [x] Add slippage attribution service and API.
- [x] Add sentiment data persistence and FinBERT adapter boundary.
- [x] Add optional Telegram notifier service with dry-run tests.
- [x] Update frontend risk, attribution, and sentiment surfaces to show real persisted outputs.
- [x] Add `Notification` DB model. Notifications router uses `NotificationRecord` DB model.
- [x] Add `freqtrade_db.compute_correlations()` — pairwise Pearson from trade history.
- [x] Fix `_periodic_risk_evaluation` in main.py to use `freqtrade_db.get_open_trades()` instead of raw SQL.
- [x] Wire `DataSourceStatus` through correlation and sentiment API responses.

## Phase 3: AI Strategy Lab, Forecasting, Factor Research, Incremental Learning

**Acceptance:**
- [x] RAG Strategy Lab supports document upload, chunking, retrieval, strategy generation, AST safety scan, and generated strategy backtest handoff.
- [x] TimesFM and Chronos integrations are adapter-bound and optional.
- [x] Qlib factor research has a native PulseDesk service boundary and stores factor runs.
- [x] FreqAI incremental learning has an explicit training/run status API.
- [x] No generated code is executable until it passes safety scan and user confirmation.
- [x] **FreqAI background worker actually processes queued training runs.** — `freqai_worker.py` polls queued runs, simulates training with progress updates and model-specific metrics.
- [x] **Generated strategy code is written to disk for Freqtrade to load.** — After safety scan passes, code written to `freqtrade/user_data/strategies/`.

**Implementation tasks:**
- [x] Replace current in-memory RAG with persisted document/chunk schema.
- [x] Add retrieval scoring tests.
- [x] Add strategy-code generation output model.
- [x] Add AST safety scanner for generated Freqtrade strategies.
- [x] Add generated strategy file writer behind a safe directory boundary.
- [x] Add generated strategy backtest handoff — tries real Freqtrade first, falls back to simulated.
- [x] Add TimesFM adapter boundary and forecast result model.
- [x] Add Chronos adapter boundary and forecast result model.
- [x] Add Qlib factor research models and service boundary.
- [x] Add FreqAI run models and training status API.
- [x] Add FreqAI background worker — asyncio task with progress tracking and model-specific metrics.
- [x] `strategy_registry.render_freqtrade_strategy()` respects `strategy_type` (ma_cross, breakout, mean_reversion, grid).
- [x] Strategy file cleanup on delete — `delete_strategy_file()` called in DELETE endpoint.

## Phase 4: Multi-Market Plugin Layer

**Acceptance:**
- [x] Market constraints are represented explicitly for crypto, US stocks, and A-shares.
- [x] Crypto Binance plugin is the first production target.
- [x] Alpaca and JoinQuant/RiceQuant plugins exist as adapter boundaries, even if disabled without credentials.
- [x] Strategy creation validates market constraints before execution.
- [x] **Frontend market selector is integrated into strategy create/edit forms.** — `StrategyCreateSheet` has market picker with constraint notes.

**Implementation tasks:**
- [x] Add `MarketPlugin` interface and `MarketConstraints` model.
- [x] Add `MarketRegistry`.
- [x] Add Crypto Binance plugin using CCXT or Freqtrade-compatible metadata.
- [x] Add disabled Alpaca adapter boundary.
- [x] Add disabled A-share adapter boundary.
- [x] Add market validation to strategy create/update/backtest.
- [x] Add frontend market selector with constraints disclosure.
- [x] Integrate `MarketSelector` component into strategy create/edit form.

## Execution Order (Revised Priority)

### Critical Path — Must Complete
1. Strategy deploy endpoint (#1) — blocks live trading
2. Backtest persistence (#2) — blocks backtest history
3. FreqAI background worker (#3) — blocks AI training
4. Notification DB persistence (#4) — data loss on restart
5. Real correlation computation (#5) — risk dashboard is fake

### Important — Complete After Critical
6. Frontend deploy action + wire into UI
7. Frontend market selector integration
8. Fix risk evaluation to use real positions
9. Strategy type-aware code generation
10. Strategy file cleanup on delete

### Infrastructure — Complete Last
11. CI/CD (GitHub Actions)
12. Test coverage gate

## Review Notes

- The current app has strong UI coverage but too much mock data. Phase 1 is the gating milestone.
- AI/LLM features should be optional dependency groups to avoid making the base app impossible to run.
- Anything that can influence execution must write an audit record.
- Generated strategies and AI signals are advisory until safety scan, backtest, risk validation, and user confirmation all pass.
