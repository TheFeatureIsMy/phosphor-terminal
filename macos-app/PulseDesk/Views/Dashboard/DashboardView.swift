// DashboardView.swift — AI 总控台 (AI Control Tower)
// P0: AI 市场判断 / 持仓+风险 / 待确认事项
// P1/P2: Agent 信号分布 / 策略状态 / 权益曲线 / 风险拦截统计

import SwiftUI
import Charts

// MARK: - AI Status Bar (顶部状态栏)

struct AIStatusBar: View {
    @Environment(PulseColors.self) private var colors
    let providerStatus: String
    let gpuStatus: String
    let todayCost: Double
    let pendingJobs: Int

    var body: some View {
        HStack(spacing: 0) {
            statusItem(
                icon: "cloud.fill",
                label: "AI Provider",
                value: providerStatusLabel,
                color: providerStatusColor
            )
            statusDivider
            statusItem(
                icon: "cpu.fill",
                label: "本地 GPU",
                value: gpuStatusLabel,
                color: gpuStatusColor
            )
            statusDivider
            statusItem(
                icon: "dollarsign.circle.fill",
                label: "今日 AI 成本",
                value: String(format: "$%.2f", todayCost),
                color: PulseColors.cyan
            )
            statusDivider
            statusItem(
                icon: "gearshape.2.fill",
                label: "待处理任务",
                value: "\(pendingJobs)",
                color: pendingJobs > 0 ? PulseColors.amber : PulseColors.accent
            )
        }
        .padding(.vertical, PulseSpacing.xs)
        .padding(.horizontal, PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    private func statusItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Text(value)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 28)
            .padding(.horizontal, PulseSpacing.xs)
    }

    private var providerStatusLabel: String {
        switch providerStatus {
        case "degraded": return "降级"
        case "cloud_unavailable": return "不可用"
        default: return "正常"
        }
    }

    private var providerStatusColor: Color {
        switch providerStatus {
        case "degraded": return PulseColors.amber
        case "cloud_unavailable": return PulseColors.danger
        default: return PulseColors.accent
        }
    }

    private var gpuStatusLabel: String {
        switch gpuStatus {
        case "active": return "运行中"
        case "unavailable": return "不可用"
        default: return "空闲"
        }
    }

    private var gpuStatusColor: Color {
        switch gpuStatus {
        case "active": return PulseColors.accent
        case "unavailable": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}

// MARK: - P0: AI Market Judgment Card (今日 AI 市场判断)

struct AIMarketJudgmentCard: View {
    @Environment(PulseColors.self) private var colors
    let judgment: AIMarketJudgment

    @State private var appeared = false

    var body: some View {
        ProofAlphaCard(emphasis: .bold) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "今日 AI 市场判断")

                HStack(alignment: .top, spacing: PulseSpacing.lg) {
                    VStack(spacing: PulseSpacing.xxs) {
                        Text(judgment.direction)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(directionColor)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)

                        Image(systemName: directionIcon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(directionColor)
                    }
                    .frame(minWidth: 90)

                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                            HStack {
                                Text("置信度")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textMuted)
                                Spacer()
                                Text(String(format: "%.0f%%", judgment.confidence * 100))
                                    .font(PulseFonts.tabular)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                                        .fill(colors.surface)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                                        .fill(directionColor)
                                        .frame(width: geo.size.width * judgment.confidence, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        HStack(spacing: PulseSpacing.md) {
                            BadgeDot(color: riskColor, label: riskLabel, size: .small)

                            HStack(spacing: PulseSpacing.xxs) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 9))
                                    .foregroundStyle(colors.textMuted)
                                Text(judgment.sourceAgent)
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textSecondary)
                            }
                        }

