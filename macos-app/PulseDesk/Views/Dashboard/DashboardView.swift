// DashboardView.swift — 主仪表盘布局
// 2x2 KPI 网格 + 权益曲线 + 右侧面板 — 紧凑内聚

import SwiftUI

struct DashboardView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if viewModel.isLoading {
                loadingSkeleton
            } else {
                mainContent
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            await viewModel.loadAll()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var mainContent: some View {
        VStack(spacing: PulseSpacing.md) {
            if viewModel.kpis == nil && !viewModel.isLoading {
                EmptyStateView(icon: "chart.bar.xaxis", title: "无法加载数据", description: "请检查后端连接后重试")
            } else if let kpis = viewModel.kpis {
                // Row 1: KPI 指标 — 一行四列均分
                kpiRow(kpis)

                // Row 2: 权益曲线 — 全宽
                EquityCurveChart(points: viewModel.equityCurve)
                    .frame(maxWidth: .infinity)

                // 数据来源
                HStack {
                    DataSourceBadge(status: kpis.dataSource)
                    Spacer()
                    Circle()
                        .fill(PulseColors.statusActive)
                        .frame(width: 6, height: 6)
                }

                // 相关性热力图
                CorrelationHeatmapView(snapshots: viewModel.correlationSnapshots)

                // Row 3: 持仓（主） + 最近交易 / 风险事件（次）
                HStack(alignment: .top, spacing: PulseSpacing.md) {
                    PositionsListView(positions: viewModel.positions)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: PulseSpacing.md) {
                        RecentTradesListView(orders: Array(viewModel.orders.prefix(5)))
                        ActivityFeedView(events: viewModel.riskEvents)
                    }
                    .frame(width: 320)
                }
            }
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - KPI 一行四列均分
    private func kpiRow(_ kpis: DashboardKPIs) -> some View {
        HStack(spacing: 8) {
            KPICardView(
                icon: "dollarsign.circle.fill",
                label: "总盈亏",
                value: String(format: "$%.2f", kpis.totalPnl),
                trend: kpis.pnlChangePct,
                color: kpis.totalPnl >= 0 ? colors.profit : PulseColors.loss
            )

            KPICardView(
                icon: "chart.line.uptrend.xyaxis",
                label: "夏普比率",
                value: String(format: "%.2f", kpis.sharpeRatio),
                trend: nil,
                color: PulseColors.accent
            )

            KPICardView(
                icon: "arrow.down.right.circle.fill",
                label: "最大回撤",
                value: String(format: "%.1f%%", kpis.maxDrawdown),
                trend: nil,
                color: PulseColors.loss
            )

            KPICardView(
                icon: "target",
                label: "胜率",
                value: String(format: "%.1f%%", kpis.winRate),
                trend: nil,
                color: colors.profit
            )
        }
    }

    // MARK: - 加载骨架
    private var loadingSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            // KPI 骨架 — 一行四列
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 95).shimmer()
                }
            }

            // 权益曲线骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 200).shimmer()

            // 下方面板骨架
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 200).shimmer()
                VStack(spacing: PulseSpacing.md) {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 140).shimmer()
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 140).shimmer()
                }.frame(width: 320)
            }
        }
        .padding(PulseSpacing.lg)
    }
}
