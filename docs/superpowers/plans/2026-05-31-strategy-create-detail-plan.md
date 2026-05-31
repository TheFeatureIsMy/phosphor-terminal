# Strategy Create & Detail Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace sheet-based strategy detail/create with route push navigation, ChatGPT-style AI chat generation, and tag-based organization.

**Architecture:** New `AppRoute.strategyDetail(id:)` for full-page detail view with breadcrumb nav. Mode-switcher component toggles between manual form and AI chat. Strategy type removed from frontend; tags added for flexible organization. Backend gets AI generation endpoint.

**Tech Stack:** SwiftUI, ProofAlpha DesignSystem, FastAPI backend with LLM integration

---

## File Structure

```
Create:
  macos-app/PulseDesk/Views/Strategies/StrategyCreatePanel.swift   — Mode switcher + manual form + AI chat panel
  macos-app/PulseDesk/Views/Strategies/AIChatView.swift            — ChatGPT-style conversation view
  macos-app/PulseDesk/Services/AIStrategyGenerator.swift           — Client for /api/strategies/generate endpoint

Modify:
  macos-app/PulseDesk/Models/Enums.swift                           — Add AppRoute.strategyDetail, deprecate StrategyType
  macos-app/PulseDesk/Models/Types.swift                           — Add tags to Strategy
  macos-app/PulseDesk/State/AppState.swift                         — Add selectedStrategyId
  macos-app/PulseDesk/Views/AppShell/AppShellView.swift           — Add .strategyDetail route case
  macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift    — Replace sheets with route push + inline create
  macos-app/PulseDesk/Views/Strategies/StrategyDetailView.swift   — Config bar + breadcrumb + remove 概览
  macos-app/PulseDesk/Views/Strategies/StrategyCardView.swift     — Add tag pills
  macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift         — Remove showCreateSheet, update create()
  macos-app/PulseDesk/Services/APIStrategies.swift                 — Update create signature
  backend/app/schemas/api.py                                       — Add tags, remove type from create
  backend/app/models/strategy.py                                   — Add tags column
  backend/app/routers/strategies.py                                — Add POST /generate endpoint, update create
```

---

## Phase 1: Navigation + Detail Page

### Task 1: Add AppRoute.strategyDetail and AppState changes

**Files:**
- Modify: `macos-app/PulseDesk/Models/Enums.swift:261-304`
- Modify: `macos-app/PulseDesk/State/AppState.swift`

- [ ] **Step 1: Add route case to AppRoute enum**

In `Enums.swift`, find `enum AppRoute` (line 261). Add the new case and update the switch statements:

```swift
enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard, strategies, backtest, trades
    case aiStudio
    case sentiment, attribution, aiProviders, risk
    case settings
    case strategyDetail  // NEW

    var id: String { rawValue }

    var icon: String {
        switch self {
        // ... existing cases unchanged ...
        case .strategyDetail: return "cpu"  // same icon as strategies
        }
    }

    var label: String {
        switch self {
        // ... existing cases unchanged ...
        case .strategyDetail: return "策略详情"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .trades, .risk: return .trading
        case .strategies, .backtest, .strategyDetail: return .strategy  // add here
        case .aiStudio, .sentiment, .attribution, .aiProviders: return .ai
        case .settings: return .system
        }
    }
}
```

- [ ] **Step 2: Add selectedStrategyId to AppState**

In `AppState.swift`, add:

```swift
var selectedStrategyId: Int?
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Models/Enums.swift macos-app/PulseDesk/State/AppState.swift
git commit -m "feat(strategy): add AppRoute.strategyDetail and selectedStrategyId to AppState"
```

---

### Task 2: Add .strategyDetail case to AppShellView route switch

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

- [ ] **Step 1: Add route case**

In `AppShellView.swift`, find the `detailContent` computed property's switch statement. After the `.strategies` case, add:

```swift
case .strategyDetail:
    if let vm = strategiesVM, let id = appState.selectedStrategyId {
        StrategyDetailView(strategyId: id, client: networkClient)
    } else {
        LoadingView(type: .detail)
    }
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/AppShell/AppShellView.swift
git commit -m "feat(strategy): add .strategyDetail route case to AppShellView"
```

