// RiskView.swift — 风险管理控制台

import SwiftUI

struct RiskView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var riskEvents: [RiskEvent] = []
    @State private var correlation: [CorrelationSnapshot] = []
    @State private var isLoading = true
    @State private var showEmergencyConfirm = false
    @State private var emergencyResult: EmergencyStopResult?
    @State private var isEmergencyLoading = false
    @State private var selectedCategory: RiskCategory = .global
    @State private var liveSmallStrategyId = ""
    @State private var liveSmallResult: LiveSmallEvaluation?
    @State private var isEvaluatingLiveSmall = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    pageHeader
                    riskCategoryBar
                    emergencyStopSection
                    riskOverviewCards
                    severityBreakdown
                    categoryMetrics
                    riskEventsList
                    topCorrelations
                    liveSmallApprovalSection
                }
                .padding(PulseSpacing.lg)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await loadData() }
        .alert("紧急停止确认", isPresented: $showEmergencyConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认停止", role: .destructive) {
                Task { await executeEmergencyStop() }
            }
        } message: {
            Text("确定要执行全局紧急停止吗？所有策略将立即停止，所有挂单撤销，持仓市价平仓。此操作不可撤销。")
        }
    }

    // MARK: - Emergency Stop Section

    @ViewBuilder
    private var emergencyStopSection: some View {
        ProofAlphaCard(emphasis: .bold) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: "shield.lefthalf.filled.slash")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PulseColors.danger)
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("紧急停止")
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(PulseColors.danger)
                        Text("立即停止所有策略运行、撤销挂单、市价平仓")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    if isEmergencyLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        ProofAlphaButton(title: "紧急停止", action: {
                            showEmergencyConfirm = true
                        }, style: .ghost)
                        .tint(PulseColors.danger)
                    }
                }

                if let result = emergencyResult {
                    Divider().foregroundStyle(colors.border)

                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        HStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PulseColors.warning)
                            Text(result.message)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textPrimary)
                        }
                        HStack(spacing: PulseSpacing.xxs) {
                            Text("已停止 \(result.stoppedRuns.count) 个运行")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    HStack {
                        Spacer()
                        ForEach(result.stoppedRuns, id: \.self) { runId in
                            Button {
                                Task { await resumeStrategy(runId: runId) }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 9))
                                    Text("恢复 \(String(runId.suffix(4)))")
                                        .font(PulseFonts.micro)
                                }
                                .foregroundStyle(PulseColors.success)
                                .padding(.horizontal, PulseSpacing.xs)
                                .padding(.vertical, PulseSpacing.xxs)
                                .background(
                                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                                        .fill(PulseColors.success.opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(PulseColors.danger.opacity(0.3), lineWidth: 1)
        )
    }

    private func executeEmergencyStop() async {
        isEmergencyLoading = true
        defer { isEmergencyLoading = false }
        let api = APIEmergency(client: networkClient)
        do {
            emergencyResult = try await api.emergencyStop(reason: "手动紧急停止")
        } catch {
            emergencyResult = EmergencyStopResult(stoppedRuns: [], message: "紧急停止失败: \(error.localizedDescription)")
        }
    }

    private func resumeStrategy(runId: String) async {
        let api = APIEmergency(client: networkClient)
        do {
            let resumeResult = try await api.emergencyResume(strategyRunId: runId)
            // Remove resumed run from the result
            if var current = emergencyResult {
                let remaining = current.stoppedRuns.filter { $0 != runId }
                if remaining.isEmpty {
                    emergencyResult = nil
                } else {
                    emergencyResult = EmergencyStopResult(stoppedRuns: remaining, message: current.message)
                }
            }
        } catch {
            // Keep current state on failure
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text("风险管理")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: riskEvents.isEmpty ? .online : .loading)
                    Text(riskEvents.isEmpty ? "风险可控" : "需要关注")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Overview Cards

    private var riskOverviewCards: some View {
        HStack(spacing: PulseSpacing.md) {
            StatCard(
                icon: "exclamationmark.triangle.fill",
                label: "风险事件",
                value: "\(riskEvents.count)",
                color: severityColor(.critical)
            )
            StatCard(
                icon: "bell.badge.fill",
                label: "活跃告警",
                value: "\(activeAlertsCount)",
                color: PulseColors.warning
            )
            StatCard(
                icon: "arrow.triangle.branch",
                label: "相关性对",
                value: "\(correlation.count)",
                color: PulseColors.info
            )
            StatCard(
                icon: "gauge.with.dots.needle.33percent",
                label: "风险评分",
                value: riskScore,
                color: riskScoreColor
            )
        }
    }

    private var activeAlertsCount: Int {
        riskEvents.filter { $0.severity == .high || $0.severity == .critical }.count
    }

    private var riskScore: String {
        guard !riskEvents.isEmpty else { return "低" }
        let criticalCount = riskEvents.filter { $0.severity == .critical }.count
        let highCount = riskEvents.filter { $0.severity == .high }.count
        if criticalCount > 0 { return "严重" }
        if highCount > 2 { return "偏高" }
        if highCount > 0 { return "中等" }
        return "低"
    }

    private var riskScoreColor: Color {
        switch riskScore {
        case "严重": return PulseColors.danger
        case "偏高": return PulseColors.warning
        case "中等": return PulseColors.amber
        default: return PulseColors.success
        }
    }

    // MARK: - Severity Breakdown Bar

    private var severityBreakdown: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "严重性分布")

                let total = max(severityCounts.total, 1)

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        segBar(count: severityCounts.critical, total: total, totalWidth: geo.size.width, color: PulseColors.danger)
                        segBar(count: severityCounts.high, total: total, totalWidth: geo.size.width, color: PulseColors.amber)
                        segBar(count: severityCounts.medium, total: total, totalWidth: geo.size.width, color: PulseColors.warning)
                        segBar(count: severityCounts.low, total: total, totalWidth: geo.size.width, color: PulseColors.success)
                    }
                }
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack(spacing: PulseSpacing.lg) {
                    severityLegend("严重", count: severityCounts.critical, color: PulseColors.danger)
                    severityLegend("高", count: severityCounts.high, color: PulseColors.amber)
                    severityLegend("中", count: severityCounts.medium, color: PulseColors.warning)
                    severityLegend("低", count: severityCounts.low, color: PulseColors.success)
                }
            }
        }
    }

    private var severityCounts: (critical: Int, high: Int, medium: Int, low: Int, total: Int) {
        let c = riskEvents.filter { $0.severity == .critical }.count
        let h = riskEvents.filter { $0.severity == .high }.count
        let m = riskEvents.filter { $0.severity == .medium }.count
        let l = riskEvents.filter { $0.severity == .low }.count
        return (c, h, m, l, c + h + m + l)
    }

    private func segBar(count: Int, total: Int, totalWidth: CGFloat, color: Color) -> some View {
        let fraction = total > 0 ? CGFloat(count) / CGFloat(total) : CGFloat(0)
        return Rectangle()
            .fill(count > 0 ? color : Color.clear)
            .frame(width: totalWidth * fraction)
    }

    private func severityLegend(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    private func severityColor(_ severity: RiskSeverity) -> Color {
        severity.color
    }

    // MARK: - Risk Events List

    @ViewBuilder
    private var riskEventsList: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "事件记录")

                if riskEvents.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("暂无风险事件")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    VStack(spacing: PulseSpacing.xxs) {
                        ForEach(Array(riskEvents.enumerated()), id: \.element.id) { index, event in
                            richEventRow(event)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }

    private func richEventRow(_ event: RiskEvent) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            // Severity indicator bar
            RoundedRectangle(cornerRadius: 1)
                .fill(event.severity.color)
                .frame(width: 3, height: 36)

            // Icon circle
            Circle()
                .fill(event.severity.color.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: event.severity.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(event.severity.color)
                )

            // Description + meta
            VStack(alignment: .leading, spacing: 1) {
                Text(event.description ?? "无描述")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: PulseSpacing.sm) {
                    if let action = event.actionTaken {
                        Text(action)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.accent)
                    }
                    Text(String(event.createdAt.prefix(16)))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }

            Spacer()

            BadgeDot(color: event.severity.color, label: event.severity.rawValue, size: .small)
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Top Correlations

    @ViewBuilder
    private var topCorrelations: some View {
        if !correlation.isEmpty {
            ProofAlphaCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    TerminalLabel(text: "顶级相关性")

                    ForEach(Array(correlation.prefix(8).enumerated()), id: \.element.id) { index, snap in
                        HStack(spacing: PulseSpacing.sm) {
                            HStack(spacing: 0) {
                                Text(String(snap.symbolA.prefix(6)))
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textPrimary)
                                Text(" ↔ ")
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                                Text(String(snap.symbolB.prefix(6)))
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            Spacer()
                            Text(String(format: "%.3f", snap.correlation))
                                .font(PulseFonts.tabular.weight(.medium))
                                .foregroundStyle(correlationColor(snap.correlation))
                            // Mini correlation bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(correlationColor(snap.correlation))
                                .frame(width: abs(snap.correlation) * 60, height: 4)
                        }
                        .staggeredAppearance(index: index, baseDelay: 0.03)
                    }
                }
            }
        }
    }

    private func correlationColor(_ val: Double) -> Color {
        if val > 0.7 { return PulseColors.danger }
        if val > 0.4 { return PulseColors.warning }
        if val < -0.4 { return PulseColors.info }
        return colors.textMuted
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let dashboard = APIDashboard(client: networkClient)
        riskEvents = (try? await dashboard.getRiskEvents()) ?? []
        correlation = (try? await dashboard.getCorrelation()) ?? []
    }

    // MARK: - Live Small 审批

    private var liveSmallApprovalSection: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "实盘小资金审批")

                HStack(spacing: PulseSpacing.md) {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("策略版本 ID")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textSecondary)
                        TextField("输入策略版本 ID...", text: $liveSmallStrategyId)
                            .darkTextField()
                    }

                    ProofAlphaButton(
                        title: isEvaluatingLiveSmall ? "评估中..." : "预检评估",
                        action: { Task { await evaluateLiveSmall() } }
                    )
                    .opacity(liveSmallStrategyId.isEmpty || isEvaluatingLiveSmall ? 0.5 : 1)
                    .disabled(liveSmallStrategyId.isEmpty || isEvaluatingLiveSmall)
                }

                if let result = liveSmallResult {
                    Divider().foregroundStyle(colors.border)

                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        HStack {
                            BadgeDot(
                                color: result.canExecute ? PulseColors.success : PulseColors.danger,
                                label: result.canExecute ? "可执行" : "不通过",
                                size: .medium
                            )
                            Spacer()
                            if result.requiresHumanConfirm {
                                BadgeDot(color: PulseColors.amber, label: "需人工确认", size: .small)
                            }
                        }

                        if let gates = result.preconditions {
                            ForEach(Array(gates.enumerated()), id: \.offset) { _, gate in
                                HStack(spacing: PulseSpacing.xs) {
                                    Image(systemName: gate.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(gate.passed ? PulseColors.success : PulseColors.danger)
                                    Text(gate.gateName)
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(colors.textPrimary)
                                    Spacer()
                                    if let msg = gate.message {
                                        Text(msg)
                                            .font(PulseFonts.micro)
                                            .foregroundStyle(colors.textMuted)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func evaluateLiveSmall() async {
        isEvaluatingLiveSmall = true
        liveSmallResult = nil
        let api = APILiveSmall(client: networkClient)
        let body: [String: Any] = ["strategy_version_id": liveSmallStrategyId]
        liveSmallResult = try? await api.evaluate(body: body)
        isEvaluatingLiveSmall = false
    }
}

// MARK: - Risk Categories

enum RiskCategory: String, CaseIterable, Identifiable {
    case global = "全局风控"
    case portfolio = "投资组合"
    case correlation = "相关性"
    case agent = "AI/Agent"
    case signalConflict = "信号冲突"
    case manipulation = "操纵风控"
    case connection = "连接风控"
    case simulation = "模拟异常"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .global: return "shield.checkered"
        case .portfolio: return "chart.pie"
        case .correlation: return "arrow.triangle.branch"
        case .agent: return "cpu"
        case .signalConflict: return "arrow.triangle.swap"
        case .manipulation: return "eye.trianglebadge.exclamationmark"
        case .connection: return "wifi.exclamationmark"
        case .simulation: return "testtube.2"
        }
    }

    var color: Color {
        switch self {
        case .global: return PulseColors.accent
        case .portfolio: return PulseColors.cyan
        case .correlation: return PulseColors.info
        case .agent: return PulseColors.purple
        case .signalConflict: return PulseColors.amber
        case .manipulation: return PulseColors.danger
        case .connection: return PulseColors.warning
        case .simulation: return PulseColors.info
        }
    }

    /// Maps RiskEventType to categories for filtering
    var matchingEventTypes: [RiskEventType] {
        switch self {
        case .global: return RiskEventType.allCases
        case .portfolio: return [.stopLoss]
        case .correlation: return [.correlationWarning]
        case .agent: return [.apiError]
        case .signalConflict: return [.dataAnomaly]
        case .manipulation: return [.circuitBreaker]
        case .connection: return [.apiError]
        case .simulation: return [.dataAnomaly]
        }
    }

    var subMetrics: [(label: String, icon: String)] {
        switch self {
        case .global:
            return [("综合风险评分", "gauge.with.dots.needle.33percent"), ("活跃告警数", "bell.badge"), ("风险事件趋势", "chart.line.uptrend.xyaxis")]
        case .portfolio:
            return [("集中度风险", "chart.pie"), ("最大敞口", "arrow.up.right"), ("行业暴露", "building.2")]
        case .correlation:
            return [("高相关对数", "link"), ("最大相关系数", "arrow.up.right"), ("分散度评分", "circles.hexagongrid")]
        case .agent:
            return [("权限异常", "lock.trianglebadge.exclamationmark"), ("越权操作", "person.badge.shield.checkmark"), ("Agent 健康度", "heart")]
        case .signalConflict:
            return [("冲突信号数", "arrow.triangle.swap"), ("多空矛盾", "arrow.up.arrow.down"), ("置信度偏离", "waveform.badge.exclamationmark")]
        case .manipulation:
            return [("高危币种数", "exclamationmark.triangle"), ("操纵评分均值", "gauge.with.dots.needle.67percent"), ("建议限制数", "hand.raised")]
        case .connection:
            return [("API 延迟", "clock.badge.exclamationmark"), ("断连次数", "wifi.slash"), ("WebSocket 状态", "antenna.radiowaves.left.and.right")]
        case .simulation:
            return [("模拟偏差", "chart.line.flattrend.xyaxis"), ("异常交易数", "exclamationmark.octagon"), ("数据同步延迟", "clock.arrow.2.circlepath")]
        }
    }
}

extension RiskEventType: CaseIterable {
    static var allCases: [RiskEventType] {
        [.stopLoss, .circuitBreaker, .apiError, .dataAnomaly, .correlationWarning]
    }
}

// Extension on RiskView for category features
extension RiskView {

    // MARK: - Category Tab Bar

    @ViewBuilder
    var riskCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.xs) {
                ForEach(RiskCategory.allCases) { category in
                    Button {
                        withAnimation(PulseAnimation.easeOutMedium) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: category.icon)
                                .font(.system(size: 10))
                            Text(category.rawValue)
                                .font(PulseFonts.captionMedium)
                        }
                        .foregroundStyle(selectedCategory == category ? colors.background : colors.textSecondary)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, PulseSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .fill(selectedCategory == category ? category.color : colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .stroke(
                                    selectedCategory == category ? category.color.opacity(0.5) : colors.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Category Metrics

    @ViewBuilder
    var categoryMetrics: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(selectedCategory.color)
                    Text(selectedCategory.rawValue)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    let count = filteredEventCount
                    BadgeDot(
                        color: count > 0 ? PulseColors.warning : PulseColors.success,
                        label: "\(count) 事件",
                        size: .small
                    )
                }

                HStack(spacing: PulseSpacing.md) {
                    ForEach(Array(selectedCategory.subMetrics.enumerated()), id: \.offset) { _, metric in
                        VStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(selectedCategory.color.opacity(0.7))
                            Text("—")
                                .font(PulseFonts.tabular)
                                .foregroundStyle(colors.textPrimary)
                            Text(metric.label)
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    var filteredEventCount: Int {
        guard selectedCategory != .global else { return riskEvents.count }
        let types = selectedCategory.matchingEventTypes
        return riskEvents.filter { types.contains($0.eventType) }.count
    }
}

// MARK: - StatCard



struct StatCard: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(spacing: PulseSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text(value)
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                Text(label)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
