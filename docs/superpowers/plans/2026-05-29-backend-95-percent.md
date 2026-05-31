# Backend 95% PRD Completion Plan

> **Date:** 2026-05-29
> **Goal:** Complete ALL PRD [ ] items for backend, then macOS app integration

## Current State Assessment

After thorough code audit, many PRD checkboxes are **stale** — the code already implements them. Here's the TRUE remaining work:

### Backend — Actually Done (PRD checkboxes not updated)
- Strategy deploy endpoint ✅ (strategies.py:101)
- Backtest persistence ✅ (BacktestRun model + backtest.py)
- Notification DB ✅ (NotificationRecord + notifications.py)
- compute_correlations ✅ (freqtrade_db.py:136-189, real Pearson)
- FreqAI worker exists ✅ (freqai_worker.py, started in main.py)
- Strategy type-aware code gen ✅ (4 types: ma_cross, breakout, mean_reversion, grid)
- Strategy file cleanup ✅ (delete_strategy_file() called on DELETE)

### Backend — Real Gaps to Fix

#### Task Group A: Bug Fixes & Hardening (parallel-safe)

**A1: Fix deploy_strategy error handling**
- File: `backend/app/routers/strategies.py:118-122`
- Bug: Sets `status = "active"` regardless of whether `start_bot()` succeeds or fails
- Fix: Set "active" only on success, "error" on failure

**A2: Fix _periodic_risk_evaluation raw SQL**
- File: `backend/app/main.py:17-46`
- Issue: Uses raw SQL `text("SELECT symbol, unrealized_pnl_pct FROM trades WHERE is_open = 1")` instead of `freqtrade_db.get_open_trades()`
- Fix: Refactor to use the existing method

**A3: Fix KnowledgeChunk missing FK**
- File: `backend/app/models/ai.py:27`
- Issue: `document_id = Column(Integer, nullable=False, index=True)` — no ForeignKey
- Fix: Add `ForeignKey("knowledge_documents.id")`

**A4: Wire DataSourceStatus through remaining API responses**
- Files: dashboard.py, orders.py, backtest.py, risk.py, sentiment.py
- Issue: Some responses lack `data_source` field
- Fix: Ensure all data-returning endpoints include DataSourceStatus

#### Task Group B: Feature Enhancements (parallel-safe)

**B1: Enhance FreqAI worker with real training simulation**
- File: `backend/app/services/freqai_worker.py`
- Issue: Returns hardcoded metrics after 2s sleep
- Fix: Add configurable training simulation with progress tracking, realistic metrics based on config

**B2: Fix generated strategy backtest to try real Freqtrade**
- File: `backend/app/routers/ai_phase3.py:112-142`
- Issue: Always calls `_generate_simulated_backtest()`, never tries real
- Fix: Try `freqtrade_client.run_backtest()` first, fall back to simulated

**B3: Add async submit+poll to FreqtradeClient.run_backtest()**
- File: `backend/app/services/freqtrade_client.py:61-62`
- Issue: Single synchronous POST, no polling for long backtests
- Fix: Add `submit_backtest()` + `poll_backtest()` methods

**B4: Add generated strategy file writer**
- File: `backend/app/routers/ai_phase3.py` + `backend/app/services/strategy_registry.py`
- Issue: Generated strategy code only stored in DB, not written to disk for Freqtrade
- Fix: After safety scan passes, write strategy file to Freqtrade strategies directory

#### Task Group C: Tests (parallel-safe)

**C1: Add tests for auth endpoints**
- register, login, refresh, settings CRUD

**C2: Add tests for strategies endpoints**
- CRUD, deploy, stop

**C3: Add tests for RAG endpoints**
- upload, search, generate, knowledge list

**C4: Add tests for AI phase3 endpoints**
- forecast, factors, freqai, generated strategy backtest

### macOS App Integration (after backend)

**D1: Switch to LiveNetworkClient**
- File: `macos-app/PulseDesk/PulseDeskApp.swift`
- Change: Replace `MockNetworkClient()` with `LiveNetworkClient()`
- Add: Environment-based toggle for mock/live

**D2: Implement real auth flow**
- Files: AuthState.swift, PulseDeskApp.swift
- Add: Real register/login/JWT token storage in Keychain

**D3: Wire ViewModels to real APIs**
- Files: DashboardViewModel, StrategiesViewModel, BacktestViewModel
- Change: API services already have the right endpoints, just need live client

**D4: Wire AI Studio views to real APIs**
- Files: RAGLabSectionView, ForecastSectionView, FactorResearchSectionView, FreqAISectionView
- Change: Replace `Task.sleep` + hardcoded data with real API calls

**D5: Add DataSourceBadge to UI**
- Add badge to dashboard KPIs, orders, backtest results

**D6: Integrate MarketSelector into strategy forms**
- Wire existing MarketSelector into StrategyCreateSheet

## Execution Order

Phase 1: Task Groups A + B + C in parallel (backend)
Phase 2: Task Group D (macOS app, sequential after backend)