---

### Task 3: Update StrategyDetailView — breadcrumb, config bar, remove 概览 tab

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyDetailView.swift`

READ the file first. Current content shows 4 tabs (概览/画布/回测/交易记录) with a strategy header and tab bar.

- [ ] **Step 1: Update init to accept strategyId instead of Strategy**

StrategyDetailView currently takes `let strategy: Strategy` and `let client: NetworkClientProtocol`. Change to fetch strategy by ID:

```swift
struct StrategyDetailView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let strategyId: Int
    let client: NetworkClientProtocol

    @State private var strategy: Strategy?
    @State private var selectedTab = 0
    private let tabs = ["画布", "回测", "交易记录", "版本"]

    var body: some View {
        Group {
            if let strategy {
                VStack(spacing: 0) {
                    navBar
                    Divider().foregroundStyle(colors.border)
                    configBar
                    Divider().foregroundStyle(colors.border)
                    tabBar
                    Divider().foregroundStyle(colors.border)
                    tabContent(strategy)
                }
            } else {
                LoadingView(type: .detail)
            }
        }
        .task { await loadStrategy() }
    }

    private func loadStrategy() async {
        let api = APIStrategies(client: client)
        strategy = try? await api.get(id: strategyId)
    }

    // ... tabContent, etc.
}
```

- [ ] **Step 2: Add navBar with breadcrumb**

```swift
private var navBar: some View {
    HStack(spacing: PulseSpacing.xs) {
        Button {
            appState.selectedRoute = .strategies
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                Text("策略列表").font(PulseFonts.caption)
            }
            .foregroundStyle(colors.textMuted)
        }
        .buttonStyle(.plain)

        Text("/").foregroundStyle(colors.textMuted).font(PulseFonts.caption)

        Text(strategy?.name ?? "")
            .font(PulseFonts.bodyMedium)
            .foregroundStyle(colors.textPrimary)
            .lineLimit(1)

        Spacer()

        // Deploy button
        if let s = strategy {
            ProofAlphaButton(title: s.status == .active ? "停止" : "部署") {
                Task {
                    let vm = StrategiesViewModel(client: client)
                    if s.status == .active { await vm.stop(id: s.id) }
                    else { await vm.deploy(id: s.id) }
                }
            }
        }
    }
    .padding(.horizontal, PulseSpacing.lg)
    .padding(.vertical, PulseSpacing.sm)
}
```

- [ ] **Step 3: Add configBar**

```swift
private var configBar: some View {
    HStack(spacing: PulseSpacing.sm) {
        configItem(label: "名称", value: strategy?.name ?? "")
        Text("|").foregroundStyle(colors.border).font(PulseFonts.micro)
        configPill(label: "市场", value: strategy?.market ?? "", color: PulseColors.accent)
        configPill(label: "交易所", value: strategy?.exchange ?? "", color: PulseColors.purple)
        configPill(label: "标签", value: nil, color: colors.textMuted)  // placeholder for tags
        Spacer()
        saveStatusDot
    }
    .padding(.horizontal, PulseSpacing.lg)
    .padding(.vertical, PulseSpacing.xs)
}

private func configItem(label: String, value: String) -> some View {
    HStack(spacing: 3) {
        Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        Text(value).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
    }
}

private func configPill(label: String, value: String?, color: Color) -> some View {
    HStack(spacing: 3) {
        Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        if let value {
            Text(value).font(PulseFonts.caption).foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }
}

private var saveStatusDot: some View {
    Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
}
```

- [ ] **Step 4: Remove old strategyHeader, update tabs**

Remove the `strategyHeader` computed property (line 45-84 in current file). Update tab names to `["画布", "回测", "交易记录", "版本"]`.

- [ ] **Step 5: Update StrategyCanvasTab init**

Since detail view now loads strategy asynchronously, the canvas tab needs to handle the case where strategy might still be loading. Pass strategy directly once loaded:

```swift
@ViewBuilder
private func tabContent(_ strategy: Strategy) -> some View {
    switch selectedTab {
    case 0: StrategyCanvasTab(strategy: strategy, client: client)
    case 1: StrategyBacktestTab(strategy: strategy, client: client)
    case 2: TradesView()
    case 3: StrategyVersionPlaceholder()
    default: EmptyView()
    }
}
```

Add version placeholder:

```swift
struct StrategyVersionPlaceholder: View {
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 32)).foregroundStyle(colors.textMuted)
            Text("版本历史").font(PulseFonts.body).foregroundStyle(colors.textSecondary)
            Text("即将推出").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 6: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 7: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategyDetailView.swift
