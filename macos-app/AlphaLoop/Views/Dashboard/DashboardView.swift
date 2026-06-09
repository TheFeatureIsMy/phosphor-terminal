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
                label: L10n.Dashboard.localGPU,
                value: gpuStatusLabel,
                color: gpuStatusColor
            )
            statusDivider
            statusItem(
                icon: "dollarsign.circle.fill",
                label: L10n.Dashboard.todayAICost,
                value: String(format: "$%.2f", todayCost),
                color: PulseColors.cyan
            )
            statusDivider
            statusItem(
                icon: "gearshape.2.fill",
                label: L10n.Dashboard.pendingTasks,
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
                .font(PulseFonts.monoLabel)
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
        case "degraded": return L10n.Dashboard.providerDegraded
        case "cloud_unavailable": return L10n.Dashboard.providerUnavailable
        default: return L10n.Dashboard.providerNormal
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
        case "active": return L10n.Dashboard.gpuRunning
        case "unavailable": return L10n.Dashboard.gpuUnavailable
        default: return L10n.Dashboard.gpuIdle
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
        KryptonCard(emphasis: .bold) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.aiMarketJudgment)

                HStack(alignment: .top, spacing: PulseSpacing.lg) {
                    VStack(spacing: PulseSpacing.xxs) {
                        Text(judgment.direction)
                            .font(PulseFonts.displayLarge)
                            .foregroundStyle(directionColor)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)

                        Image(systemName: directionIcon)
                            .font(PulseFonts.displayHeading)
                            .foregroundStyle(directionColor)
                    }
                    .frame(minWidth: 90)

                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                            HStack {
                                Text(L10n.Dashboard.confidence)
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
                                    .font(PulseFonts.micro)
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
        case "看多", "Bullish": return colors.profit
        case "看空", "Bearish": return colors.loss
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
        case "low": return L10n.Dashboard.riskLow
        case "high": return L10n.Dashboard.riskHigh
        case "critical": return L10n.Dashboard.riskCritical
        default: return L10n.Dashboard.riskMedium
        }
    }
}

// MARK: - P0: Positions + Risk Card (当前持仓 + 风险状态)

struct PositionsRiskCard: View {
    @Environment(PulseColors.self) private var colors
    let positions: [PositionWithAI]

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: L10n.Dashboard.positionsAndRisk)
                    Spacer()
                    Text(L10n.Dashboard.positionCount(positions.count))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                if positions.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text(L10n.Dashboard.noActivePositions)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.vertical, PulseSpacing.sm)
                } else {
                    HStack(spacing: 0) {
                        Text(L10n.Dashboard.symbol).frame(width: 100, alignment: .leading)
                        Text(L10n.Dashboard.direction).frame(width: 50, alignment: .center)
                        Text(L10n.Dashboard.pnl).frame(width: 100, alignment: .trailing)
                        Text(L10n.Dashboard.aiSuggestion).frame(width: 90, alignment: .center)
                        Text(L10n.Dashboard.risk).frame(width: 70, alignment: .center)
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

            Text(position.direction == "long" ? L10n.Dashboard.long : L10n.Dashboard.short)
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
        case "hold": return L10n.Dashboard.hold
        case "reduce": return L10n.Dashboard.reduce
        case "take-profit": return L10n.Dashboard.takeProfit
        case "close": return L10n.Dashboard.closePosition
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
        case "low": return L10n.Dashboard.riskLevelLow
        case "high": return L10n.Dashboard.riskLevelHigh
        default: return L10n.Dashboard.riskLevelMedium
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
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: L10n.Dashboard.pendingConfirmations)
                    Spacer()
                    if !confirmations.isEmpty {
                        BadgeDot(color: PulseColors.amber, label: "\(confirmations.count)", size: .small)
                    }
                }

                if confirmations.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text(L10n.Dashboard.noPendingItems)
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
                    .font(PulseFonts.caption)
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
                        Text(L10n.Dashboard.reject)
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
                        Text(L10n.Dashboard.approve)
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
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.agentSignalDist)

                if groups.isEmpty {
                    Text(L10n.Dashboard.noSignalData)
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
                            Text(L10n.Dashboard.bullish).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                        HStack(spacing: PulseSpacing.xxs) {
                            Circle().fill(colors.loss).frame(width: 6, height: 6)
                            Text(L10n.Dashboard.bearish).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
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
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.strategyOverview)

                HStack(spacing: 0) {
                    statusCell(label: L10n.Dashboard.draft, count: summary.draft, color: colors.textMuted)
                    cellDivider
                    statusCell(label: L10n.Dashboard.running, count: summary.active, color: PulseColors.accent)
                    cellDivider
                    statusCell(label: L10n.Dashboard.dryRun, count: summary.dryRunning, color: PulseColors.cyan)
                    cellDivider
                    statusCell(label: L10n.Dashboard.paused, count: summary.paused, color: PulseColors.amber)
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
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.riskInterception)

                let total = summary.rejected + summary.reduced + summary.paperOnly + summary.allowed
                HStack(spacing: 0) {
                    statCell(label: L10n.Dashboard.rejected, count: summary.rejected, color: PulseColors.danger, total: total)
                    cellDivider
                    statCell(label: L10n.Dashboard.reduced, count: summary.reduced, color: PulseColors.amber, total: total)
                    cellDivider
                    statCell(label: L10n.Dashboard.paperOnly, count: summary.paperOnly, color: PulseColors.cyan, total: total)
                    cellDivider
                    statCell(label: L10n.Dashboard.allowed, count: summary.allowed, color: PulseColors.accent, total: total)
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
                        .font(PulseFonts.captionMedium)
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
    @Environment(SettingsState.self) private var settingsState
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
            TradingWorkflowRailView(workflow: viewModel.dailyWorkflow)
                .staggeredAppearance(index: 0)

            AIStatusBar(
                providerStatus: viewModel.aiProviderStatus,
                gpuStatus: viewModel.gpuStatus,
                todayCost: viewModel.todayAICost,
                pendingJobs: viewModel.pendingAIJobs
            )
            .staggeredAppearance(index: 0)

            if let judgment = viewModel.aiMarketJudgment {
                AIMarketJudgmentCard(judgment: judgment)
                    .staggeredAppearance(index: 1)
            }

            PositionsRiskCard(positions: viewModel.positions)
                .staggeredAppearance(index: 2)

            PendingConfirmationsCard(
                confirmations: viewModel.pendingConfirmations,
                onApprove: { viewModel.approveConfirmation($0) },
                onReject: { viewModel.rejectConfirmation($0) }
            )
            .staggeredAppearance(index: 3)

            // 可展开分析区域 — 替代原生 DisclosureGroup
            PulseExpandableSection {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(PulseFonts.label)
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.Dashboard.moreAnalysis)
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
            .staggeredAppearance(index: 4)

            if viewModel.aiMarketJudgment == nil && !viewModel.isLoading {
                EmptyStateView(
                    icon: "brain.head.profile",
                    title: L10n.Dashboard.aiControlTower,
                    description: L10n.Dashboard.waitingForData
                )
                .staggeredAppearance(index: 5)
            }
        }
        .padding(PulseSpacing.lg)
        .id(settingsState.language)
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
