# Phase 3: AI 功能域 Implementation Plan

**Goal:** Create Sentiment, Attribution, and AI Providers views with their API services, and fix the Forecast mock data issue.

---

## Task 1: Sentiment API + View

**Files:**
- Create: `macos-app/PulseDesk/Services/APISentiment.swift`
- Create: `macos-app/PulseDesk/Views/Sentiment/SentimentView.swift`
- Create: `macos-app/PulseDesk/Views/Sentiment/FearGreedGauge.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift` (replace placeholder)

Backend endpoints:
- `GET /sentiment/summary` → `{fear_greed_index, fear_greed_label, market_overview, updated_at}`
- `GET /sentiment/market/{symbol}?days=N` → sentiment history
- `POST /sentiment/analyze` → `{text}` → sentiment scores

---

## Task 2: Attribution API + View

**Files:**
- Create: `macos-app/PulseDesk/Services/APIAttribution.swift`
- Create: `macos-app/PulseDesk/Views/Attribution/AttributionView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift` (replace placeholder)

Backend endpoints:
- `POST /attribution/feature-importance` → `{features, values, strategy_type}` → SHAP values
- `GET /attribution/slippage` → slippage list
- `GET /attribution/reports` → report list

---

## Task 3: AI Providers API + View

**Files:**
- Create: `macos-app/PulseDesk/Services/APIAIProviders.swift`
- Create: `macos-app/PulseDesk/Views/AIProviders/AIProvidersView.swift`
- Create: `macos-app/PulseDesk/Views/AIProviders/ProviderCardView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift` (replace placeholder)

Backend endpoints:
- `GET /api/ai/providers` → provider list
- `POST /api/ai/providers/test` → test connectivity
- `GET /api/ai/models/status` → ML model status

---

## Task 4: Fix Forecast Mock Data

**Files:**
- Modify: `macos-app/PulseDesk/Views/AIStudio/ForecastSectionView.swift`

Remove the mock data generation when API returns empty points (lines 192-208). Show empty state instead.

---

## Task 5: Risk View (placeholder → real)

**Files:**
- Create: `macos-app/PulseDesk/Views/Risk/RiskView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

Simple risk view showing risk events list + summary from existing API.

---

## Task 6: Build Verification

Run `swift build` and `pytest`.