git commit -m "feat(strategy): redesign detail page with breadcrumb, config bar, route push"
```

---

### Task 4: Update StrategiesListView — route push instead of sheet

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift`

- [ ] **Step 1: Replace sheet with route push**

Find the two `.sheet()` calls (lines 50-56) and replace:

```swift
// REMOVE both .sheet modifiers
// .sheet(isPresented: $viewModel.showCreateSheet) { ... }
// .sheet(item: $selectedStrategy) { ... }

// Instead, add these:
.onChange(of: viewModel.showCreateSheet) { _, show in
    // Create panel is now inline — handled in Task 7
}
.onTapGesture on each card: instead of setting selectedStrategy, push route:
```

Update the card tap action:

```swift
StrategyCardView(strategy: strategy) {
    appState.selectedStrategyId = strategy.id
    appState.selectedRoute = .strategyDetail
} onDeploy: { ... }
```

Add `@Environment(AppState.self) private var appState` to the struct.

- [ ] **Step 2: Remove selectedStrategy state**

Remove `@State private var selectedStrategy: Strategy?` since we no longer use sheet.

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift
git commit -m "feat(strategy): replace detail sheet with AppRoute.strategyDetail push navigation"
```

---

## Phase 2: Create Flow

### Task 5: Create StrategyCreatePanel — mode switcher + manual form

**Files:**
- Create: `macos-app/PulseDesk/Views/Strategies/StrategyCreatePanel.swift`

- [ ] **Step 1: Create StrategyCreatePanel**

```swift
import SwiftUI

enum CreateMode { case manual, aiChat }