                        Text(judgment.reasoning)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(3)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { appeared = true }
        }
    }

    private var directionColor: Color {
        switch judgment.direction {
        case "看多": return colors.profit
        case "看空": return colors.loss
        default: return PulseColors.amber
        }
    }

    private var directionIcon: String {
        switch judgment.direction {
        case "看多": return "arrow.up.right"
        case "看空": return "arrow.down.right"
        default: return "arrow.left.arrow.right"
        }
    }

    private var riskColor: Color {
        switch judgment.riskLevel {
        case "low": return PulseColors.success
        case "high": return PulseColors.amber
        case "critical": return PulseColors.danger
        default: return PulseColors.warning
        }
    }

    private var riskLabel: String {
        switch judgment.riskLevel {
        case "low": return "低风险"
        case "high": return "高风险"
        case "critical": return "极高风险"
        default: return "中风险"
        }
    }
}

// MARK: - P0: Positions + Risk Card (当前持仓 + 风险状态)

struct PositionsRiskCard: View {
    @Environment(PulseColors.self) private var colors
    let positions: [PositionWithAI]

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: "当前持仓 + 风险状态")
                    Spacer()
                    Text("\(positions.count) 个持仓")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                if positions.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("无活跃持仓")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.vertical, PulseSpacing.sm)
                } else {
                    HStack(spacing: 0) {
                        Text("品种").frame(width: 100, alignment: .leading)
                        Text("方向").frame(width: 50, alignment: .center)
                        Text("盈亏").frame(width: 100, alignment: .trailing)
                        Text("AI 建议").frame(width: 90, alignment: .center)
                        Text("风险").frame(width: 70, alignment: .center)
                    }
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.horizontal, PulseSpacing.xxs)

                    Divider().foregroundStyle(colors.border)

                    VStack(spacing: PulseSpacing.xxs) {
                        ForEach(Array(positions.enumerated()), id: \.element.id) { index, pos in
                            PositionAIRow(position: pos)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }
}

struct PositionAIRow: View {
    @Environment(PulseColors.self) private var colors
    let position: PositionWithAI

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: PulseSpacing.xxs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(position.pnl >= 0 ? colors.profit : colors.loss)
                    .frame(width: 3, height: 24)
                Text(position.symbol)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
            }
            .frame(width: 100, alignment: .leading)

            Text(position.direction == "long" ? "多" : "空")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(position.direction == "long" ? colors.profit : colors.loss)
                .frame(width: 50, alignment: .center)

            VStack(alignment: .trailing, spacing: 0) {
                Text(String(format: "%+.2f", position.pnl))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(position.pnl >= 0 ? colors.profit : colors.loss)
                Text(String(format: "%+.1f%%", position.pnlPercent))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            .frame(width: 100, alignment: .trailing)

            Text(recommendationLabel)
                .font(PulseFonts.micro)
                .foregroundStyle(recommendationColor)
                .padding(.horizontal, PulseSpacing.xxs)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(recommendationColor.opacity(0.1))
                )
                .frame(width: 90, alignment: .center)

            BadgeDot(color: riskColor, label: riskLabel, size: .small)
                .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, PulseSpacing.xxs)
        .padding(.horizontal, PulseSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.4))
        )
    }

    private var recommendationLabel: String {
        switch position.aiRecommendation {
        case "hold": return "持有"
        case "reduce": return "减仓"
        case "take-profit": return "止盈"
        case "close": return "平仓"
        default: return position.aiRecommendation
        }
    }

    private var recommendationColor: Color {
        switch position.aiRecommendation {
        case "hold": return PulseColors.accent
        case "reduce": return PulseColors.amber
        case "take-profit": return PulseColors.cyan
        case "close": return PulseColors.danger
        default: return colors.textSecondary
        }
    }

    private var riskColor: Color {
        switch position.riskLevel {
        case "low": return PulseColors.success
        case "high": return PulseColors.danger
        default: return PulseColors.warning
        }
    }

    private var riskLabel: String {
        switch position.riskLevel {
        case "low": return "低"
        case "high": return "高"
        default: return "中"
        }
    }
}

// MARK: - P0: Pending Confirmations Card (需人工确认事项)

