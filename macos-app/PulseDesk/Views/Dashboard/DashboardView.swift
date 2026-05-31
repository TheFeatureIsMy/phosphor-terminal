// DashboardView.swift — 主仪表盘布局
// 按信息重要程度分层：P&L Hero + 风险 → 持仓 → 权益曲线 → KPI条带 → 交易+相关性

import SwiftUI
import Charts

// MARK: - 迷你权益走势图 (Hero PnL 卡片内嵌)
struct MiniEquitySparkline: View {
    let points: [EquityPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("", point.date),
                y: .value("", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [PulseColors.accent.opacity(0.25), PulseColors.accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("", point.date),
                y: .value("", point.value)
            )
            .foregroundStyle(PulseColors.accent)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Hero PnL 卡片 (最大视觉权重)
struct HeroPnLCard: View {
    @Environment(PulseColors.self) private var colors
    let totalPnl: Double
    let pnlChangePct: Double
    let equityCurve: [EquityPoint]
    let todaysTrades: Int
    let activeStrategies: Int

    @State private var appeared = false
    @State private var displayPnl: Double = 0

    var body: some View {
        ProofAlphaCard(emphasis: .bold) {
            HStack(alignment: .top, spacing: PulseSpacing.lg) {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    // 标签
                    TerminalLabel(text: "总盈亏 (P&L)")

                    // 大数值 — 数字跳动效果
                    Text(pnlFormatted)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundStyle(totalPnl >= 0 ? colors.profit : colors.loss)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    // 副指标行
                    HStack(spacing: PulseSpacing.md) {
                        trendBadge
                        HStack(spacing: 3) {
                            Circle().fill(PulseColors.accent).frame(width: 4, height: 4)
                            Text("\(todaysTrades) 笔交易")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textSecondary)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(PulseColors.cyan).frame(width: 4, height: 4)
                            Text("\(activeStrategies) 个策略")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                }

                Spacer()

                // 迷你权益走势 (右侧)
                if !equityCurve.isEmpty {
                    MiniEquitySparkline(points: equityCurve)
                        .frame(width: 200, height: 80)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var pnlFormatted: String {
        let sign = totalPnl >= 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", abs(totalPnl)))"
    }

    private var trendBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: pnlChangePct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%+.1f%%", pnlChangePct))
                .font(PulseFonts.bodyMedium)
        }
        .foregroundStyle(pnlChangePct >= 0 ? colors.profit : colors.loss)
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .fill(pnlChangePct >= 0 ? colors.profit.opacity(0.12) : colors.loss.opacity(0.12))
        )
    }
}

// MARK: - 风险警报条 (紧凑高优先级)
struct RiskAlertStrip: View {
    @Environment(PulseColors.self) private var colors
    let events: [RiskEvent]

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseColors.warning)
                    Text("风险事件")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    if !events.isEmpty {
                        BadgeDot(color: PulseColors.danger, label: "\(events.count)", size: .small)
                    }
                }

                if events.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("无风险事件").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                } else {
                    VStack(spacing: PulseSpacing.xxs) {
                        ForEach(Array(events.prefix(3).enumerated()), id: \.element.id) { index, event in
                            riskRow(event)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }

    private func riskRow(_ event: RiskEvent) -> some View {
        let severityColor = event.severity.color
        return HStack(spacing: PulseSpacing.xs) {
            RoundedRectangle(cornerRadius: 1)
                .fill(severityColor)
                .frame(width: 3, height: 20)

            Image(systemName: event.severity.icon)
                .font(.system(size: 10))
                .foregroundStyle(severityColor)
                .frame(width: 14)

            Text(event.description ?? "")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
                .lineLimit(1)

            Spacer()

            Text(event.createdAt.prefix(10).description)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }
}

// MARK: - 持仓水平卡片（紧凑横向）
struct PositionCard: View {
    @Environment(PulseColors.self) private var colors
    let position: Position

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            // 方向色条
            RoundedRectangle(cornerRadius: 1)
                .fill(position.unrealizedPnl >= 0 ? colors.profit : colors.loss)
                .frame(width: 3, height: 36)

            // 交易对
            VStack(alignment: .leading, spacing: 1) {
                Text(position.symbol)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(position.side.label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(position.side.color(colors))
            }

            Spacer()

            // 数量 + 未实现盈亏
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.4f", position.quantity))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textSecondary)
                Text(String(format: "%+.2f", position.unrealizedPnl))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(position.unrealizedPnl >= 0 ? colors.profit : colors.loss)
            }
        }
        .padding(PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface)
        )
    }
}

// MARK: - 紧凑 KPI 条带
struct CompactKPIStrip: View {
    @Environment(PulseColors.self) private var colors
    let kpis: DashboardKPIs

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
            HStack(spacing: 0) {
                kpiItem(label: "夏普比率", value: String(format: "%.2f", kpis.sharpeRatio), color: PulseColors.accent)
                kpiDivider
                kpiItem(label: "最大回撤", value: String(format: "%.1f%%", kpis.maxDrawdown), color: colors.loss)
                kpiDivider
                kpiItem(label: "胜率", value: String(format: "%.1f%%", kpis.winRate), color: colors.profit)
                kpiDivider
                kpiItem(label: "活跃策略", value: "\(kpis.activeStrategies)", color: PulseColors.cyan)
            }
        }
    }

    private func kpiItem(label: String, value: String, color: Color) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 24)
            .padding(.horizontal, PulseSpacing.sm)
    }
}

