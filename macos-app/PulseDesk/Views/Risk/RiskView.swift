// RiskView.swift — 风险管理控制台

import SwiftUI

struct RiskView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var riskEvents: [RiskEvent] = []
    @State private var correlation: [CorrelationSnapshot] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    pageHeader
                    riskOverviewCards
                    severityBreakdown
                    riskEventsList
                    topCorrelations
                }
                .padding(PulseSpacing.lg)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await loadData() }
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