struct PendingConfirmationsCard: View {
    @Environment(PulseColors.self) private var colors
    let confirmations: [PendingConfirmation]
    let onApprove: (String) -> Void
    let onReject: (String) -> Void

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: "需人工确认事项")
                    Spacer()
                    if !confirmations.isEmpty {
                        BadgeDot(color: PulseColors.amber, label: "\(confirmations.count)", size: .small)
                    }
                }

                if confirmations.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("无待处理事项")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.vertical, PulseSpacing.sm)
                } else {
                    VStack(spacing: PulseSpacing.xs) {
                        ForEach(Array(confirmations.enumerated()), id: \.element.id) { index, item in
                            ConfirmationRow(item: item, onApprove: onApprove, onReject: onReject)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }
}

struct ConfirmationRow: View {
    @Environment(PulseColors.self) private var colors
    let item: PendingConfirmation
    let onApprove: (String) -> Void
    let onReject: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: typeIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(typeColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(item.description)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: PulseSpacing.xs) {
                    Button {
                        onReject(item.id)
                    } label: {
                        Text("拒绝")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .padding(.horizontal, PulseSpacing.xs)
                            .padding(.vertical, PulseSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.button)
                                    .stroke(colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onApprove(item.id)
                    } label: {
                        Text("批准")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.background)
                            .padding(.horizontal, PulseSpacing.xs)
                            .padding(.vertical, PulseSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.button)
                                    .fill(PulseColors.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.4))
        )
    }

    private var typeIcon: String {
        switch item.type {
        case "strategy_deploy": return "arrow.up.doc.fill"
        case "dry_run": return "play.circle.fill"
        case "risk_release": return "lock.open.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case "strategy_deploy": return PulseColors.cyan
        case "dry_run": return PulseColors.accent
        case "risk_release": return PulseColors.amber
        default: return colors.textMuted
        }
    }
}

// MARK: - P1: Agent Signal Distribution (Agent 信号分布)

struct AgentSignalDistributionView: View {
    @Environment(PulseColors.self) private var colors
    let groups: [AgentSignalGroup]

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "Agent 信号分布")

                if groups.isEmpty {
                    Text("暂无信号数据")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                } else {
                    VStack(spacing: PulseSpacing.xxs) {
                        ForEach(groups) { group in
                            HStack(spacing: PulseSpacing.sm) {
                                Text(group.agentName)
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textPrimary)
                                    .frame(width: 120, alignment: .leading)

                                GeometryReader { geo in
                                    let total = max(group.signalCount, 1)
                                    let longWidth = geo.size.width * CGFloat(group.longCount) / CGFloat(total)
                                    HStack(spacing: 1) {
                                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                                            .fill(colors.profit)
                                            .frame(width: max(longWidth, 0), height: 12)
                                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                                            .fill(colors.loss)
                                            .frame(height: 12)
                                    }
                                }
                                .frame(height: 12)

                                Text("\(group.signalCount)")
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }

                    HStack(spacing: PulseSpacing.md) {
                        HStack(spacing: PulseSpacing.xxs) {
                            Circle().fill(colors.profit).frame(width: 6, height: 6)
                            Text("看多").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                        HStack(spacing: PulseSpacing.xxs) {
                            Circle().fill(colors.loss).frame(width: 6, height: 6)
                            Text("看空").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                    }
                    .padding(.top, PulseSpacing.xxs)
                }
            }
        }
    }
}

// MARK: - P1: Strategy Status Overview (策略状态总览)

struct StrategyStatusOverviewCard: View {
    @Environment(PulseColors.self) private var colors
    let summary: StrategyStatusSummary

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "策略状态总览")

                HStack(spacing: 0) {
                    statusCell(label: "草稿", count: summary.draft, color: colors.textMuted)
                    cellDivider
                    statusCell(label: "运行中", count: summary.active, color: PulseColors.accent)
                    cellDivider
                    statusCell(label: "模拟盘", count: summary.dryRunning, color: PulseColors.cyan)
                    cellDivider
                    statusCell(label: "已暂停", count: summary.paused, color: PulseColors.amber)
                }
            }
        }
    }

    private func statusCell(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Text("\(count)")
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var cellDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 36)
            .padding(.horizontal, PulseSpacing.xs)
    }
}

