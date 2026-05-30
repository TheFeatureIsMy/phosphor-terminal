# Phase 2: 核心交易链路 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Connect Dashboard, Strategies, Backtest, Trades, and Notifications to real backend data with WebSocket real-time updates.

**Architecture:** Extend existing ViewModels and views with WebSocket subscriptions, add missing API calls (correlation, strategy update, backtest history), and add filtering/detail views.

**Tech Stack:** Swift 5.9 / SwiftUI / macOS 26

---

## Task 1: Dashboard — Add Correlation Heatmap

**Files:**
- Create: `macos-app/PulseDesk/Views/Dashboard/CorrelationHeatmapView.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/DashboardView.swift`
- Modify: `macos-app/PulseDesk/ViewModels/DashboardViewModel.swift`

- [ ] **Step 1: Add correlation data to DashboardViewModel**

Add property and load call:
```swift
var correlationSnapshots: [CorrelationSnapshot] = []
```
In `loadAll()`, add:
```swift
correlationSnapshots = (try? await dashboardAPI.getCorrelation()) ?? []
```

- [ ] **Step 2: Create CorrelationHeatmapView**

```swift
// CorrelationHeatmapView.swift — 相关性热力图

import SwiftUI

struct CorrelationHeatmapView: View {
    @Environment(PulseColors.self) private var colors
    let snapshots: [CorrelationSnapshot]

    private var symbols: [String] {
        let set = Set(snapshots.flatMap { [$0.symbolA, $0.symbolB] })
        return Array(set).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("资产相关性")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            if snapshots.isEmpty {
                Text("暂无相关性数据")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                let syms = symbols
                Grid(alignment: .center, horizontalSpacing: 2, verticalSpacing: 2) {
                    // Header row
                    GridRow {
                        Color.clear.frame(width: 40, height: 20)
                        ForEach(syms, id: \.self) { sym in
                            Text(sym.prefix(4))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                    // Data rows
                    ForEach(syms, id: \.self) { rowSym in
                        GridRow {
                            Text(rowSym.prefix(4))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .frame(width: 40, alignment: .trailing)
                            ForEach(syms, id: \.self) { colSym in
                                let val = correlationValue(symA: rowSym, symB: colSym)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForCorrelation(val))
                                    .frame(height: 28)
                                    .overlay(
                                        Text(String(format: "%.1f", val))
                                            .font(PulseFonts.micro)
                                            .foregroundStyle(.white.opacity(0.8))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.card)
    }

    private func correlationValue(symA: String, symB: String) -> Double {
        if symA == symB { return 1.0 }
        return snapshots.first { s in
            (s.symbolA == symA && s.symbolB == symB) ||
            (s.symbolA == symB && s.symbolB == symA)
        }?.correlation ?? 0.0
    }

    private func colorForCorrelation(_ val: Double) -> Color {
        let absVal = abs(val)
        if val > 0.7 { return PulseColors.danger.opacity(absVal) }
        if val > 0.3 { return PulseColors.warning.opacity(absVal) }
        if val < -0.3 { return PulseColors.info.opacity(absVal) }
        return PulseColors.accent.opacity(0.1)
    }
}
```

- [ ] **Step 3: Add heatmap to DashboardView**

In `DashboardView.mainContent`, after the `DataSourceBadge` HStack, add:
```swift
CorrelationHeatmapView(snapshots: viewModel.correlationSnapshots)
```

- [ ] **Step 4: Build and commit**

Run: `cd macos-app && swift build`
```bash
git add macos-app/PulseDesk/Views/Dashboard/CorrelationHeatmapView.swift macos-app/PulseDesk/Views/Dashboard/DashboardView.swift macos-app/PulseDesk/ViewModels/DashboardViewModel.swift
git commit -m "feat(app): add correlation heatmap to dashboard"
```

---

## Task 2: Strategies — Add Update Method

**Files:**
- Modify: `macos-app/PulseDesk/Services/APIStrategies.swift`
- Modify: `macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift`

- [ ] **Step 1: Add update method to APIStrategies**

In `APIStrategies.swift`, add:
```swift
func update(id: Int, name: String?, type: StrategyType?, market: String?) async throws -> Strategy {
    struct UpdateBody: Encodable {
        let name: String?
        let type: String?
        let market: String?
    }
    let body = UpdateBody(name: name, type: type?.rawValue, market: market)
    return try await client.put("/api/strategies/\(id)", body: body, mock: { MockData.mockStrategies().first! })
}
```

- [ ] **Step 2: Add update method to StrategiesViewModel**

```swift
func update(id: Int, name: String?, type: StrategyType?, market: String?) async {
    do {
        let updated = try await api.update(id: id, name: name, type: type, market: market)
        if let index = strategies.firstIndex(where: { $0.id == id }) {
            strategies[index] = updated
        }
    } catch {
        self.error = error.localizedDescription
    }
}
```

- [ ] **Step 3: Build and commit**

Run: `cd macos-app && swift build`
```bash
git add macos-app/PulseDesk/Services/APIStrategies.swift macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift
git commit -m "feat(app): add strategy update method"
```

---

## Task 3: Backtest — History List and Detail

