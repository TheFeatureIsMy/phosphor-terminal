# StrategyCanvasTab & Notification System — Design Spec

**Date:** 2026-05-29
**Status:** Draft
**Scope:** StrategyCanvasTab node-based workflow editor + complete notification system

---

## 1. Overview

### Goal
Build a Dify/ComfyUI-inspired node-based workflow canvas for PulseDesk's strategy editor, plus a complete notification system with bell icon, popover, and toast integration.

### Phased Delivery
- **Phase 1:** Notification bell (complete system) + Canvas with visual configuration (save/load/serialize, code generation)
- **Phase 2:** Direct execution (backend DAG executor, real-time node status)

### Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering | Hybrid: SwiftUI Canvas (connections/background) + SwiftUI Views (node bodies) | Reuse DesignSystem components, native controls in nodes |
| Node scope | 65+ nodes, 5 categories | Full coverage: data sources, signal processing, decision, AI, output |
| Data flow | Variable pool (Dify model) | Decouples topology from data contracts |
| Execution | Phase 1: visual config → code gen; Phase 2: direct execution | Incremental complexity |

---

## 2. Architecture

### Layer Structure

```
Views Layer
  StrategyCanvasTab / NodeView / ConnectionView
  NodeConfigPanel / NotificationPopover / MiniMapView
ViewModel Layer
  CanvasViewModel (@Observable)
    - graph: WorkflowGraph
    - selectedNodeId / draggingState / viewport
  NotificationViewModel (@Observable)
    - notifications / unreadCount
Model Layer
  WorkflowGraph / CanvasNode / CanvasEdge
  NodeDefinition / PortDefinition / VariableRef
  AppNotification / NotificationType
Services Layer
  NodeRegistry / WorkflowExecutor / GraphSerializer
  APINotifications / ToastManager
```

### Data Models

```swift
// WorkflowGraph — the canvas state
struct WorkflowGraph: Codable {
    var nodes: [CanvasNode]
    var edges: [CanvasEdge]
    var groups: [NodeGroup]
    var viewport: ViewportState
}

struct CanvasNode: Codable, Identifiable {
    let id: UUID
    let nodeType: NodeType           // e.g. "data.kline", "indicator.rsi"
    var position: CGPoint
    var size: CGSize
    var config: [String: AnyCodable] // node configuration parameters
    var widgetValues: [String: AnyCodable] // current widget values
    var isCollapsed: Bool
    var isDisabled: Bool
}

struct CanvasEdge: Codable, Identifiable {
    let id: UUID
    let sourceNodeId: UUID
    let sourcePort: String
    let targetNodeId: UUID
    let targetPort: String
    let dataType: PortDataType
}

struct NodeGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var color: Color
    var nodeIds: [UUID]
}

struct ViewportState: Codable {
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
}

// Port types — determine wire color and connection compatibility
enum PortDataType: String, Codable {
    case ticker, kline, orderbook, indicator, signal, position
    case text, number, boolean, array, object
    case llmOutput, sentiment, riskMetric, macro
    case onchain, fundingRate, liquidation
}

// Variable reference for data passing between nodes
struct VariableRef: Codable {
    let nodeId: UUID
    let variableName: String
}

// Variable pool for execution
struct VariablePool {
    var storage: [String: Any]  // "nodeId.variableName" -> value
}
```

### Node Definition Registry

```swift
struct NodeDefinition {
    let type: NodeType
    let category: NodeCategory    // data, signal, decision, ai, output
    let name: String              // display name (Chinese)
    let icon: String              // SF Symbol
    let color: Color              // node theme color
    let inputPorts: [PortDefinition]
    let outputPorts: [PortDefinition]
    let configSchema: [ConfigField]    // right panel fields
    let widgetDefinitions: [WidgetDefinition] // inline node widgets
}

struct PortDefinition {
    let name: String
    let dataType: PortDataType
    let isRequired: Bool
    let allowsMultiple: Bool      // can connect multiple edges
}

enum NodeCategory: String, CaseIterable {
    case data      // cyan
    case signal    // purple
    case decision  // amber
    case ai        // accent green
    case output    // danger red
}
```

---

## 3. Node Type System

### 3.1 Data Source Nodes (25 nodes)