struct StrategyCreatePanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState

    @State private var mode: CreateMode = .manual
    @State private var name = ""
    @State private var selectedMarket: MarketType = .crypto
    @State private var selectedExchange: Exchange = .binance
    @State private var isCreating = false

    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Mode switcher
            modeSwitcher
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.top, PulseSpacing.md)

            Divider().foregroundStyle(colors.border).padding(.top, PulseSpacing.sm)

            if mode == .manual {
                manualForm
            } else {
                AIChatView(onStrategyGenerated: { strategyId in
                    appState.selectedStrategyId = strategyId
                    appState.selectedRoute = .strategyDetail
                })
            }
        }
        .padding(.bottom, PulseSpacing.md)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.lg).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([("手动创建", CreateMode.manual), ("AI 对话创建", CreateMode.aiChat)], id: \.0) { label, m in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: mode == m ? .semibold : .regular))
                        .foregroundStyle(mode == m ? PulseColors.accent : colors.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mode == m ? colors.surfaceElevated : .clear)
                        )
                        .shadow(color: mode == m ? .black.opacity(0.15) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var manualForm: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("策略名称").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                TextField("输入策略名称...", text: $name)
                    .textFieldStyle(.plain).font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(10).background(colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(
                        !name.isEmpty ? PulseColors.accent.opacity(0.3) : colors.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("交易市场").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                pillSelector(MarketType.allCases.map { ($0.label, $0) }, selected: selectedMarket) { selectedMarket = $0 }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("交易所").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                pillSelector(availableExchanges, selected: selectedExchange) { selectedExchange = $0 }
            }

            HStack(spacing: 4) {
                Image(systemName: "lightbulb").font(.system(size: 9)).foregroundStyle(PulseColors.amber)
                Text("创建后进入画布，从调色板拖入节点开始构建策略逻辑")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            .padding(8).background(colors.background)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))

            HStack {
                ProofAlphaButton(title: "取消", action: onCancel, style: .ghost)
                Spacer()
                ProofAlphaButton(title: "创建并打开画布 →") {
                    Task { await doCreate() }
                }
                .opacity(name.isEmpty ? 0.5 : 1).disabled(name.isEmpty)
            }
            .padding(.top, PulseSpacing.sm)
        }
        .padding(PulseSpacing.lg)
    }

    private func pillSelector<T: Identifiable & Hashable>(_ items: [(String, T)], selected: T, onSelect: @escaping (T) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.0) { label, item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { onSelect(item) }
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: selected.hashValue == item.hashValue ? .semibold : .regular))
                        .foregroundStyle(selected.hashValue == item.hashValue ? colors.background : colors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selected.hashValue == item.hashValue ? PulseColors.accent : colors.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected.hashValue == item.hashValue ? .clear : colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var availableExchanges: [(String, Exchange)] {
        switch selectedMarket {
        case .crypto: return [("Binance", .binance), ("OKX", .okx), ("Bybit", .bybit), ("Gate", .gate)]
        case .usStock: return [("Alpaca", .alpaca), ("IBKR", .ibkr)]
        case .aShare: return [("JoinQuant", .joinquant), ("EastMoney", .eastmoney)]
        }
    }

    private func doCreate() async {
        isCreating = true
        let api = APIStrategies(client: client)
        if let strategy = try? await api.create(name: name, type: .maCross, market: selectedMarket.rawValue, exchange: selectedExchange.rawValue) {
            appState.selectedStrategyId = strategy.id
            appState.selectedRoute = .strategyDetail
        }
        isCreating = false
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds (may need to add `NetworkClientProtocol` access — StrategyCreatePanel needs a `client` parameter or environment)

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategyCreatePanel.swift
git commit -m "feat(strategy): add StrategyCreatePanel with mode switcher and manual form"
```

---

### Task 6: Create AIChatView — ChatGPT-style conversation

**Files:**
- Create: `macos-app/PulseDesk/Views/Strategies/AIChatView.swift`

- [ ] **Step 1: Create AIChatView**

```swift
import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let generatedGraph: (strategyId: Int, name: String, market: String, exchange: String, nodeCount: Int, nodeNames: [String])?

    enum Role { case ai, user }

    static func ai(_ text: String, graph: (Int, String, String, String, Int, [String])? = nil) -> ChatMessage {
        ChatMessage(role: .ai, content: text, generatedGraph: graph)
    }
    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: text, generatedGraph: nil)
    }
}

struct AIChatView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @Environment(AppState.self) private var appState
    var onStrategyGenerated: (Int) -> Void

    @State private var messages: [ChatMessage] = [
        .ai("你好！我是策略构建助手。用自然语言描述你想做的交易策略，我会自动生成对应的画布节点图。\n\n试试说：\"用 EMA 和 RSI 做比特币趋势跟踪，RSI 低于 30 买入，Binance 交易所\"")
    ]
    @State private var inputText = ""
    @State private var isThinking = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { _, msg in
                            MessageBubble(msg: msg, onOpenGraph: { id in
                                onStrategyGenerated(id)
                            })
                        }
                        if isThinking {
                            ThinkingBubble()
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(PulseSpacing.md)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: isThinking) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider().foregroundStyle(colors.border)

            // Input bar
            HStack(spacing: 8) {
                TextField("描述你的策略...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .padding(10)
                    .background(colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? colors.border : PulseColors.purple))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(PulseSpacing.sm)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isThinking else { return }
        messages.append(.user(text))
        inputText = ""
        isThinking = true

        Task {
            do {
                let result = try await AIStrategyGenerator(client: networkClient).generate(prompt: text)
                isThinking = false
                let nodeNames = result.graph?.nodes.map { NodeRegistry.definition(for: $0.nodeType)?.name ?? $0.nodeType } ?? []
                messages.append(.ai(
                    "已根据你的描述生成策略画布：",
                    graph: (result.strategy.id, result.strategy.name, result.strategy.market, result.strategy.exchange, result.graph?.nodes.count ?? 0, nodeNames)
                ))
            } catch {
                isThinking = false
                messages.append(.ai("抱歉，生成过程遇到问题。请再试一次或换个描述试试。"))
            }
        }
    }
}

