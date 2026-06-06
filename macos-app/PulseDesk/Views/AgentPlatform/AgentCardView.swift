// AgentCardView.swift — Agent 卡片
// 显示 Agent 名称、类型、性能指标、状态、最近信号

import SwiftUI

struct AgentCardView: View {
    let agent: AgentProfile
    let signalCount: Int
    let avgScore: String
    let recentSignals: [AgentSignal]
    var permissionLevel: String = "observe_only"
    var winRate: Double = 0.0
    var weight: Int = 0
    var onDemote: (() -> Void)? = nil
    var onDisable: (() -> Void)? = nil
    @Environment(PulseColors.self) private var colors

    /// Max signals displayed on card
    private let maxDisplayedSignals = 2

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // 顶部：名称 + 状态
                HStack(spacing: PulseSpacing.sm) {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(agent.name)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)

                        BadgeDot(
                            color: kindColor,
                            label: kindLabel,
                            size: .small
                        )
                    }

                    Spacer()

                    StatusDot(status: agent.status == "active" ? .online : .offline)
                }

                // Permission + Win Rate + Weight row
                HStack(spacing: PulseSpacing.sm) {
                    // Permission level badge
                    BadgeDot(
                        color: permissionColor,
                        label: permissionLabel,
                        size: .small
                    )

                    // Win rate
                    HStack(spacing: 3) {
                        Text("胜率")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(String(format: "%.0f%%", winRate * 100))
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(winRateColor)
                    }

                    // Weight/ranking
                    if weight > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "number")
                                .font(.system(size: 8))
                                .foregroundStyle(colors.textMuted)
                            Text("\(weight)")
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(PulseColors.accent)
                        }
                    }

                    Spacer()

                    // Action menu
                    Menu {
                        Button(role: .none) {
                            onDemote?()
                        } label: {
                            Label("降级", systemImage: "arrow.down.circle")
                        }
                        Button(role: .destructive) {
                            onDisable?()
                        } label: {
                            Label("禁用", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textMuted)
                            .frame(width: 24, height: 24)
                            .background(colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }

                // 性能指标行
                HStack(spacing: PulseSpacing.lg) {
                    metricColumn(label: "信号数", value: "\(signalCount)", color: PulseColors.cyan)
                    metricColumn(label: "平均评分", value: avgScore, color: PulseColors.warning)
                    metricColumn(label: "状态", value: statusLabel, color: statusColor)
                }

                Divider().foregroundStyle(colors.border)

                // 最近信号
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    TerminalLabel(text: "最近信号")

                    if recentSignals.isEmpty {
                        Text("暂无信号")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    } else {
                        ForEach(recentSignals.prefix(maxDisplayedSignals), id: \.id) { signal in
                            recentSignalRow(signal)
                        }
                        if recentSignals.count > maxDisplayedSignals {
                            Text("... +\(recentSignals.count - maxDisplayedSignals)")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 240, maxHeight: 240)
        .clipped()
    }

    // MARK: - 指标列

    private func metricColumn(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
        }
    }

    // MARK: - 最近信号行

    private func recentSignalRow(_ signal: AgentSignal) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            // 方向指示
            Image(systemName: directionIcon(signal.direction))
                .font(.system(size: 9))
                .foregroundStyle(directionColor(signal.direction))

            Text(signal.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            if let score = signal.overallScore {
                Text(String(format: "%.1f", score))
                    .font(PulseFonts.micro)
                    .foregroundStyle(scoreColor(score))
            }

            Text(formatDate(signal.createdAt))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 辅助

    private var kindLabel: String {
        switch agent.kind {
        case "research": return L10n.Agent.kindResearch
        case "manual": return L10n.Agent.kindManual
        case "execution": return L10n.Agent.kindExecution
        default: return agent.kind
        }
    }

    private var kindColor: Color {
        switch agent.kind {
        case "research": return PulseColors.cyan
        case "manual": return PulseColors.amber
        case "execution": return PulseColors.purple
        default: return colors.textMuted
        }
    }

    private var statusLabel: String {
        agent.status == "active" ? "运行中" : "离线"
    }

    private var statusColor: Color {
        agent.status == "active" ? PulseColors.statusActive : colors.textMuted
    }

    private func directionIcon(_ direction: String?) -> String {
        switch direction?.lowercased() {
        case "long": return "arrow.up"
        case "short": return "arrow.down"
        default: return "arrow.right"
        }
    }

    private func directionColor(_ direction: String?) -> Color {
        switch direction?.lowercased() {
        case "long": return colors.profit
        case "short": return PulseColors.loss
        default: return PulseColors.warning
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 4.0 { return colors.profit }
        if score >= 3.0 { return PulseColors.warning }
        return PulseColors.loss
    }

    // MARK: - Permission helpers

    private var permissionLabel: String {
        switch permissionLevel {
        case "observe_only": return "仅观察"
        case "signal_only": return "仅信号"
        case "paper_trade": return "模拟交易"
        case "live_requires_confirm": return "实盘确认"
        default: return permissionLevel
        }
    }

    private var permissionColor: Color {
        switch permissionLevel {
        case "observe_only": return colors.textMuted
        case "signal_only": return PulseColors.info
        case "paper_trade": return PulseColors.warning
        case "live_requires_confirm": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private var winRateColor: Color {
        if winRate > 0.6 { return PulseColors.success }
        if winRate > 0.4 { return PulseColors.warning }
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