| Type | Outputs | Config | Description |
|------|---------|--------|-------------|
| `data.kline` | ticker, kline[] | exchange, symbol, timeframe | OHLCV price data |
| `data.orderbook` | orderbook | exchange, symbol, depth | Order book depth |
| `data.funding` | fundingRate | exchange, symbol | Funding rate |
| `data.liquidation` | liquidation[] | exchange, threshold | Liquidation events |
| `data.openInterest` | oi | exchange, symbol | Open interest |
| `data.onchain.tvl` | tvl | chain, protocol | Protocol TVL |
| `data.onchain.activeAddresses` | count | chain | Active addresses |
| `data.onchain.whaleAlert` | transfers[] | chain, minAmount | Whale transfers |
| `data.onchain.dexVolume` | volume | chain, dex | DEX volume |
| `data.onchain.dexLiquidity` | liquidity | chain, pool | DEX liquidity pool |
| `data.onchain.lendingRate` | rate | protocol | Lending rate (Aave/Compound) |
| `data.onchain.stakingYield` | apy | chain, validator | Staking yield |
| `data.onchain.gasPrice` | gwei | chain | Gas price |
| `data.onchain.nftVolume` | volume | chain, collection | NFT volume |
| `data.sentiment.social` | sentimentScore | source, keywords | Social media sentiment |
| `data.sentiment.news` | sentimentScore | source, keywords | News sentiment |
| `data.sentiment.fearGreed` | index | — | Fear & Greed Index |
| `data.macro.dxy` | value | — | US Dollar Index |
| `data.macro.bondYield` | yield | maturity | Treasury yield |
| `data.macro.cpi` | value | — | CPI data |
| `data.macro.fedRate` | rate | — | Federal funds rate |
| `data.macro.sp500` | value | — | S&P 500 |
| `data.custom.api` | customData | url, parser, headers | Custom API source |

### 3.2 Signal Processing Nodes (22 nodes)

| Type | Outputs | Config |
|------|---------|--------|
| `indicator.rsi` | rsiValue | period, overbought, oversold |
| `indicator.macd` | macd, signal, histogram | fast, slow, signal |
| `indicator.bollinger` | upper, middle, lower | period, stdDev |
| `indicator.ma` | maValue | period, type (SMA/EMA/WMA/DEMA) |
| `indicator.atr` | atrValue | period |
| `indicator.ichimoku` | tenkan, kijun, senkouA, senkouB, chikou | tenkan, kijun, senkou |
| `indicator.fibonacci` | levels[] | swing high, swing low |
| `indicator.vwap` | vwap | — |
| `indicator.obv` | obv | — |
| `indicator.stochastic` | k, d | kPeriod, dPeriod, smooth |
| `indicator.adx` | adx, diPlus, diMinus | period |
| `indicator.cci` | cci | period |
| `indicator.williamsR` | williamsR | period |
| `indicator.mfi` | mfi | period |
| `indicator.custom` | result | formula expression |
| `math.expression` | result | math expression |
| `filter.threshold` | signal | threshold, operator |
| `transform.smooth` | smoothed[] | method (MA/exp/kalman) |
| `transform.normalize` | normalized[] | min, max range |
| `logic.delay` | any | delay (N candles) |
| `logic.gate` | signal | condition |

### 3.3 Decision Nodes (13 nodes)

| Type | Outputs | Config |
|------|---------|--------|
| `condition.if` | true, false | condition expression |
| `condition.multi` | branches... | switch cases |
| `condition.combine` | combined | logic (AND/OR/weighted) |
| `strategy.entry` | order | entry conditions, position size |
| `strategy.exit` | order | exit conditions (TP/SL/trailing) |
| `sizing.fixed` | quantity | fixed amount |
| `sizing.percentage` | quantity | % of portfolio |
| `sizing.kelly` | quantity | win rate, odds |
| `sizing.volatility` | quantity | ATR multiplier |
| `sizing.pyramid` | quantity | pyramid strategy |
| `sizing.antiMartingale` | quantity | anti-martingale params |
| `sizing.maxDrawdown` | quantity | max drawdown constraint |
| `strategy.rebalance` | orders[] | target allocation |

### 3.4 AI Nodes (13 nodes)