// MARK: - MessageBubble
private struct MessageBubble: View {
    @Environment(PulseColors.self) private var colors
    let msg: ChatMessage
    var onOpenGraph: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == .ai {
                avatar("🤖", bg: Color.purple.opacity(0.15))
                bubbleContent.alignmentGuide(.leading) { _ in 0 }
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                bubbleContent
                avatar("👤", bg: PulseColors.accent.opacity(0.15))
            }
        }
        .id(msg.id)
    }

    private func avatar(_ emoji: String, bg: Color) -> some View {
        Text(emoji).font(.system(size: 13))
            .frame(width: 28, height: 28)
            .background(Circle().fill(bg))
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(msg.content)
                .font(PulseFonts.caption)
                .foregroundStyle(msg.role == .ai ? colors.textSecondary : colors.textPrimary)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(msg.role == .ai ? Color.white.opacity(0.03) : PulseColors.accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(msg.role == .ai ? Color.white.opacity(0.05) : PulseColors.accent.opacity(0.1), lineWidth: 1)
                )

            if let graph = msg.generatedGraph {
                generatedCard(graph)
            }
        }
    }

    private func generatedCard(_ graph: (strategyId: Int, name: String, market: String, exchange: String, nodeCount: Int, nodeNames: [String])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2").font(.system(size: 9)).foregroundStyle(PulseColors.accent)
                Text("策略画布预览").font(PulseFonts.captionMedium).foregroundStyle(PulseColors.accent)
            }

            HStack(spacing: 12) {
                paramItem("名称", graph.name)
                paramItem("市场", graph.market)
                paramItem("交易所", graph.exchange)
            }

            Text("\(graph.nodeCount) 个节点已自动连线")
                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)

            HStack(spacing: 4) {
                Button { onOpenGraph(graph.strategyId) } label: {
                    Label("打开画布", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(colors.background)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PulseColors.accent))
                }
                Button {} label: {
                    Label("重新生成", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(colors.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
    }

    private func paramItem(_ key: String, _ val: String) -> some View {
        HStack(spacing: 2) {
            Text(key).font(.system(size: 8)).foregroundStyle(colors.textMuted)
            Text(val).font(.system(size: 9, weight: .semibold)).foregroundStyle(colors.textPrimary)
        }
    }
}

// MARK: - ThinkingBubble
private struct ThinkingBubble: View {
    @Environment(PulseColors.self) private var colors
    @State private var animating = false

    var body: some View {
        HStack(spacing: 10) {
            Text("🤖").font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.purple.opacity(0.15)))
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(colors.textMuted)
                        .frame(width: 5, height: 5)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: animating)
                }
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            .onAppear { animating = true }
            Spacer(minLength: 60)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds (AIStrategyGenerator may be unresolved until Task 8)

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/AIChatView.swift
git commit -m "feat(strategy): add ChatGPT-style AI chat view for strategy generation"
```

---

### Task 7: Wire create panel into StrategiesListView

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift`

- [ ] **Step 1: Add inline create panel**

In `StrategiesListView.swift`, add a `@State private var showCreatePanel = false` and toggle it with the "新建策略" button. Add the create panel above the grid:

```swift
var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: PulseSpacing.lg) {
            header

            if showCreatePanel {
                StrategyCreatePanel(onCancel: { withAnimation { showCreatePanel = false } })
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ... existing loading/empty/grid content ...
        }
        .padding(PulseSpacing.lg)
    }
    .animation(.easeInOut(duration: 0.2), value: showCreatePanel)
}
```

Update the "新建策略" button to toggle `showCreatePanel` instead of `viewModel.showCreateSheet`.

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift
git commit -m "feat(strategy): wire StrategyCreatePanel into StrategiesListView inline"
```

---

## Phase 3: AI Chat Backend

### Task 8: Create AIStrategyGenerator service

**Files:**
- Create: `macos-app/PulseDesk/Services/AIStrategyGenerator.swift`

- [ ] **Step 1: Create AIStrategyGenerator**

```swift
import Foundation