**Files:**
- Modify: `macos-app/PulseDesk/Views/Backtest/BacktestView.swift`
- Modify: `macos-app/PulseDesk/ViewModels/BacktestViewModel.swift`
- Modify: `macos-app/PulseDesk/Services/APIBacktest.swift`

- [ ] **Step 1: Add list method to APIBacktest**

In `APIBacktest.swift`, add:
```swift
func list(limit: Int = 20) async throws -> [Backtest] {
    try await client.get("/api/backtest?limit=\(limit)", mock: { [MockData.mockBacktest()] })
}
```

- [ ] **Step 2: Add history state to BacktestViewModel**

```swift
var history: [Backtest] = []
var isLoadingHistory = false

func loadHistory() async {
    isLoadingHistory = true
    defer { isLoadingHistory = false }
    do {
        history = try await api.list()
    } catch {}
}
```

- [ ] **Step 3: Add history tab to BacktestView**

In `BacktestView.swift`, after the results section, add a history list:
```swift
// 回测历史
if !viewModel.history.isEmpty {
    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
        Text("回测历史")
            .font(PulseFonts.bodyMedium)
            .foregroundStyle(colors.textPrimary)

        ForEach(viewModel.history) { backtest in
            HStack {
                VStack(alignment: .leading) {
                    Text("策略 #\(backtest.strategyId)")
                        .font(PulseFonts.caption)
                    Text(backtest.createdAt ?? "")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                Text(String(format: "夏普 %.2f", backtest.sharpeRatio ?? 0))
                    .font(PulseFonts.monoLabel)
                Text(String(format: "%.1f%%", (backtest.winRate ?? 0) * 100))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accent)
            }
            .padding(PulseSpacing.sm)
            .background(colors.cardBackground)
            .cornerRadius(PulseRadii.sm)
        }
    }
}
```

Add `.task { await viewModel.loadHistory() }` alongside existing task.

- [ ] **Step 4: Build and commit**

Run: `cd macos-app && swift build`
```bash
git add macos-app/PulseDesk/Views/Backtest/BacktestView.swift macos-app/PulseDesk/ViewModels/BacktestViewModel.swift macos-app/PulseDesk/Services/APIBacktest.swift
git commit -m "feat(app): add backtest history list"
```

---

## Task 4: Trades — Filtering and Empty State

**Files:**
- Modify: `macos-app/PulseDesk/Views/Trades/TradesView.swift`

- [ ] **Step 1: Add filter state and empty state**

In `TradesView.swift`, add:
```swift
@State private var symbolFilter = ""
@State private var sideFilter: OrderSide? = nil
```

Add filter bar above the table:
```swift
HStack(spacing: PulseSpacing.sm) {
    TextField("搜索币对", text: $symbolFilter)
        .textFieldStyle(.roundedBorder)
        .frame(width: 150)

    Picker("方向", selection: $sideFilter) {
        Text("全部").tag(nil as OrderSide?)
        Text("买入").tag(OrderSide.buy)
        Text("卖出").tag(OrderSide.sell)
    }
    .pickerStyle(.segmented)
    .frame(width: 150)

    Spacer()
}
.padding(.horizontal, PulseSpacing.lg)
```

Add computed filtered arrays:
```swift
private var filteredOrders: [Order] {
    orders.filter { order in
        (symbolFilter.isEmpty || order.symbol.localizedCaseInsensitiveContains(symbolFilter)) &&
        (sideFilter == nil || order.side == sideFilter)
    }
}
```

Replace `OrdersTableView(orders: orders)` with `OrdersTableView(orders: filteredOrders)`.

Add empty state when orders is empty:
```swift
if orders.isEmpty {
    EmptyStateView(
        icon: "arrow.left.arrow.right",
        title: "暂无交易记录",
        description: "配置 Freqtrade 后可查看实盘交易数据"
    )
    .frame(height: 200)
}
```

- [ ] **Step 2: Build and commit**

Run: `cd macos-app && swift build`
```bash
git add macos-app/PulseDesk/Views/Trades/TradesView.swift
git commit -m "feat(app): add trades filtering and empty state"
```

---

## Task 5: Notifications — Action Routing

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/ToolbarView.swift` (unused, skip)
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift` (ConsoleToolbar)

- [ ] **Step 1: Add notification action routing to ConsoleToolbar**

In `AppShellView.swift`, in the ConsoleToolbar's notification popover, add an `onViewAll` handler that navigates to settings:

```swift
.popover(isPresented: $showNotifications) {
    if let vm = notificationViewModel {
        NotificationPopover(viewModel: vm) {
            showNotifications = false
            appState.selectedRoute = .settings
        }
    }
}
```

- [ ] **Step 2: Build and commit**

Run: `cd macos-app && swift build`
```bash
git add macos-app/PulseDesk/Views/AppShell/AppShellView.swift
git commit -m "feat(app): add notification action routing"
```

---

## Task 6: Final Build Verification

- [ ] **Step 1: Run build**
Run: `cd macos-app && swift build`
- [ ] **Step 2: Run backend tests**
Run: `cd backend && python3 -m pytest tests/ -q`
- [ ] **Step 3: Commit any fixes**