| Type | Outputs | Config |
|------|---------|--------|
| `ai.llm` | text, analysis | model, temperature, system prompt |
| `ai.rag` | documents[] | knowledge base, top-k |
| `ai.sentiment.nlp` | score, label | model |
| `ai.sentiment.finbert` | score, label | — |
| `ai.forecast` | prediction, confidence | model, horizon |
| `ai.agent` | result | agent type (researcher/trader/risk) |
| `ai.scoring` | score, ranking | scoring model |
| `ai.freqai.model` | prediction | model config |
| `ai.freqai.train` | model, metrics | training data, params |
| `ai.backtest.result` | metrics, equityCurve | strategy config |
| `ai.backtest.optimize` | bestParams | optimization target |
| `ai.correlation` | matrix | symbols, window |
| `ai.anomaly` | anomalies[] | detection method |

### 3.5 Output Nodes (5 nodes)

| Type | Config |
|------|--------|
| `output.order` | exchange, execution (market/limit/IOC/FOK) |
| `output.alert` | channels (Telegram/email/toast), template |
| `output.log` | level (debug/info/warn/error) |
| `output.dashboard` | display type (line/bar/pie/kline) |
| `output.webhook` | url, headers |

**Total: 65+ node types across 5 categories.**

Category color scheme:
- Data → cyan (`PulseColors.cyan`)
- Signal → purple (`PulseColors.purple`)
- Decision → amber (`PulseColors.amber`)
- AI → green (`PulseColors.accent`)
- Output → red (`PulseColors.danger`)

---

## 4. Canvas Rendering & Interaction

### 4.1 Layered Rendering

```
ZStack {
    // Layer 1: Grid background (Canvas 2D)
    Canvas { drawGrid(scale, offset) }

    // Layer 2: Edges/connections (Canvas 2D)
    Canvas { drawEdges(edges, nodes) }

    // Layer 3: Nodes (SwiftUI Views)
    ForEach(graph.nodes) { node in
        NodeView(node)
            .position(node.position)
            .gesture(nodeDragGesture)
    }

    // Layer 4: Wire drag preview (Canvas 2D)
    Canvas { drawDragPreview(wireDragState) }

    // Layer 5: Selection rectangle (Canvas 2D)
    Canvas { drawSelectionRect(rect) }

    // Layer 6: Minimap (bottom-right)
    MiniMapView(graph, viewport)

    // Layer 7: Group boxes
    ForEach(graph.groups) { group in
        GroupBoxView(group)
    }
}
// Right-side config panel
.overlay(alignment: .trailing) {
    if let selected = selectedNode {
        NodeConfigPanel(selected)
            .transition(.move(edge: .trailing))
    }
}
```

### 4.2 Viewport Controls

| Action | Gesture | Behavior |
|--------|---------|----------|
| Pan | Two-finger drag / middle-button drag | `viewport.offset += delta` |
| Zoom | Pinch / Ctrl+scroll | `viewport.scale *= factor`, clamped 0.1~3.0 |
| Fit | Double-click empty area | Calculate bounding box, adjust viewport |
| Select | Drag on empty area | Rectangle select, highlight nodes inside |

### 4.3 Connection Interaction

```
Drag from output port → Draw temporary Bezier → Drag to input port → Type check → Create Edge
                                                                  ↓ mismatch
                                                              Port not highlighted, reject
```

**Bezier wire rendering (Canvas 2D):**
```swift
func drawConnection(from: CGPoint, to: CGPoint, color: Color) {
    let dx = abs(to.x - from.x) * 0.5
    context.stroke(
        Path { p in
            p.move(to: from)
            p.addCurve(to: to,
                       control1: CGPoint(x: from.x + dx, y: from.y),
                       control2: CGPoint(x: to.x - dx, y: to.y))
        },
        with: .linearGradient(...),
        lineWidth: 2
    )
}
```

**Wire colors by data type:**
- ticker/kline → cyan
- indicator → purple
- signal/boolean → amber
- ai.* → green
- order/position → red

### 4.4 Node View Structure

```
┌─ DepthCard (glass effect) ─────────────────┐
│  [icon] RSI Indicator         [collapse] [x] │ ← Title bar (draggable)
├─────────────────────────────────────────────┤
│  Input port ●  K-line data                  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Period  [====●====] 14             │   │ ← Widget controls
│  │  Overbuy [====●====] 70             │   │
│  │  Oversold[====●====] 30             │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Output port ● RSI  ● Overbuy  ● Oversold  │
└─────────────────────────────────────────────┘
```

