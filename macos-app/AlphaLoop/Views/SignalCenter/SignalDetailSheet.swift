// SignalDetailSheet.swift — 信号详情弹层
// 完整信号信息 + 生命周期 + 操作按钮

import SwiftUI

struct SignalDetailSheet: View {
    let signal: SignalV2
    let viewModel: SignalCenterViewModel
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            sheetHeader

            Divider().foregroundStyle(colors.border)

            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                    // 信号概览
                    signalOverview

                    Divider().foregroundStyle(colors.border)

                    // 完整推理
                    reasoningSection

                    // 证据列表
                    if let evidence = signal.evidence, !evidence.isEmpty {
                        Divider().foregroundStyle(colors.border)
                        evidenceSection(evidence)
                    }

                    // 生命周期
                    if let events = signal.lifecycleEvents, !events.isEmpty {
                        Divider().foregroundStyle(colors.border)
                        lifecycleSection(events)
                    }

                    // AI 溯源信息
                    if signal.providerTrace != nil {
                        Divider().foregroundStyle(colors.border)
                        providerTraceSection
                    }

                    Divider().foregroundStyle(colors.border)

                    // 操作按钮
                    actionButtons
                }
                .padding(PulseSpacing.lg)
            }
        }
        .frame(width: 520, height: 480)
        .id(settingsState.language)
        
    }

    // MARK: - 顶部栏

    private var sheetHeader: some View {
        HStack(spacing: PulseSpacing.md) {
            // 方向图标
            ZStack {
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(directionColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: directionIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(directionColor)
            }

            Text(signal.symbol)
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text(signal.direction.uppercased())
                .font(PulseFonts.monoLabel)
                .foregroundStyle(directionColor)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - 信号概览

    private var signalOverview: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(spacing: PulseSpacing.md) {
                HStack(spacing: PulseSpacing.xl) {
                    metricItem(label: L10n.zh("置信度", en: "Confidence"), value: "\(Int(signal.confidence * 100))%", color: confidenceColor)
                    if let score = signal.score {
                        metricItem(label: L10n.zh("评分", en: "Score"), value: String(format: "%.1f", score), color: scoreColor(score))
                    }
                    metricItem(label: L10n.zh("风险", en: "Risk"), value: riskLabel, color: riskColor)
                    metricItem(label: L10n.zh("状态", en: "Status"), value: statusLabel, color: statusColor)
                }

                HStack(spacing: PulseSpacing.lg) {
                    detailRow(label: L10n.zh("来源", en: "Source"), value: sourceLabel)
                    detailRow(label: L10n.zh("创建时间", en: "Created"), value: formatDate(signal.createdAt))
                    detailRow(label: L10n.zh("到期时间", en: "Expires"), value: formatDate(signal.expiresAt))
                }
            }
        }
    }

    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            TerminalLabel(text: label)
            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(color)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    // MARK: - 推理

    private var reasoningSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("推理分析", en: "Reasoning"))

            Text(signal.reasoning ?? L10n.zh("暂无推理信息", en: "No reasoning available"))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - 证据

    private func evidenceSection(_ evidence: [AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("证据", en: "Evidence"))

            ForEach(Array(evidence.enumerated()), id: \.offset) { index, item in
                HStack(spacing: PulseSpacing.xs) {
                    Circle()
                        .fill(PulseColors.cyan)
                        .frame(width: 4, height: 4)

                    Text("\(item.value)")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }

    // MARK: - 生命周期

    private func lifecycleSection(_ events: [AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("生命周期", en: "Lifecycle"))

            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                HStack(spacing: PulseSpacing.xs) {
                    // 时间线点
                    VStack(spacing: 0) {
                        Circle()
                            .fill(PulseColors.accent)
                            .frame(width: 6, height: 6)
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(colors.border)
                                .frame(width: 1, height: 16)
                        }
                    }

                    Text("\(event.value)")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }


    // MARK: - AI Provider Trace

    @ViewBuilder
    private var providerTraceSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("AI 溯源", en: "AI Provenance"))

            if let trace = signal.providerTrace,
               let dict = trace.value as? [String: Any] {
                let fields: [(String, String)] = [
                    ("Provider", dict["provider_id"] as? String ?? "—"),
                    ("Model", dict["model_name"] as? String ?? "—"),
                    ("Version", dict["model_version"] as? String ?? "—"),
                    ("Latency", dict["latency_ms"].map { "\($0)ms" } ?? "—"),
                    ("Cost", dict["cost_usd"].map { String(format: "$%.4f", $0 as? Double ?? 0) } ?? "—"),
                    ("Privacy", dict["privacy_level"] as? String ?? "—"),
                ]

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: PulseSpacing.xs) {
                    ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.0)
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .textCase(.uppercase)
                            Text(field.1)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                        }
                    }
                }
            } else {
                Text(L10n.zh("无溯源数据", en: "No provenance data"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }
    // MARK: - 操作按钮

    private var actionButtons: some View {
        HStack(spacing: PulseSpacing.sm) {
            if signal.status == "pending" {
                KryptonButton(title: L10n.zh("激活", en: "Activate"), action: {
                    Task { await viewModel.transition(signal.id, to: "active") }
                    onDismiss()
                })
            }

            KryptonButton(title: L10n.zh("发布为策略", en: "Publish as Strategy"), action: {
                Task { await viewModel.publishToStrategy(signal.id) }
                onDismiss()
            }, style: .ghost)

            Spacer()

            if signal.status != "archived" {
                KryptonButton(title: L10n.zh("归档", en: "Archive"), action: {
                    Task { await viewModel.archive(signal.id) }
                    onDismiss()
                }, style: .ghost)
            }
        }
    }

    // MARK: - 辅助属性

    private var directionIconName: String {
        switch signal.direction.lowercased() {
        case "long": return "arrow.up"
        case "short": return "arrow.down"
        default: return "arrow.right"
        }
    }

    private var directionColor: Color {
        switch signal.direction.lowercased() {
        case "long": return colors.profit
        case "short": return PulseColors.loss
        default: return PulseColors.warning
        }
    }

    private var confidenceColor: Color {
        if signal.confidence >= 0.8 { return colors.profit }
        if signal.confidence >= 0.6 { return PulseColors.warning }
        return PulseColors.loss
    }

    private var sourceLabel: String {
        switch signal.sourceType {
        case "ai_research": return L10n.zh("AI研究", en: "AI Research")
        case "tradingagents": return "TradingAgents"
        case "manual": return L10n.zh("手动", en: "Manual")
        case "canvas": return "Canvas"
        default: return signal.sourceType
        }
    }

    private var statusLabel: String {
        switch signal.status {
        case "pending": return L10n.zh("待处理", en: "Pending")
        case "active": return L10n.zh("已激活", en: "Active")
        case "expired": return L10n.zh("已过期", en: "Expired")
        case "archived": return L10n.zh("已归档", en: "Archived")
        case "rejected": return L10n.zh("已拒绝", en: "Rejected")
        default: return signal.status
        }
    }

    private var statusColor: Color {
        switch signal.status {
        case "pending": return PulseColors.warning
        case "active": return PulseColors.statusActive
        case "expired", "archived": return colors.textMuted
        case "rejected": return PulseColors.loss
        default: return colors.textMuted
        }
    }

    private var riskLabel: String {
        switch signal.riskLevel {
        case "low": return L10n.zh("低", en: "Low")
        case "medium": return L10n.zh("中", en: "Medium")
        case "high": return L10n.zh("高", en: "High")
        case "critical": return L10n.zh("极高", en: "Critical")
        default: return signal.riskLevel
        }
    }

    private var riskColor: Color {
        switch signal.riskLevel {
        case "low": return PulseColors.statusActive
        case "medium": return PulseColors.warning
        case "high": return PulseColors.loss
        case "critical": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 4.0 { return colors.profit }
        if score >= 3.0 { return PulseColors.warning }
        return PulseColors.loss
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        let display = DateFormatter()
        display.dateFormat = "MM-dd HH:mm"
        return display.string(from: date)
    }
}
