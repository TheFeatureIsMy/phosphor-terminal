# Strategy Create & Detail Redesign — Design Spec

**Date:** 2026-05-31
**Status:** Approved
**Scope:** StrategiesListView, StrategyCreateSheet, StrategyDetailView — navigation and creation flow

## Problem

1. **Detail page uses `.sheet()`** — system-native modal card breaks ProofAlpha immersive dark theme. Canvas is cramped in a sheet. No navigation context.
2. **Create flow uses `.sheet()`** — 480px fixed modal, form-centric, no connection to canvas workflow.
3. **Strategy type is confusing** — mixing trading logic (MA cross/breakout/grid/mean reversion) with creation method (RAG). With canvas visual graphs, a single type label can't describe what the strategy does.

## Target State

Production-grade creation and detail navigation that matches the ProofAlpha design system.

- Detail page: **route push** instead of sheet, full-width canvas workspace
- Create flow: **mode switcher** — manual quick form or AI chat conversation
- Strategy type: **removed**, replaced by optional user-defined tags for organization
- AI generation: ChatGPT-style conversation that produces editable canvas graphs

## Architecture

### Navigation Change

```
Before: StrategiesListView → .sheet(item:) → StrategyDetailView
After:  StrategiesListView → AppRoute.strategyDetail(id) → StrategyDetailView (full page)
```

`AppRoute` gets a new case: `.strategyDetail(id: Int)`. The `AppShellView` route switch renders `StrategyDetailView` full-frame when this route is active.

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `Models/Enums.swift` | Modify | Add `AppRoute.strategyDetail(id:)`, remove `StrategyType` enum (or deprecate) |
| `Models/Types.swift` | Modify | Add `tags: [String]` to `Strategy` model |
| `Views/Strategies/StrategiesListView.swift` | Modify | Replace `.sheet(item:)` with route push; replace create sheet with inline mode switcher |
| `Views/Strategies/StrategyCreateSheet.swift` | **Rewrite** | Replace sheet with inline mode-switcher component |
| `Views/Strategies/StrategyDetailView.swift` | Modify | Remove `TabView` tab "概览", add config bar + breadcrumb nav |
| `State/AppState.swift` | Modify | Add strategyDetail route handling |
| `Views/AppShell/AppShellView.swift` | Modify | Add `.strategyDetail` case in route switch |
| `ViewModels/StrategiesViewModel.swift` | Modify | Remove `showCreateSheet`, add AI chat state |

### Component Tree

```
StrategiesListView
├── Header (stats + "新建策略" button)
├── CreateArea (conditionally visible)
│   ├── ModeSwitcher ("手动创建" | "AI 对话创建")
│   ├── ManualForm (name + market pills + exchange pills + create button)
│   └── AIChatPanel (ChatGPT-style conversation)
└── StrategyCardGrid

StrategyDetailView (pushed via route)
├── NavBar (← 策略列表 / 策略名称)
├── ConfigBar (name, market, exchange, tags — inline editable)
├── TabBar (画布 | 回测 | 交易记录 | 版本)
└── TabContent
```

## Module Designs

### 1. Mode Switcher + Manual Create

A segmented control at the top switches between "手动创建" and "AI 对话创建".

**Manual mode form:**
- Strategy name (text field, monospace font)
- Market (pill selector: 加密/美股/A股)
- Exchange (pill selector: context-dependent on market)
- Hint text: "创建后进入画布，从调色板拖入节点开始构建策略逻辑"
- CTA button: "创建并打开画布 →"

When submitted:
1. POST `/api/strategies` with name, market, exchange
2. On success, `appState.selectedRoute = .strategyDetail(id: newId)`
3. StrategyDetailView opens at canvas tab

### 2. AI Chat Panel (ChatGPT-style)

**Layout:**
- Message list (scrollable)
  - AI messages: left-aligned, purple avatar "🤖", dark bubble
  - User messages: right-aligned, green avatar "👤", accent-tinted bubble
  - Typing indicator: animated dots in AI bubble