- Title bar: drag to move node
- Collapse button: minimize to title + ports only
- Port dots: hover shows data type tooltip
- Widget controls: embedded inline (Slider, Dropdown, TextField)

### 4.5 Minimap (MiniMapView)

Bottom-right corner, 200×150px:
- All nodes rendered as small colored rectangles by category
- Current viewport shown as semi-transparent rectangle
- Click/drag on minimap pans main canvas
- Auto-updates on zoom

### 4.6 Right-Side Configuration Panel (NodeConfigPanel)

Slides in when node selected, width 320px:

```
┌─ NodeConfigPanel ─────────────────┐
│  [icon] RSI Indicator      [delete] │ ← Header
├───────────────────────────────────┤
│  // Basic info                     │
│  Name      [RSI Indicator    ]     │ ← Editable
│  Notes     [                  ]     │
├───────────────────────────────────┤
│  // Parameters (dynamic per type)  │
│  Period    [14                 ]   │
│  Overbuy   [70                 ]   │
│  Oversold  [30                 ]   │
│  Source    [K-line node ▾      ]   │ ← Variable selector
├───────────────────────────────────┤
│  // Advanced (collapsible)         │
│  ▸ Output variable name            │
│  ▸ Execution condition             │
│  ▸ Error handling                  │
├───────────────────────────────────┤
│  // Runtime status (when running)  │
│  Last run: 2s ago                  │
│  Output: RSI=65.3                  │
└───────────────────────────────────┘
```

### 4.7 Undo/Redo

```swift
@Observable
class UndoManager {
    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []

    func record(_ action: CanvasAction) {
        undoStack.append(action)
        redoStack.removeAll()
    }
    func undo() { /* pop undoStack, reverse, push redoStack */ }
    func redo() { /* pop redoStack, apply, push undoStack */ }
}

enum CanvasAction {
    case addNode(CanvasNode)
    case removeNode(CanvasNode)
    case moveNode(id: UUID, from: CGPoint, to: CGPoint)
    case addEdge(CanvasEdge)
    case removeEdge(CanvasEdge)
    case updateConfig(nodeId: UUID, key: String, old: Any, new: Any)
    case addGroup(NodeGroup)
    case removeGroup(NodeGroup)
}
```

Shortcuts: `Cmd+Z` undo, `Cmd+Shift+Z` redo.

### 4.8 Node Groups

```swift
struct NodeGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var color: Color
    var nodeIds: [UUID]
    var position: CGPoint   // auto-calculated
    var size: CGSize        // auto-fit content
}
```

- Select multiple nodes → `Cmd+G` to create group
- Groups can be collapsed (title bar only)
- Groups move as a unit
- Double-click group to enter internal edit

### 4.9 Node Palette

Left sidebar or right-click context menu:
- Search filter
- Category accordion
- Drag onto canvas to create node
- Favorites / recent nodes

---

## 5. Per-Node Editable Fields

### Data Source Nodes
| Field | Control | Notes |
|-------|---------|-------|
| Exchange | Dropdown | Binance/OKX/Bybit/Gate |
| Symbol | SearchableDropdown | BTC/USDT, ETH/USDT... |
| Timeframe | Dropdown | 1m/5m/15m/1h/4h/1d |
| API endpoint | TextField | Custom data source URL |
| Refresh rate | Slider | Data polling interval |
| Chain | Dropdown | ETH/BSC/SOL/ARB (onchain) |
| Metric type | MultiSelect | Active addr/TVL/whale (onchain) |

### Signal Processing Nodes
| Field | Control | Notes |
|-------|---------|-------|
| Period | NumberInput + Slider | RSI=14, MACD=12/26/9 |
| Threshold | NumberInput | Overbought/oversold |
| MA type | Dropdown | SMA/EMA/WMA/DEMA |
| Formula | CodeEditor | Custom indicator formula |
| Smooth method | Dropdown | MA/exponential/Kalman |
| Output var name | TextField | Custom output name |

### Decision Nodes
| Field | Control | Notes |
|-------|---------|-------|
| Condition | ExpressionBuilder | `[var] [op] [value/var]` |
| Logic | AND/OR Toggle | Multi-condition combo |
| Position size | NumberInput | Fixed or percentage |
| Kelly params | NumberInput | Win rate, odds |
| ATR multiplier | Slider | SL/TP ATR multiplier |
| Sizing strategy | Dropdown | Pyramid/anti-martingale |
| Max drawdown | Slider | Drawdown constraint % |

