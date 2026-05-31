# Progress

## 2026-05-28 — Phase 1-4 remaining work execution

### Phase 1: Core MVP Trading Loop — Gating

- [x] Backend pytest infrastructure + isolated test DB (conftest.py)
- [x] DataSourceStatus metadata schema defined
- [x] FreqtradeClient hardened (settings-driven auth, `ping()`, typed `is_success()`)
- [x] FreqtradeDB hardened (schema detection `is_available()`, typed `source_status()`)
- [x] Strategy-to-Freqtrade adapter (`strategy_registry.py`)
- [x] Deterministic simulated backtest fallback with `simulated=true`
- [x] DataSourceBadge frontend component exists
- [ ] Wire DataSourceStatus through ALL API responses (dashboard, orders, backtest, system)
- [ ] Wire DataSourceBadge into remaining frontend surfaces

### Phase 2: Risk, SHAP, Attribution, Sentiment

- [x] RiskEvent/CorrelationSnapshot models
- [x] Risk rules service with unit tests (18 tests)
- [x] SHAP attribution persistence API (POST/GET /attribution/reports)
- [x] Slippage attribution service + API + tests (9 tests)
- [x] Sentiment data persistence + FinBERT adapter
- [x] Telegram notifier with dry-run tests (7 tests)
- [x] Frontend RiskSettings wired to Zustand store
- [ ] Scheduled risk evaluation hook (background task)
- [ ] Fix frontend attribution/sentiment to query real persisted data

### Phase 3: AI Lab, Forecasting, Factors, FreqAI

- [x] RAG KnowledgeDocument/KnowledgeChunk DB models
- [x] Retrieval scoring + tests (9 tests)
- [x] AST safety scanner + tests (13 tests)
- [x] Generated strategy artifact model
- [x] Generated strategy backtest handoff endpoint
- [x] TimesFM/Chronos adapter boundaries (stubs)
- [x] Qlib factor service boundary (POST /api/ai/factors/research)
- [x] FreqAI training endpoint (POST /api/ai/freqai/train)
- [ ] Wire RAG /rag/generate to use DB persistence (not in-memory)
- [ ] Add FreqAI status/runs GET endpoints
- [ ] Create frontend Forecast, Factor, FreqAI pages + sidebar nav
- [ ] Wire real TimesFM/Chronos inference (requires pip install)

### Phase 4: Multi-Market

- [x] MarketRegistry with crypto/us_stock/a_share
- [x] Market validation in strategy create/update
- [ ] Frontend MarketSelector component with constraints disclosure

### Verification

- [x] Backend tests 59/59 passed
- [x] TypeScript `tsc --noEmit` clean
- [x] ESLint clean
- [x] Production build succeeds
- [ ] Post-change: re-run all tests + lint + typecheck + build