- Input area (bottom): text field + "发送" button

**Conversation flow:**
1. AI greeting with capability intro + example prompts
2. User describes strategy in natural language
3. AI shows typing indicator (~1-2s)
4. AI responds with:
   - Parsed parameters (name, market, exchange inferred from description)
   - Mini node graph preview (colored node chips connected by arrows)
   - Three action buttons: "打开画布" / "调整参数" / "重新生成"

**Backend integration:**
- POST `/api/strategies/generate` with `{ prompt: String }`
- Backend calls LLM to parse trading intent → selects nodes from NodeRegistry → builds WorkflowGraph JSON
- Response: `{ strategy: StrategyResponse, graph: WorkflowGraph }`
- Frontend receives graph, can either open directly or let user refine in chat

### 3. Strategy Detail Page (Route Push)

**Navigation bar:**
- "← 策略列表" back button (sets `appState.selectedRoute = .strategies`)
- Breadcrumb: 策略列表 / {strategy.name}

**Config bar (canvas page):**
- Inline editable: name, market pill, exchange pill
- Tags: "添加标签 +" button, shows existing tags as removable pills
- Save status indicator (from CanvasErrorNotifier)

**Tabs:** 画布 | 回测 | 交易记录 | 版本
- Remove "概览" tab (static info is now in config bar)
- Add "版本" tab (future: canvas version history, placeholder for now)

### 4. Tags System (Replaces Strategy Type)

- `Strategy` model gets `tags: [String]` (stored as JSON array in backend)
- Tags displayed as small pills on strategy cards and in detail config bar
- List page: filter by tag via horizontal scrollable tag bar above grid
- Detail page: add/remove tags inline
- Backend: `Strategy` model adds `tags` JSON column, schema updated

### 5. Backend Changes

- `Strategy` model: add `tags` column (JSON, default `[]`)
- `StrategyResponse` schema: add `tags: list[str]`
- `StrategyCreate` schema: remove `type` (or make optional), add `tags: list[str]`
- NEW endpoint: `POST /api/strategies/generate` — AI chat strategy generation
  - Request: `{ prompt: str }`
  - Response: `{ name: str, market: str, exchange: str, tags: [str], graph_json: str }`
  - Uses existing RAG/LLM infrastructure to parse trading intent into NodeRegistry selections

## Design Tokens (ProofAlpha)

- Mode switcher: `bg-surface`, selected state `bg-elevated` + `accent` text
- Pills: inactive `bg-surface` + `border`, active `accent` bg + glow
- Chat bubbles: AI `rgba(168,85,247,0.05)` bg, User `rgba(0,255,157,0.04)` bg
- CTA button: `accent` bg, full width, 12px padding
- Typing dots: 3 dots, staggered animation, `purple` color

## What Gets Removed

- `StrategyType` enum from frontend (Enums.swift) — backend keeps `strategy_type` as internal field for Freqtrade template selection, not exposed to user
- "概览" tab in StrategyDetailView
- `.sheet()` usage for both detail and create
- `showCreateSheet` state in StrategiesViewModel

## Implementation Order

### Phase 1: Navigation + Detail Page (1-2 days)
- Add `AppRoute.strategyDetail(id:)`
- Rewire StrategiesListView to push route instead of sheet
- Update StrategyDetailView (remove 概览, add config bar, add breadcrumb)

### Phase 2: Create Flow (1-2 days)
- Build mode switcher + manual form
- Remove .sheet() from create
- Wire create → detail navigation

### Phase 3: AI Chat (2-3 days)
- Build ChatGPT-style chat UI
- Add backend `/api/strategies/generate` endpoint
- Implement LLM → NodeRegistry → WorkflowGraph pipeline
- Wire chat → canvas flow

### Phase 4: Tags + Cleanup (1 day)
- Add tags to Strategy model (frontend + backend)
- Tag UI in list cards and detail config bar
- Remove/deprecate StrategyType
- Migration: map existing types to tags