// MARK: - 主仪表盘
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
                // Row 1: Hero P&L + 风险警报
                rowHeroAndRisk(kpis)

                // Row 2: 当前持仓水平
                rowPositions

                // Row 3: 权益曲线
                EquityCurveChart(points: viewModel.equityCurve)
                    .frame(maxWidth: .infinity)

                // 数据来源 + 实时指示器
                HStack {
                    DataSourceBadge(status: kpis.dataSource)
                    Spacer()
                    Circle()
                        .fill(PulseColors.statusActive)
                        .frame(width: 6, height: 6)
                }

                // Row 4: 紧凑 KPI 条带
                CompactKPIStrip(kpis: kpis)

                // Row 5: 最近交易 + 相关性热力图
                rowBottom
            }
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - Row 1: Hero PnL (60%) + 风险警报 (40%)

    private func rowHeroAndRisk(_ kpis: DashboardKPIs) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            HeroPnLCard(
                totalPnl: kpis.totalPnl,
                pnlChangePct: kpis.pnlChangePct,
                equityCurve: viewModel.equityCurve,
                todaysTrades: kpis.todaysTrades,
                activeStrategies: kpis.activeStrategies
            )
            .frame(maxWidth: .infinity)

            RiskAlertStrip(events: viewModel.riskEvents)
                .frame(width: 300)
        }
    }

    // MARK: - Row 2: 当前持仓 (水平滚动卡片)

    @ViewBuilder
    private var rowPositions: some View {
        if !viewModel.positions.isEmpty {
            ProofAlphaCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    HStack {
                        TerminalLabel(text: "当前持仓")
                        Spacer()
                        Text("\(viewModel.positions.count) 个")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PulseSpacing.xs) {
                            ForEach(Array(viewModel.positions.enumerated()), id: \.element.id) { index, pos in
                                PositionCard(position: pos)
                                    .frame(width: 200)
                                    .staggeredAppearance(index: index)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row 5: 最近交易 + 相关性

    private var rowBottom: some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            RecentTradesListView(orders: Array(viewModel.orders.prefix(5)))
                .frame(maxWidth: .infinity)

            CorrelationHeatmapView(snapshots: viewModel.correlationSnapshots)
                .frame(width: 340)
        }
    }

    // MARK: - 加载骨架

    private var loadingSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            // Hero + 风险骨架
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 120).shimmer()
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(width: 300, height: 120).shimmer()
            }

            // KPI 骨架
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 40).shimmer()
                }
            }

            // 权益曲线骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 200).shimmer()

            // 底部骨架
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 160).shimmer()
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(width: 340, height: 160).shimmer()
            }
        }
        .padding(PulseSpacing.lg)
    }
}
