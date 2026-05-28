# Original PRD All Phases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the original PulseDesk/CyberQuant quantitative trading PRD before continuing the AI Research Committee and Agent Signal Hub work.

**Architecture:** Finish the system from the bottom up: first remove fake data from the Phase 1 trading loop, then add risk/event automation, then add attribution/sentiment/RAG/forecast/factor/learning modules behind explicit services and persisted outputs. All LLM or AI outputs must remain advisory until the Freqtrade execution, risk, audit, and user-confirmation layers are reliable.

**Tech Stack:** FastAPI, SQLAlchemy, SQLite first with PostgreSQL-ready models, Freqtrade REST and SQLite integration, CCXT/Freqtrade strategies, React/Tauri frontend, React Query, SHAP/FinBERT/LangChain/TimesFM/Chronos/Qlib/FreqAI as optional phase dependencies.

---

## Priority Rule

Do not implement `docs/superpowers/plans/2026-05-28-ai-research-and-agent-signal-hub.md` until this plan reaches Phase 1-4 acceptance. TradingAgents and AI-Trader integration remain deferred.

## Phase 1: Core MVP Trading Loop

Acceptance:
- `VITE_USE_MOCK=false` can run the app against FastAPI.
- FastAPI can detect Freqtrade availability honestly.
- Dashboard, orders, positions, and equity curve use Freqtrade DB when available and expose mock fallback explicitly.
- Strategy create/update can map to a Freqtrade strategy identifier.
- Backtest endpoint returns real Freqtrade result when available and marks fallback as simulated.
- System status never reports `connected` when Freqtrade is unavailable.

Implementation tasks:
- [ ] Add backend pytest infrastructure and isolated test database.
- [ ] Add `DataSourceStatus` metadata to dashboard/orders/backtest/system responses.
- [ ] Fix `/api/system/status` to report disconnected when Freqtrade is unavailable.
- [ ] Harden `FreqtradeClient` with auth from config, timeout, typed status helpers, and no silent success.
- [ ] Harden `FreqtradeDB` with schema detection for missing `trades` table.
- [ ] Add strategy-to-Freqtrade adapter service for strategy names and generated strategy files.
- [ ] Replace random backtest fallback with deterministic simulated fallback and an explicit `simulated=true` field.
- [ ] Add frontend display of simulated/real data badges where backend reports source metadata.

## Phase 2: Risk, SHAP, Execution Attribution, Sentiment

Acceptance:
- Risk events are persisted from rules, not only mocked.
- Basic stop-loss, take-profit, max-drawdown, correlation warning, and API error rules create `risk_events`.
- SHAP attribution can persist per-trade attribution reports.
- Slippage attribution separates signal price, fill price, spread, impact, latency, and diagnosis.
- Sentiment endpoints can store and serve scored sentiment records.
- Telegram notification remains optional and disabled by default unless configured.

Implementation tasks:
- [ ] Add attribution, slippage, sentiment, and stress-test models.
- [ ] Add risk rules service with deterministic unit tests.
- [ ] Add risk evaluator endpoint and scheduled evaluation hook.
- [ ] Add SHAP attribution persistence API.
- [ ] Add slippage attribution service and API.
- [ ] Add sentiment data persistence and FinBERT adapter boundary.
- [ ] Add optional Telegram notifier service with dry-run tests.
- [ ] Update frontend risk, attribution, and sentiment surfaces to show real persisted outputs.

## Phase 3: AI Strategy Lab, Forecasting, Factor Research, Incremental Learning

Acceptance:
- RAG Strategy Lab supports document upload, chunking, retrieval, strategy generation, AST safety scan, and generated strategy backtest handoff.
- TimesFM and Chronos integrations are adapter-bound and optional.
- Qlib factor research has a native PulseDesk service boundary and stores factor runs.
- FreqAI incremental learning has an explicit training/run status API.
- No generated code is executable until it passes safety scan and user confirmation.

Implementation tasks:
- [ ] Replace current in-memory RAG with persisted document/chunk schema.
- [ ] Add retrieval scoring tests.
- [ ] Add strategy-code generation output model.
- [ ] Add AST safety scanner for generated Freqtrade strategies.
- [ ] Add generated strategy file writer behind a safe directory boundary.
- [ ] Add generated strategy backtest handoff.
- [ ] Add TimesFM adapter boundary and forecast result model.
- [ ] Add Chronos adapter boundary and forecast result model.
- [ ] Add Qlib factor research models and service boundary.
- [ ] Add FreqAI run models and training status API.

## Phase 4: Multi-Market Plugin Layer

Acceptance:
- Market constraints are represented explicitly for crypto, US stocks, and A-shares.
- Crypto Binance plugin is the first production target.
- Alpaca and JoinQuant/RiceQuant plugins exist as adapter boundaries, even if disabled without credentials.
- Strategy creation validates market constraints before execution.

Implementation tasks:
- [ ] Add `MarketPlugin` interface and `MarketConstraints` model.
- [ ] Add `MarketRegistry`.
- [ ] Add Crypto Binance plugin using CCXT or Freqtrade-compatible metadata.
- [ ] Add disabled Alpaca adapter boundary.
- [ ] Add disabled A-share adapter boundary.
- [ ] Add market validation to strategy create/update/backtest.
- [ ] Add frontend market selector with constraints disclosure.

## Execution Order

1. Execute Phase 1 fully.
2. Run backend tests, frontend checks, and Tauri build checks.
3. Execute Phase 2.
4. Execute Phase 3.
5. Execute Phase 4.
6. Only then resume `2026-05-28-ai-research-and-agent-signal-hub.md`.

## Review Notes

- The current app has strong UI coverage but too much mock data. Phase 1 is the gating milestone.
- AI/LLM features should be optional dependency groups to avoid making the base app impossible to run.
- Anything that can influence execution must write an audit record.
- Generated strategies and AI signals are advisory until safety scan, backtest, risk validation, and user confirmation all pass.