### AI Nodes
| Field | Control | Notes |
|-------|---------|-------|
| Model | Dropdown | GPT-4/Claude/FinBERT/custom |
| System prompt | TextEditor (multiline) | LLM role definition |
| User prompt | TextEditor + var insertion | Supports `{{variable}}` |
| Temperature | Slider 0~2 | Creativity control |
| Top-K | NumberInput | RAG retrieval count |
| Knowledge base | MultiSelect | RAG knowledge bases |
| Agent type | Dropdown | Researcher/trader/risk |
| Training data | FilePicker | FreqAI training data |
| Training params | Form | epochs/batch_size/lr |
| Prediction target | Dropdown | Price direction/change/vol |

### Output Nodes
| Field | Control | Notes |
|-------|---------|-------|
| Execution | Dropdown | Market/Limit/IOC/FOK |
| Channels | MultiSelect | Telegram/email/toast |
| Template | TextEditor | Message format template |
| Webhook URL | TextField | Push endpoint |
| Log level | Dropdown | Debug/Info/Warn/Error |
| Chart type | Dropdown | Line/bar/pie/kline |

### Edit Interaction Principles
1. **Inline (canvas):** Simple params via node widgets (Slider, Dropdown)
2. **Panel (right side):** Complex params (multiline text, expressions, variable selectors)
3. **Double-click:** Rename node title
4. **Right-click menu:** Copy, delete, disable, view details

---

## 6. Execution Model

### Phase 1: Visual Configuration

User builds workflow on canvas → Serialize to JSON → Generate Freqtrade Python strategy

**Serialization format:**
```json
{
  "name": "RSI+MACD Strategy",
  "version": "1.0",
  "graph": {
    "nodes": [...],
    "edges": [...],
    "groups": [...],
    "viewport": {"scale": 1.0, "offset": [0, 0]}
  },
  "metadata": {
    "createdAt": "2026-05-29T...",
    "updatedAt": "2026-05-29T..."
  }
}
```

**Code generation flow:**
```
WorkflowGraph → GraphAnalyzer → CodeGenerator → Freqtrade Python Strategy
                     ↓
            Topological sort for execution order
            Validate graph (no orphans, no cycles)
```

### Phase 2: Direct Execution (Future)
- Backend DAG executor with topological sort
- Real-time canvas sync with execution progress
- Node status visualization (running/complete/error)

---

## 7. Notification System

### Data Model

```swift
struct AppNotification: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let severity: NotificationSeverity
    let isRead: Bool
    let actionRoute: AppRoute?
    let actionPayload: String?
    let createdAt: Date
}

enum NotificationType: String, Codable {
    case riskAlert, tradeExecuted, strategyUpdate, systemAlert, aiInsight
}

enum NotificationSeverity: String, Codable {
    case info, warning, critical
}
```

### Bell Icon Interaction

Click bell → Popover shows notification list → Click notification → Navigate to related page
                                          → "Mark all read" button → Badge disappears

### NotificationPopover UI

```
┌─ Notification Center ────────────────────┐
│  ● Critical  BTC price broke stop-loss    │ ← Red left border
│    2 min ago                              │
│                                           │
│  ● Warning   RSI overbought signal fired  │ ← Amber
│    15 min ago                             │
│                                           │
│  ○ Info      Daily report generated       │ ← Gray (read)
│    1 hour ago                             │
├───────────────────────────────────────────┤
│  [Mark all read]           [View all]     │
└───────────────────────────────────────────┘
```

- Unread: colored left border
- Click: mark read + navigate
- Max 20 recent items
- "View all" navigates to full notification page

### Backend Integration

```swift
protocol NotificationServiceProtocol {
    func fetchNotifications(limit: Int) async throws -> [AppNotification]
    func markAsRead(id: UUID) async throws
    func markAllAsRead() async throws
    func getUnreadCount() async throws -> Int
}
```

Backend already has `routers/notifications.py`. Wire up API calls.

### Toast Integration

Existing `ToastView` + new `ToastManager`:
```swift
@Observable
class ToastManager {
    var currentToast: Toast?
    func show(_ type: ToastType, message: String, duration: TimeInterval = 3)
}
```

Triggers: trade executed → `.success`, risk alert → `.error`, system change → `.info`

