# Phase 4: Canvas 持久化 + 一键部署 Implementation Plan

**Goal:** Enable saving/loading canvas workflow graphs to the backend and one-click deploy from canvas to Freqtrade.

---

## Task 1: Backend Canvas CRUD

**Files:**
- Modify: `backend/app/routers/strategies.py`
- Modify: `backend/app/models/strategy.py` (add CanvasWorkflow model)
- Create: `backend/tests/test_canvas_crud.py`

Add 3 endpoints:
- `POST /api/strategies/{id}/canvas` — save workflow graph
- `GET /api/strategies/{id}/canvas` — load workflow graph
- `PUT /api/strategies/{id}/canvas` — update workflow graph

---

## Task 2: App APICanvas Service

**Files:**
- Create: `macos-app/PulseDesk/Services/APICanvas.swift`

API service for canvas CRUD + deploy.

---

## Task 3: Canvas Auto-Save

**Files:**
- Modify: `macos-app/PulseDesk/ViewModels/CanvasViewModel.swift`

Add auto-save with 3s debounce when graph changes. Load on init.

---

## Task 4: One-Click Deploy UI

**Files:**
- Create: `macos-app/PulseDesk/Views/Canvas/CodePreviewSheet.swift`
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift`

Add "生成并部署" button that generates code, shows preview, then deploys.

---

## Task 5: Build Verification
