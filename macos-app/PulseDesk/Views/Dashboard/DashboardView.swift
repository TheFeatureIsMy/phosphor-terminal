// DashboardView.swift — 主仪表盘布局
// 按信息重要程度分层：P&L Hero → 风险 → 持仓 → 权益曲线 → KPI条带 → 交易+相关性

import SwiftUI
import Charts

// MARK: - Hero PnL 卡片 (最大视觉权重, 无冗余走势图)
struct HeroPnLCard: View {
    @Environment(PulseColors.self) private var colors
    let totalPnl: Double
    let pnlChangePct: Double
    let todaysTrades: Int
    let activeStrategies: Int
    let openPositions: Int
    let systemUptime: String

    @State private var appeared = false

    var body: some View {
        ProofAlphaCard(emphasis: .bold) {
            HStack(alignment: .top, spacing: PulseSpacing.lg) {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    TerminalLabel(text: "总盈亏 (P&L)")

                    Text(pnlFormatted)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundStyle(totalPnl >= 0 ? colors.profit : colors.loss)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    HStack(spacing: PulseSpacing.md) {
                        trendBadge
                        contextPill(icon: "arrow.left.arrow.right", value: "\(todaysTrades)", label: "交易")
                        contextPill(icon: "brain.head.profile", value: "\(activeStrategies)", label: "策略")
                        contextPill(icon: "briefcase", value: "\(openPositions)", label: "持仓")
                    }
                }

                Spacer()

                // System status on the right
                VStack(alignment: .trailing, spacing: PulseSpacing.xxs) {
                    HStack(spacing: PulseSpacing.xxs) {
                        StatusDot(status: .online)
                        Text("运行中").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    }
                    Text(systemUptime).font(PulseFonts.monoLabel).foregroundStyle(colors.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { appeared = true }
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

    private func contextPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(value).font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        }
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

// MARK: - 持仓行 (可展开详情)
struct RichPositionRow: View {
    @Environment(PulseColors.self) private var colors
    let position: Position

    @State private var isExpanded = false

    private var pnlPercent: Double {
        let cost = position.quantity * position.avgPrice
        guard cost != 0 else { return 0 }
        return (position.unrealizedPnl / cost) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: PulseSpacing.sm) {
                    // PnL color bar
                    RoundedRectangle(cornerRadius: 1)
                        .fill(position.unrealizedPnl >= 0 ? colors.profit : colors.loss)
                        .frame(width: 3, height: 40)

                    // Symbol + side
                    VStack(alignment: .leading, spacing: 1) {
                        Text(position.symbol)
                            .font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
                        HStack(spacing: PulseSpacing.xxs) {
                            Text(position.side.label)
                                .font(PulseFonts.micro)
                                .foregroundStyle(position.side.color(colors))
                            Text("·").foregroundStyle(colors.textMuted)
                            Text("开仓 @ \(String(format: "%.2f", position.avgPrice))")
                                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                    }

                    Spacer()

                    // Key metrics
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%+.2f", position.unrealizedPnl))
                            .font(PulseFonts.tabular).fontWeight(.medium)
                            .foregroundStyle(position.unrealizedPnl >= 0 ? colors.profit : colors.loss)
                        Text("\(String(format: "%.4f", position.quantity)) · \(String(format: "%.1f%%", pnlPercent))")
                            .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundStyle(colors.textMuted)
                        .frame(width: 16)
                }
                .padding(.vertical, PulseSpacing.sm)
                .padding(.horizontal, PulseSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(spacing: PulseSpacing.xs) {
                    Divider().foregroundStyle(colors.border)
                    HStack(spacing: PulseSpacing.lg) {
                        detailItem("数量", String(format: "%.4f", position.quantity))
                        detailItem("均价", String(format: "%.2f", position.avgPrice))
                        detailItem("止损", position.stopLossPrice.map { String(format: "%.2f", $0) } ?? "未设置")
                        detailItem("止盈", position.takeProfitPrice.map { String(format: "%.2f", $0) } ?? "未设置")
                        detailItem("开仓时间", formatDate(position.openedAt))
                    }
                    .font(PulseFonts.caption)
                }
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.bottom, PulseSpacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.4))
        )
    }

    private func detailItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
        }
    }

    private func formatDate(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return iso }
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f.string(from: d)
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
                // Row 1: Hero P&L (full width)
                rowHero(kpis)

                // Row 2: 风险事件 (compact strip)
                RiskAlertStrip(events: viewModel.riskEvents)

                // Row 3: 当前持仓 (expandable list)
                if !viewModel.positions.isEmpty {
                    rowPositions
                }

                // Row 4: 权益曲线
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

                // Row 5: 紧凑 KPI 条带
                CompactKPIStrip(kpis: kpis)

                // Row 6: 最近交易 + 相关性热力图
                rowBottom
            }
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - Row 1: Hero PnL

    private func rowHero(_ kpis: DashboardKPIs) -> some View {
        HeroPnLCard(
            totalPnl: kpis.totalPnl,
            pnlChangePct: kpis.pnlChangePct,
            todaysTrades: kpis.todaysTrades,
            activeStrategies: kpis.activeStrategies,
            openPositions: kpis.openPositions,
            systemUptime: viewModel.systemStatus?.uptime ?? "--"
        )
    }

    // MARK: - Row 3: 当前持仓 (expandable rich list)

    @ViewBuilder
    private var rowPositions: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack {
                    TerminalLabel(text: "当前持仓")
                    Spacer()
                    Text("\(viewModel.positions.count) 个")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                VStack(spacing: PulseSpacing.xxs) {
                    ForEach(Array(viewModel.positions.enumerated()), id: \.element.id) { index, pos in
                        RichPositionRow(position: pos)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    // MARK: - Row 6: 最近交易 + 相关性

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
            // Hero 骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 120).shimmer()

            // 风险骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 60).shimmer()

            // 持仓骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 200).shimmer()

            // 权益曲线骨架
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 200).shimmer()

            // KPI 骨架
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 40).shimmer()
                }
            }

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
