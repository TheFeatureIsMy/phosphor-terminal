// TradesView.swift — 交易记录页面
// 订单表格 + 持仓表格

import SwiftUI

struct TradesView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var orders: [Order] = []
    @State private var positions: [Position] = []
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var symbolFilter = ""
    @State private var sideFilter: OrderSide? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                tabButton("订单", tag: 0, count: orders.count)
                tabButton("持仓", tag: 1, count: positions.count)
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.top, PulseSpacing.md)

            Divider()
                .foregroundStyle(colors.border)

            if selectedTab == 0 {
                // Custom filter bar (replaces native TextField + Picker)
                HStack(spacing: PulseSpacing.sm) {
                    // Custom search field
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.textMuted)
                        TextField("搜索币对...", text: $symbolFilter)
                            .textFieldStyle(.plain)
                            .font(PulseFonts.caption)
                        if !symbolFilter.isEmpty {
                            Button { symbolFilter = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(colors.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
                    .frame(width: 180)

                    // Custom side filter pills
                    HStack(spacing: 2) {
                        filterPill("全部", isActive: sideFilter == nil) { sideFilter = nil }
                        filterPill("买入", isActive: sideFilter == .buy) { sideFilter = .buy }
                        filterPill("卖出", isActive: sideFilter == .sell) { sideFilter = .sell }
                    }

                    Spacer()

                    Text("\(filteredOrders.count) 条")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.xs)
            }

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    if selectedTab == 0 {
                        if orders.isEmpty {
                            EmptyStateView(
                                icon: "arrow.left.arrow.right",
                                title: "暂无交易记录",
                                description: "配置 Freqtrade 后可查看实盘交易数据"
                            )
                            .frame(height: 200)
                        } else {
                            OrdersTableView(orders: filteredOrders)
                        }
                    } else {
                        PositionsTableView(positions: positions)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
        .task { await loadData() }
    }

    private func tabButton(_ title: String, tag: Int, count: Int) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedTab = tag }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Text(title)
                    .font(selectedTab == tag ? PulseFonts.bodyMedium : PulseFonts.body)
                    .foregroundStyle(selectedTab == tag ? colors.textPrimary : colors.textSecondary)

                Text("\(count)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(selectedTab == tag ? PulseColors.accent : colors.textMuted)
                    .animation(.easeInOut, value: count)
                    .transition(.opacity)
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(selectedTab == tag ? PulseColors.accent : .clear)
                        .frame(height: 2)
                        .padding(.top, PulseSpacing.xxs)
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var filteredOrders: [Order] {
        orders.filter { order in
            (symbolFilter.isEmpty || order.symbol.localizedCaseInsensitiveContains(symbolFilter)) &&
            (sideFilter == nil || order.side == sideFilter)
        }
    }

    private func filterPill(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(isActive ? colors.background : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? PulseColors.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func loadData() async {
        isLoading = true
        do {
            let api = APIOrders(client: networkClient)
            async let o = api.listOrders(limit: 50)
            async let p = api.listPositions()
            orders = try await o
            positions = try await p
        } catch {}
        isLoading = false
    }
}
