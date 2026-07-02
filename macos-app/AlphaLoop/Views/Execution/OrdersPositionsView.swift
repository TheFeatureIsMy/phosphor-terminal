// OrdersPositionsView.swift — 订单/持仓页面

import SwiftUI

struct OrdersPositionsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: ExecutionCenterViewModel?
    @State private var selectedTab = 0

    // Confirm dialog states
    @State private var showCancelAllConfirm = false
    @State private var showForceCloseAllConfirm = false
    @State private var cancelOrderId: String?
    @State private var closePositionId: String?

    private var resolvedMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel?.ordersPositions?.state,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    private var affectedRunCount: Int {
        guard let data = viewModel?.ordersPositions else { return 0 }
        return data.orders.filter { $0.status.lowercased() == "pending" }.count + data.positions.count
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveWireStrip(mode: resolvedMode)
            EmergencyStopBar(
                mode: resolvedMode,
                affectedRuns: affectedRunCount,
                emergencyLocked: viewModel?.ordersPositions?.state == "emergency_locked",
                onStop: { await viewModel?.emergencyStop() },
                onResume: { await viewModel?.emergencyResume() }
            )

            if let vm = viewModel {
                if vm.isLoading && vm.ordersPositions == nil {
                    LoadingView(type: .detail)
                } else if let data = vm.ordersPositions {
                    // 状态横幅
                    stateBanner(data)

                    // Tab 选择器 + 状态指示
                    tabHeader(data)

                    Divider().foregroundStyle(colors.border)

                    // 批量操作行
                    batchActionRow(data)

                    // 内容区
                    ScrollView {
                        if selectedTab == 0 {
                            ordersSection(data.orders)
                        } else {
                            positionsSection(data.positions)
                        }
                    }
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.Execution.loadFailed,
                        description: error,
                        primaryAction: (title: L10n.Common.retry, action: { Task { await vm.loadOrdersPositions() } })
                    )
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: L10n.Execution.noData,
                        description: L10n.Execution.noDataDesc
                    )
                }
            }
        }
        .id(settingsState.language)
        .riskAtmosphericBackground(tint: PulseColors.accent)
        .task {
            let vm = ExecutionCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadOrdersPositions()
        }
        // 批量撤销全部确认
        .confirmDialog(
            isPresented: $showCancelAllConfirm,
            title: L10n.Execution.confirmCancelAll,
            message: String(
                format: L10n.Execution.confirmCancelAllMessage,
                viewModel?.ordersPositions?.orders.filter { $0.status.lowercased() == "pending" }.count ?? 0,
                resolvedMode.label
            ),
            confirmLabel: L10n.Execution.cancelAllOrders,
            confirmStyle: .danger,
            onConfirm: { Task { await viewModel?.cancelAllOrders() } }
        )
        // 批量强制平仓确认
        .confirmDialog(
            isPresented: $showForceCloseAllConfirm,
            title: L10n.Execution.confirmForceCloseAll,
            message: String(
                format: L10n.Execution.confirmForceCloseAllMessage,
                viewModel?.ordersPositions?.positions.count ?? 0,
                resolvedMode.label
            ),
            confirmLabel: L10n.Execution.forceCloseAll,
            confirmStyle: .danger,
            onConfirm: { Task { await viewModel?.forceCloseAllPositions() } }
        )
        // 单笔撤销订单确认
        .confirmDialog(
            isPresented: .init(
                get: { cancelOrderId != nil },
                set: { if !$0 { cancelOrderId = nil } }
            ),
            title: L10n.Execution.confirmCancelOrder,
            message: String(
                format: L10n.Execution.confirmCancelOrderMessage,
                cancelOrderId ?? "",
                resolvedMode.label
            ),
            confirmLabel: L10n.Execution.cancelOrder,
            confirmStyle: .danger,
            onConfirm: {
                guard let id = cancelOrderId else { return }
                Task { await viewModel?.cancelOrder(id: id) }
                cancelOrderId = nil
            }
        )
        // 单笔平仓确认
        .confirmDialog(
            isPresented: .init(
                get: { closePositionId != nil },
                set: { if !$0 { closePositionId = nil } }
            ),
            title: L10n.Execution.confirmClosePosition,
            message: String(
                format: L10n.Execution.confirmClosePositionMessage,
                closePositionId ?? "",
                resolvedMode.label
            ),
            confirmLabel: L10n.Execution.closePosition,
            confirmStyle: .danger,
            onConfirm: {
                guard let id = closePositionId else { return }
                Task { await viewModel?.closePosition(id: id) }
                closePositionId = nil
            }
        )
    }

    // MARK: - 状态横幅

    @ViewBuilder
    private func stateBanner(_ data: OrdersPositionsBFFResponse) -> some View {
        if data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: data.state == "error" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "error" ? L10n.Execution.connectionError : L10n.Execution.statusError)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !data.reasonCodes.isEmpty {
                        Text(data.reasonCodes.joined(separator: ", "))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()
            }
            .padding(PulseSpacing.sm)
            .padding(.horizontal, PulseSpacing.lg)
            .background(
                (data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.08)
            )
        }
    }

    // MARK: - Tab 选择器

    private func tabHeader(_ data: OrdersPositionsBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            tabButton(L10n.Execution.orders, index: 0, count: data.orders.count)
            tabButton(L10n.Execution.positionsTab, index: 1, count: data.positions.count)

            Spacer()

            statusIndicators(data)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    private func tabButton(_ title: String, index: Int, count: Int) -> some View {
        Button { selectedTab = index } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Text(title)
                    .font(selectedTab == index ? PulseFonts.bodyMedium : PulseFonts.body)
                Text("\(count)")
                    .font(PulseFonts.micro)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(selectedTab == index ? PulseColors.accent.opacity(0.2) : colors.surface)
                    .clipShape(Capsule())
            }
            .foregroundStyle(selectedTab == index ? PulseColors.accent : colors.textMuted)
        }
        .buttonStyle(.plain)
    }

    private func statusIndicators(_ data: OrdersPositionsBFFResponse) -> some View {
        let exchangeOk = data.state != "error"
        let ftOk = !data.reasonCodes.contains("freqtrade_down")

        return HStack(spacing: PulseSpacing.xs) {
            Circle()
                .fill(exchangeOk ? PulseColors.StateColors.green : PulseColors.StateColors.red)
                .frame(width: 6, height: 6)
            Text("Exchange: \(exchangeOk ? "OK" : "Error")")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)

            Circle()
                .fill(ftOk ? PulseColors.StateColors.green : PulseColors.StateColors.red)
                .frame(width: 6, height: 6)
            Text("Freqtrade: \(ftOk ? "Healthy" : "Down")")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - 批量操作行

    private func batchActionRow(_ data: OrdersPositionsBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Button {
                showCancelAllConfirm = true
            } label: {
                Label(L10n.Execution.cancelAllOrders, systemImage: "xmark.octagon")
            }
            .buttonStyle(.bordered)
            .tint(PulseColors.danger)
            .disabled(data.orders.filter { $0.status.lowercased() == "pending" }.isEmpty)

            Button {
                showForceCloseAllConfirm = true
            } label: {
                Label(L10n.Execution.forceCloseAll, systemImage: "arrow.down.right.square")
            }
            .buttonStyle(.bordered)
            .tint(PulseColors.danger)
            .disabled(data.positions.isEmpty)

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 订单列表

    private func ordersSection(_ orders: [OrderBFFResponse]) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            if orders.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: L10n.Execution.noOrders,
                    description: L10n.Execution.noOrdersDesc
                )
                .padding(.top, PulseSpacing.lg)
            } else {
                ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                    orderRow(order)
                        .staggeredAppearance(index: index)
                }
            }
        }
        .padding(PulseSpacing.lg)
    }

    private func orderRow(_ order: OrderBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Text(order.side.uppercased())
                .font(PulseFonts.captionMedium)
                .foregroundStyle(sideColor(order.side))
                .frame(width: 40)

            Text(order.symbol)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            Text(order.type.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)

            Spacer()

            Text("Qty: \(order.quantity, specifier: "%.4f")")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)

            if let price = order.price {
                Text("@ \(formatPrice(price))")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
            }

            Text(order.status)
                .font(PulseFonts.micro)
                .foregroundStyle(orderStatusColor(order.status))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(orderStatusColor(order.status).opacity(0.1))
                .clipShape(Capsule())

            if let exchangeId = order.exchangeOrderId {
                Text(exchangeId)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .lineLimit(1)
                    .help("Exchange Order ID: \(exchangeId)")
            }

            // 内联撤销按钮（仅挂单）
            if order.status.lowercased() == "pending" {
                Button {
                    cancelOrderId = order.id
                } label: {
                    Label(L10n.Execution.cancelOrder, systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .tint(PulseColors.danger)
            }
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - 持仓列表

    private func positionsSection(_ positions: [PositionBFFResponse]) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            if positions.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: L10n.Execution.noPositions,
                    description: L10n.Execution.noPositionsDesc
                )
                .padding(.top, PulseSpacing.lg)
            } else {
                ForEach(Array(positions.enumerated()), id: \.element.id) { index, position in
                    positionRow(position)
                        .staggeredAppearance(index: index)
                }
            }
        }
        .padding(PulseSpacing.lg)
    }

    private func positionRow(_ position: PositionBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Text(position.side.uppercased())
                .font(PulseFonts.captionMedium)
                .foregroundStyle(sideColor(position.side))
                .frame(width: 50)

            Text(position.symbol)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("Entry: \(formatPrice(position.avgEntryPrice))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Text("Current: \(formatPrice(position.currentPrice))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textPrimary)
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(position.unrealizedPnl >= 0 ? "+" : "")\(position.unrealizedPnl, specifier: "%.1f") USDT")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(pnlColor(position.unrealizedPnl))
                Text("\(position.unrealizedPnlPct >= 0 ? "+" : "")\(position.unrealizedPnlPct, specifier: "%.2f")%")
                    .font(PulseFonts.micro)
                    .foregroundStyle(pnlColor(position.unrealizedPnl))
            }

            if let stopLoss = position.stopLoss {
                Text("SL: \(formatPrice(stopLoss))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.StateColors.orangeRed)
            }

            // reason_codes 提示
            if !position.reasonCodes.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseColors.StateColors.yellow)
                    .help(position.reasonCodes.joined(separator: ", "))
            }

            // 内联平仓按钮
            Button {
                closePositionId = position.id
            } label: {
                Label(L10n.Execution.closePosition, systemImage: "arrow.down.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .tint(PulseColors.danger)
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - 辅助方法

    private func sideColor(_ side: String) -> Color {
        switch side.lowercased() {
        case "buy", "long": return PulseColors.StateColors.green
        case "sell", "short": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private func pnlColor(_ pnl: Double) -> Color {
        pnl >= 0 ? PulseColors.StateColors.green : PulseColors.StateColors.red
    }

    private func orderStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "filled": return PulseColors.StateColors.green
        case "pending", "open": return PulseColors.StateColors.yellow
        case "cancelled", "canceled": return PulseColors.StateColors.gray
        case "rejected", "error": return PulseColors.StateColors.red
        case "partially_filled": return PulseColors.StateColors.orange
        default: return PulseColors.StateColors.gray
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        } else if price >= 1 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
    }
}
