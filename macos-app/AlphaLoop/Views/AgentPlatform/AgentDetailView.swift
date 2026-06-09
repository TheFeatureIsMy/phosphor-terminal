// AgentDetailView.swift — Agent 详情弹窗
// 展示 Agent 完整信息、指标和信号历史

import SwiftUI

struct AgentDetailView: View {
    let agent: AgentProfile
    let signals: [AgentSignal]
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            header
            Divider().overlay(colors.border)

            // Scrollable content
            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    // Agent info section
                    infoSection

                    // Metrics grid
                    metricsSection

                    // Signal history
                    signalHistorySection
                }
                .padding(PulseSpacing.lg)
            }
            .id(settingsState.language)
        }
        .frame(width: 520, height: 600)
        .background(colors.cardBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(agent.name)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)

                HStack(spacing: PulseSpacing.sm) {
                    BadgeDot(
                        color: kindColor,
                        label: kindLabel,
                        size: .medium
                    )

                    StatusDot(status: agent.status == "active" ? .online : .offline)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colors.textMuted)
                    .frame(width: 28, height: 28)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            if let desc = agent.description, !desc.isEmpty {
                Text(desc)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textSecondary)
            }

            HStack(spacing: PulseSpacing.md) {
                BadgeDot(
                    color: permissionColor,
                    label: permissionLabel,
                    size: .small
                )

                if let heartbeat = agent.lastHeartbeatAt {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PulseColors.loss)
                        Text(L10n.Agent.lastHeartbeat + ": " + formatDate(heartbeat))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Agent.performance)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: PulseSpacing.sm),
                GridItem(.flexible(), spacing: PulseSpacing.sm)
            ], spacing: PulseSpacing.sm) {
                metricCard(
                    title: L10n.Agent.totalSignals,
                    value: "\(signals.count)",
                    color: PulseColors.cyan
                )
                metricCard(
                    title: L10n.Agent.avgScore,
                    value: computedAvgScore,
                    color: PulseColors.warning
                )
                metricCard(
                    title: L10n.Agent.winRate,
                    value: "0%",
                    color: PulseColors.success
                )
                metricCard(
                    title: L10n.Agent.weight,
                    value: "—",
                    color: PulseColors.accent
                )
            }
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(value)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.md)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // MARK: - Signal History Section

    private var signalHistorySection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Agent.signalHistory)

            if signals.isEmpty {
                Text(L10n.zh("暂无信号记录", en: "No signal records"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .padding(.vertical, PulseSpacing.md)
            } else {
                VStack(spacing: PulseSpacing.xs) {
                    ForEach(sortedSignals, id: \.id) { signal in
                        signalRow(signal)
                    }
                }
            }
        }
    }

    private func signalRow(_ signal: AgentSignal) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            // Left color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(directionColor(signal.direction))
                .frame(width: 3, height: 32)

            // Direction arrow
            Image(systemName: directionIcon(signal.direction))
                .font(.system(size: 10))
                .foregroundStyle(directionColor(signal.direction))
                .frame(width: 16)

            // Symbol
            Text(signal.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Score
            if let score = signal.overallScore {
                Text(String(format: "%.1f", score))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(scoreColor(score))
            }

            // Date
            Text(formatDate(signal.createdAt))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, PulseSpacing.xs)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Computed

    private var sortedSignals: [AgentSignal] {
        signals.sorted { $0.createdAt > $1.createdAt }
    }

    private var computedAvgScore: String {
        let scores = signals.compactMap { $0.overallScore }
        guard !scores.isEmpty else { return "N/A" }
        return String(format: "%.1f", scores.reduce(0, +) / Double(scores.count))
    }

    // MARK: - Helpers

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

    private var permissionLabel: String {
        L10n.Agent.permObserveOnly
    }

    private var permissionColor: Color {
        colors.textMuted
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
        case "long": return PulseColors.success
        case "short": return PulseColors.loss
        default: return PulseColors.warning
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 4.0 { return PulseColors.success }
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