// MARK: - P2: Risk Interception Stats (风险拦截统计)

struct RiskInterceptionStatsCard: View {
    @Environment(PulseColors.self) private var colors
    let summary: RiskInterceptionSummary

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "风险拦截统计")

                let total = summary.rejected + summary.reduced + summary.paperOnly + summary.allowed
                HStack(spacing: 0) {
                    statCell(label: "已拒绝", count: summary.rejected, color: PulseColors.danger, total: total)
                    cellDivider
                    statCell(label: "已减仓", count: summary.reduced, color: PulseColors.amber, total: total)
                    cellDivider
                    statCell(label: "仅模拟", count: summary.paperOnly, color: PulseColors.cyan, total: total)
                    cellDivider
                    statCell(label: "已放行", count: summary.allowed, color: PulseColors.accent, total: total)
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    let t = max(Double(total), 1)
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(PulseColors.danger)
                            .frame(width: w * Double(summary.rejected) / t)
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(PulseColors.amber)
                            .frame(width: w * Double(summary.reduced) / t)
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(PulseColors.cyan)
                            .frame(width: w * Double(summary.paperOnly) / t)
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(PulseColors.accent)
                            .frame(width: w * Double(summary.allowed) / t)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func statCell(label: String, count: Int, color: Color, total: Int) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Text("\(count)")
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var cellDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 28)
            .padding(.horizontal, PulseSpacing.xs)
    }
}

// MARK: - Custom Expandable Section (替代原生 DisclosureGroup)

struct PulseExpandableSection<Label: View, Content: View>: View {
    @Environment(PulseColors.self) private var colors
    @State private var isExpanded = false
    let label: () -> Label
    let content: () -> Content

    var body: some View {
        VStack(spacing: PulseSpacing.sm) {
            Button {
                withAnimation(PulseAnimation.springDefault) { isExpanded.toggle() }
            } label: {
                HStack {
                    label()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, PulseSpacing.xs)
                .padding(.horizontal, PulseSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(colors.surface.opacity(0.4))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Main Dashboard View (AI 总控台)

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

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: PulseSpacing.lg) {
            AIStatusBar(
                providerStatus: viewModel.aiProviderStatus,
                gpuStatus: viewModel.gpuStatus,
                todayCost: viewModel.todayAICost,
                pendingJobs: viewModel.pendingAIJobs
            )

            if let judgment = viewModel.aiMarketJudgment {
                AIMarketJudgmentCard(judgment: judgment)
            }

            PositionsRiskCard(positions: viewModel.positions)

            PendingConfirmationsCard(
                confirmations: viewModel.pendingConfirmations,
                onApprove: { viewModel.approveConfirmation($0) },
                onReject: { viewModel.rejectConfirmation($0) }
            )

            // 可展开分析区域 — 替代原生 DisclosureGroup
            PulseExpandableSection {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 12))
                        .foregroundStyle(PulseColors.accent)
                    Text("更多分析")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                }
            } content: {
                VStack(spacing: PulseSpacing.md) {
                    AgentSignalDistributionView(groups: viewModel.agentSignalDistribution)

                    if let summary = viewModel.strategyStatusSummary {
                        StrategyStatusOverviewCard(summary: summary)
                    }

                    if !viewModel.equityCurve.isEmpty {
                        EquityCurveChart(points: viewModel.equityCurve)
                    }

                    if let riskStats = viewModel.riskInterceptions {
                        RiskInterceptionStatsCard(summary: riskStats)
                    }
                }
            }

            if viewModel.aiMarketJudgment == nil && !viewModel.isLoading {
                EmptyStateView(
                    icon: "brain.head.profile",
                    title: "AI 总控台",
                    description: "等待 AI Agent 数据加载..."
                )
            }
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 52).shimmer()

            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 160).shimmer()

            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 180).shimmer()

            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface).frame(height: 120).shimmer()
        }
        .padding(PulseSpacing.lg)
    }
}
