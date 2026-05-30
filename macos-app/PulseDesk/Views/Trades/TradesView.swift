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

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                if selectedTab == 0 {
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
                }

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
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(selectedTab == tag ? PulseColors.accent : .clear)
                        .frame(height: 2)
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
