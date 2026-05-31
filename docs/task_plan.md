# Task Plan — Phase 1-4 Remaining Work

Execution order: Phase 1 gating → Phase 2 → Phase 3 → Phase 4 → Verification.

## Task 1: Wire DataSourceStatus through API responses (Phase 1)

**Why**: Without this, DataSourceBadge is useless — UI can't tell if data is real or simulated.

**Steps**:
1. Add `data_source` field to every Pydantic response schema for: backtest, system status, dashboard KPIs, positions, orders
2. In each router, pass DB/Client `source_status()` result through the response
3. Verify with test calls

**Files**:
- `backend/app/schemas/` (dashboard, system, backtest, etc.)
- `backend/app/routers/` (dashboard, system, backtest, orders, positions)

## Task 2: Wire frontend DataSourceBadge (Phase 1)

**Why**: Badge component exists but doesn't show on all relevant surfaces.

**Steps**:
1. Add `data_source` prop passing through Dashboard KPI cards
2. Add to Orders table / BacktestResults

## Task 3: Wire RAG to DB persistence (Phase 3 — Critical)

**Why**: `/rag/generate` uses in-memory `_knowledge_store`, not DB. Uploaded documents are lost on restart.

**Steps**:
1. Update `rag_service.py` to use `db_session` queries instead of in-memory dict
2. Update `POST /rag/upload` to persist chunks to DB via `KnowledgeChunk`
3. Update `POST /rag/generate` to query DB chunks

## Task 4: Fix frontend attribution/sentiment to use real data (Phase 2)

**Why**: SentimentDashboard and SHAPChart show random mock data instead of API results.

**Steps**:
1. Update `SentimentDashboard` to call `GET /sentiment/records` instead of `/sentiment/summary`
2. Update `SHAPChart` to call `GET /attribution/reports` instead of hardcoded random
3. Add fallback: if API returns empty, show "no data" state

## Task 5: Add scheduled risk evaluation hook (Phase 2)

**Why**: Risk rules need periodic evaluation to detect threats in real time.

**Steps**:
1. Add APScheduler or simple FastAPI lifespan background task
2. Schedule `evaluate_risk_rules()` every 60s
3. Log evaluations

## Task 6: Add FreqAI status GET endpoints (Phase 3)

**Why**: Can start training but can't check results.

**Steps**:
1. Add `GET /api/ai/freqai/status` — latest run status
2. Add `GET /api/ai/freqai/runs` — list all runs

## Task 7: Create frontend MarketSelector (Phase 4)

**Why**: Backend markets exist; frontend has no way to select or display them.

**Steps**:
1. Create `MarketSelector.tsx` component
2. Call `GET /api/markets` on mount
3. Display constraints and enabled/disabled state per market

## Task 8: Create frontend Forecast/Factor/FreqAI pages (Phase 3)

**Why**: Backend endpoints exist but no UI.

**Steps**:
1. Create `ForecastPage.tsx`
2. Create `FactorResearchPage.tsx`
3. Create `FreqAIPage.tsx`
4. Add routes and sidebar nav items

## Task 9: Verification

**Steps**:
1. `pytest backend/tests/ -q`
2. `tsc --noEmit`
3. `npm run lint`
4. `npm run build`
