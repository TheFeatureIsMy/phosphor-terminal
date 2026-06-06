# PulseDesk Phases 3-6 Implementation Plan

**Context:** Phases 1-2 are complete (64/64 tests). DSL v3.0, Decision Engine, Structure Engine, Account Risk Firewall, Freqtrade dual-mode all working. Now building the remaining modules: disconnect protection enhancements, AI slow track, position adjustment, and trade review/learning.

**Total:** 13 tasks across 4 phases. Phases 3+4 can run in parallel. Phase 5 follows Phase 4. Phase 6 last.

---

## Phase 3: Disconnect Protection Enhancements (3 tasks)

### 3.1 HeartbeatMonitor
- **Create** `backend/app/services/heartbeat_monitor.py`
- Redis key `pd:runtime:heartbeat:{strategy_id}` with TTL
- `record_heartbeat()`, `check_alive()` → HeartbeatStatus
- Add endpoints to decision router
- Freqtrade: fire-and-forget POST in bot_loop_start
- **Tests:** 4 (fresh/stale/missing/metadata)

### 3.2 ExchangeStopService
- **Create** `backend/app/services/exchange_stop_service.py`
- Place reduce-only stop-market via FreqtradeClient after each fill
- `place_protective_stop()`, `cancel_protective_stop()`, `update_protective_stop()`
- dry_run mode for safety
- **Tests:** 3 (success/failure/update)

### 3.3 Graduated RuntimeSnapshotGuard
- **Update** `freqtrade/user_data/strategies/runtime_snapshot_guard.py`
- 4-state: HEALTHY → DEGRADED (tighten stops 0.7x) → DISCONNECT (block entries) → EMERGENCY (market close)
- Add `detect_reconnection()`, tighten factor config
- Wire HeartbeatMonitor into DegradationPolicy in DecisionEngine
- **Tests:** 5 (graduated states + reconnection + tighten math)

---

## Phase 4: Slow Track AI Risk Cache (4 tasks)

### 4.1 AI Analyzers
- **Create** `backend/app/services/ai_analyzers/` — `base.py`, `news_risk.py`, `whale_risk.py`, `conflict_analysis.py`
- BaseAnalyzer ABC → AnalyzerResult (risk_score, risk_flags, summary)
- Each calls LLMService.chat with structured prompt, parses JSON response
- Graceful fallback on LLM failure (returns conservative defaults)
- **Tests:** 6 (mock LLM, fallback, conflict detection)

### 4.2 AIRiskCacheService
- **Create** `backend/app/services/ai_risk_cache.py`
- Periodically runs all analyzers, aggregates (max risk_score, union flags), writes to Redis
- Uses existing `RuntimeRedisStore.write_ai_cache()`
- Background loop + manual refresh trigger
- **Create** `backend/app/routers/ai_cache.py` — GET/POST endpoints
- **Tests:** 4 (write/read, partial failure, aggregation, endpoint)

### 4.3 AICacheEvaluator
- **Create** `backend/app/services/ai_cache_evaluator.py`
- Pure function: cache dict + DegradationPolicy → AICacheEvaluation (cache_state, action, size_multiplier)
- Maps soft/hard expired to policy actions (reduce_size, block_new_entries, ignore)
- **Tests:** 5 (fresh/missing/soft/hard/policy override)

### 4.4 DecisionEngine AI Integration
- **Update** `backend/app/services/decision_engine.py`
- Call `evaluate_ai_cache()` after reading cache, apply `size_multiplier` to position_size
- If `action == "block_new_entries"`, override to reject_trade
- Set `ai_cache_age_ms` on snapshot
- **Tests:** 3 (fresh normal, missing reduces, hard expired rejects)

---

## Phase 5: Structural Position Adjustment (3 tasks)

### 5.1 PositionCalculator
- **Create** `backend/app/services/position_calculator.py`
- `position_size = risk_budget / |entry - stop|`
- Clamp to max_position_pct, apply ai_size_multiplier, leverage
- Fallback to fixed_pct when stop distance too small
- **Tests:** 5 (basic sizing, clamped, multiplier, zero distance, leverage)

### 5.2 AddPositionValidator + BlendedEntry
- **Create** `backend/app/services/add_position_validator.py` + `backend/app/services/blended_entry.py`
- 7 constraints from design doc: DCA policy, structure valid, breakeven met, risk budget, R:R, liq distance, max count
- Uses existing `AddPositionPolicy` from `domain/dsl.py`
- Pure functions, no side effects
- **Tests:** 8 (valid, DCA rejected, structure invalid, breakeven, risk, R:R, liq, max count)

### 5.3 DecisionEngine + Freqtrade Integration
- **Update** snapshot model: add `"allow_add_position"` to ExecutionPlan.decision
- **Update** DecisionEngine: new `evaluate_add_position()` method
- **Update** Freqtrade: implement `adjust_trade_position` reading add-position from snapshot
- **Tests:** 2 (allowed/rejected snapshot)

---

## Phase 6: Trade Review & Learning (3 tasks)

### 6.1 TradeReviewer (AI-powered)
- **Create** `backend/app/services/trade_reviewer.py`
- Uses LLMService to analyze snapshot context + trade outcome
- Generates TradeReview with ai_assessment, identified_labels, improvement_suggestion
- Wraps existing GrowthService findings pipeline
- **Tests:** 3 (review trade, snapshot context, LLM failure)

### 6.2 LabelGenerator (deterministic)
- **Create** `backend/app/services/label_generator.py`
- Rule-based labels: good_structure_entry, entered_before_reclaim, stop_too_close, ai_cache_expired, disconnect_emergency_close, etc.
- Writes to existing `trade_learning_labels` table
- **Tests:** 5 (each label rule + persistence)

### 6.3 FailureClustering
- **Create** `backend/app/services/failure_clustering.py`
- Groups losing trades by failure label, sorts by total_loss
- Maps clusters to optimization suggestions
- **Create** growth router endpoints for labels/clusters
- **Tests:** 5 (single/multi cluster, empty, sorted, suggestions)

---

## Key Reuse Points
- `LLMService` (existing) — all Phase 4+6 AI calls
- `RuntimeRedisStore` (existing) — heartbeat + AI cache keys
- `AddPositionPolicy` (existing DSL) — all Phase 5 constraint values
- `DegradationPolicy` (existing DSL) — Phase 4 cache evaluation
- `GrowthService` (existing) — Phase 6 review pipeline
- `trade_learning_labels` table (existing) — Phase 6 label storage
- `FreqtradeClient` (existing) — Phase 3 exchange stop orders

## Verification
After all phases:
```bash
cd backend && .venv/bin/python -m pytest tests/ -v  # all tests pass
cd canvas-web && npx tsc --noEmit                   # clean compile
```