---

## 8. File Structure

### New Files

```
macos-app/PulseDesk/
  Models/
    CanvasModels.swift          # WorkflowGraph, CanvasNode, CanvasEdge, NodeGroup, etc.
    NotificationModels.swift    # AppNotification, NotificationType, etc.
  Services/
    NodeRegistry.swift          # All 65+ NodeDefinition registrations
    APINotifications.swift      # Notification API service
    GraphSerializer.swift       # Save/load workflow JSON
    CodeGenerator.swift         # Graph → Freqtrade Python code
    ToastManager.swift          # Toast notification manager
  ViewModels/
    CanvasViewModel.swift       # Canvas state, selection, viewport, undo
    NotificationViewModel.swift # Notifications, unread count, fetch/mark
  Views/
    Canvas/
      StrategyCanvasTab.swift   # Main canvas view (replace placeholder)
      CanvasBackground.swift    # Grid background (Canvas 2D)
      CanvasEdges.swift         # Edge rendering (Canvas 2D)
      CanvasDragPreview.swift   # Wire drag preview
      CanvasSelectionRect.swift # Rectangle selection
      MiniMapView.swift         # Minimap overlay
      NodeView.swift            # Individual node view
      NodeConfigPanel.swift     # Right-side config panel
      NodePalette.swift         # Node type picker sidebar
      GroupBoxView.swift        # Node group box
      VariableSelector.swift    # Upstream variable picker
    Notifications/
      NotificationPopover.swift # Bell popover content
      NotificationRow.swift     # Single notification row
```

### Modified Files

```
macos-app/PulseDesk/
  Views/
    AppShell/
      ToolbarView.swift         # Wire bell button action → show popover
    Strategies/
      StrategyDetailView.swift  # StrategyCanvasTab already wired as tab 1
  State/
    AppState.swift              # Add NotificationViewModel, ToastManager
  Models/
    Types.swift                 # Add any shared types if needed
    Enums.swift                 # Add NotificationType, NotificationSeverity
```

---

## 9. Implementation Order

### Step 1: Notification System (implement first)
1. `NotificationModels.swift` — data types
2. `APINotifications.swift` — API service (mock first, live later)
3. `NotificationViewModel.swift` — state management
4. `NotificationPopover.swift` + `NotificationRow.swift` — UI
5. Wire bell button in `ToolbarView.swift`
6. `ToastManager.swift` — integrate with existing `ToastView`

### Step 2: Canvas Foundation
1. `CanvasModels.swift` — all data models
2. `NodeRegistry.swift` — register all 65+ node definitions
3. `CanvasViewModel.swift` — graph state, viewport, selection
4. `StrategyCanvasTab.swift` — main canvas layout (replace placeholder)
5. `CanvasBackground.swift` — grid background
6. `NodeView.swift` — node rendering with DepthCard
7. `CanvasEdges.swift` — Bezier wire rendering

### Step 3: Canvas Interaction
8. Node drag gesture
9. Port connection (drag from output to input)
10. Type-based connection validation
11. `CanvasDragPreview.swift` — wire drag preview
12. `CanvasSelectionRect.swift` — rectangle selection
13. Viewport pan/zoom gestures

### Step 4: Canvas Features
14. `MiniMapView.swift` — minimap
15. `NodeConfigPanel.swift` — right-side panel
16. `VariableSelector.swift` — upstream variable picker
17. `NodePalette.swift` — node type sidebar
18. `GroupBoxView.swift` — node groups
19. Undo/Redo system
20. `GraphSerializer.swift` — save/load

### Step 5: Code Generation
21. `CodeGenerator.swift` — graph → Freqtrade Python code
22. Graph validation (orphans, cycles, missing required inputs)

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SwiftUI Canvas performance with many nodes | Hybrid approach: Canvas for connections only, Views for nodes. Test with 50+ nodes early. |
| Complex gesture conflicts (pan vs drag vs connect) | Clear gesture priority: port drag > node drag > canvas pan. Use `simultaneousGesture` and `highPriorityGesture` appropriately. |
| 65+ node definitions is a lot of code | Use a data-driven registry pattern. Define nodes declaratively, generate UI dynamically. |
| Variable selector needs graph traversal | Pre-compute upstream node list on selection change, cache it. |
| Code generation for complex graphs | Start with simple linear chains, add branching support incrementally. |