struct AIGenerateRequest: Encodable {
    let prompt: String
}

struct AIGenerateResponse: Decodable {
    let strategy_id: Int
    let name: String
    let market: String
    let exchange: String
    let graph_json: String

    var strategy: (id: Int, name: String, market: String, exchange: String) {
        (id: strategy_id, name: name, market: market, exchange: exchange)
    }

    var graph: WorkflowGraph? {
        guard let data = graph_json.data(using: .utf8) else { return nil }
        return try? GraphSerializer().deserialize(data)
    }
}

struct AIStrategyGenerator {
    let client: any NetworkClientProtocol

    func generate(prompt: String) async throws -> AIGenerateResponse {
        try await client.post("/api/strategies/generate", body: AIGenerateRequest(prompt: prompt), mock: {
            AIGenerateResponse(
                strategy_id: 999,
                name: "AI 生成策略",
                market: "crypto",
                exchange: "binance",
                graph_json: "{\"nodes\":[],\"edges\":[],\"groups\":[],\"viewport\":{\"scale\":1.0,\"offset\":{\"x\":0,\"y\":0}}}"
            )
        })
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Services/AIStrategyGenerator.swift
git commit -m "feat(strategy): add AIStrategyGenerator service for AI chat endpoint"
```

---

### Task 9: Add POST /api/strategies/generate backend endpoint

**Files:**
- Modify: `backend/app/routers/strategies.py`
- Modify: `backend/app/schemas/api.py`

- [ ] **Step 1: Add schema**

In `backend/app/schemas/api.py`, add:

```python
class StrategyGenerateRequest(BaseModel):
    prompt: str

class StrategyGenerateResponse(BaseModel):
    strategy_id: int
    name: str
    market: str
    exchange: str
    graph_json: str
```

- [ ] **Step 2: Add endpoint**

In `backend/app/routers/strategies.py`, add:

```python
from app.schemas.api import StrategyGenerateRequest, StrategyGenerateResponse
from app.services.strategy_registry import render_freqtrade_strategy, strategy_class_name, strategy_file_path

@router.post("/generate", response_model=StrategyGenerateResponse)
def generate_strategy(body: StrategyGenerateRequest, db: Session = Depends(get_db)):
    from app.services.rag_service import RAGService
    rag = RAGService()

    # Use RAG/LLM to parse trading intent from natural language
    result = rag.generate_strategy_from_prompt(body.prompt)
    # result contains: name, market, exchange, graph_json, freqtrade_code

    # Create the strategy record
    strategy = Strategy(
        name=result["name"],
        type="ma_cross",  # default, canvas defines actual logic
        market=result.get("market", "crypto"),
        exchange=result.get("exchange", "binance"),
        parameters={},
        status=StrategyStatus.draft.value,
    )
    db.add(strategy)
    db.commit()
    db.refresh(strategy)

    # Save canvas workflow
    canvas = CanvasWorkflow(
        strategy_id=strategy.id,
        graph_json=result.get("graph_json", "{}"),
        code_snapshot=result.get("code_snapshot"),
    )
    db.add(canvas)
    db.commit()

    return StrategyGenerateResponse(
        strategy_id=strategy.id,
        name=strategy.name,
        market=strategy.market,
        exchange=strategy.exchange,
        graph_json=result.get("graph_json", "{}"),
    )
```

- [ ] **Step 3: Run backend tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -5`
Expected: Existing tests still pass

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/strategies.py backend/app/schemas/api.py
git commit -m "feat(backend): add POST /api/strategies/generate for AI chat strategy creation"
```

---

## Phase 4: Tags + Cleanup

### Task 10: Add tags to Strategy model (frontend + backend)

**Files:**
- Modify: `macos-app/PulseDesk/Models/Types.swift`
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCardView.swift`
- Modify: `backend/app/models/strategy.py`
- Modify: `backend/app/schemas/api.py`

- [ ] **Step 1: Add tags to frontend Strategy**

In `Types.swift`, find the `Strategy` struct. Add:

```swift
var tags: [String]
```

Add to init:
```swift
tags: [String] = [],
```

- [ ] **Step 2: Add tags to backend model**

In `backend/app/models/strategy.py`, add to the `Strategy` class:

```python
tags = Column(JSON, default=[])
```

- [ ] **Step 3: Add tags to API schemas**

In `backend/app/schemas/api.py`, add to `StrategyResponse`:

```python
tags: list[str] = []
```

Add to `StrategyCreate`:
```python
tags: list[str] = []
```

- [ ] **Step 4: Add tag pills to StrategyCardView**

In `StrategyCardView.swift`, add a tag row below the metadata:

```swift
if !strategy.tags.isEmpty {
    HStack(spacing: 4) {
        ForEach(strategy.tags.prefix(3), id: \.self) { tag in
            Text("#\(tag)")
                .font(.system(size: 8))
                .foregroundStyle(PulseColors.accent)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(PulseColors.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        if strategy.tags.count > 3 {
            Text("+\(strategy.tags.count - 3)")
                .font(.system(size: 8)).foregroundStyle(colors.textMuted)
        }
    }
}
```

- [ ] **Step 5: Run migration**

Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "from app.database import engine; from app.models.strategy import Strategy; Strategy.metadata.create_all(engine)"`

- [ ] **Step 6: Verify build + tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -3`

- [ ] **Step 7: Commit**

```bash
git add macos-app/PulseDesk/Models/Types.swift macos-app/PulseDesk/Views/Strategies/StrategyCardView.swift backend/app/models/strategy.py backend/app/schemas/api.py
git commit -m "feat(strategy): add tags to Strategy model — frontend and backend"
```

---

### Task 11: Remove StrategyType from frontend, deprecate in API

**Files:**
- Modify: `macos-app/PulseDesk/Models/Enums.swift`
- Modify: `macos-app/PulseDesk/Models/Types.swift`
- Modify: `macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift`
- Modify: `macos-app/PulseDesk/Services/APIStrategies.swift`

- [ ] **Step 1: Mark StrategyType as deprecated, remove UI usage**

In `Enums.swift`, add `@available(*, deprecated, message: "Use tags instead")` above the `StrategyType` enum. Don't delete it yet (backend still uses it for Freqtrade templates).

- [ ] **Step 2: Remove type from Strategy struct**

In `Types.swift`, remove `type: StrategyType` from the `Strategy` struct. Add a computed property for backward compat:

```swift
@available(*, deprecated, message: "Use tags instead")
var type: StrategyType { .maCross }
```

- [ ] **Step 3: Update StrategiesViewModel.create()**

Change signature from:
```swift
func create(name: String, type: StrategyType, market: String, exchange: String) async
```
To:
```swift
func create(name: String, market: String, exchange: String, tags: [String] = []) async
```

Update body accordingly.

- [ ] **Step 4: Update APIStrategies.create()**

Change signature to match: remove `type` parameter, add `tags`.

- [ ] **Step 5: Update StrategyCardView and StrategiesListView**

Remove `strategy.type` references. Use tags or status badge instead.

- [ ] **Step 6: Verify build + tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -3`

- [ ] **Step 7: Commit**

```bash
git add macos-app/PulseDesk/Models/Enums.swift macos-app/PulseDesk/Models/Types.swift macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift macos-app/PulseDesk/Services/APIStrategies.swift macos-app/PulseDesk/Views/Strategies/StrategyCardView.swift macos-app/PulseDesk/Views/Strategies/StrategiesListView.swift
git commit -m "feat(strategy): deprecate StrategyType on frontend, replace with tags"
```

---

### Task 12: End-to-end integration verification

- [ ] **Step 1: Run all Swift tests**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test 2>&1 | tail -5
```
Expected: All tests pass

- [ ] **Step 2: Run all backend tests**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -5
```
Expected: All tests pass (pre-existing failures unrelated)

- [ ] **Step 3: Build**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3
```
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore: final integration verification for strategy create and detail redesign"
```
