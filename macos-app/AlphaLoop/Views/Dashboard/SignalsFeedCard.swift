// SignalsFeedCard.swift — Recent signals with explicit source-trace tags.
// Driven by /api/agent-signals/signals. Each row shows:
//   symbol · direction · confidence · content
//   source: agent / strategy / feature-snapshot (clickable to AI Studio)

import SwiftUI

struct SignalsFeedCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let signals: [DashboardSignalRef]
    let dataSourceAvailable: Bool

    @State private var hoveredIndex: Int?

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                header

                if !dataSourceAvailable {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        title: L10n.Dashboard.dataSourceUnavailable,
                        description: ""
                    )
                    .frame(minHeight: 120)
                } else if signals.isEmpty {
                    EmptyStateView(
                        icon: "waveform.path.ecg",
                        title: L10n.Dashboard.noSignals,
                        description: ""
                    )
                    .frame(minHeight: 120)
                } else {
                    ScrollView {
                        VStack(spacing: PulseSpacing.xxs) {
                            ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                                signalRow(signal, index: index)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
        }
        .id(settingsState.language)
    }

    private var header: some View {
        HStack(spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Dashboard.signalsFeed)
            Spacer()
            if dataSourceAvailable {
                Text("\(signals.count)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    // MARK: - Row

    private func signalRow(_ signal: DashboardSignalRef, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: PulseSpacing.xs) {
                directionTag(signal.direction)
                Text(signal.symbol)
                    .font(PulseFonts.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundStyle(colors.textPrimary)
                if let rating = signal.rating, !rating.isEmpty {
                    Text(rating.uppercased())
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(colors.surface)
                        )
                }
                Spacer()
                if let conf = signal.confidence {
                    Text(String(format: "%.0f%%", conf * 100))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(confidenceColor(conf))
                }
            }
            if !signal.content.isEmpty {
                Text(signal.content)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(2)
            }
            sourceRow(signal)
        }
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(hoveredIndex == index ? colors.surface.opacity(0.5) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) {
                hoveredIndex = hovering ? index : nil
            }
        }
    }

    private func sourceRow(_ signal: DashboardSignalRef) -> some View {
        HStack(spacing: 6) {
            sourceChip(
                icon: "person.crop.square",
                label: L10n.Dashboard.signalSourceAgent,
                value: signal.sourceAgent
            )
            sourceChip(
                icon: "wand.and.stars",
                label: L10n.Dashboard.signalSourceStrategy,
                value: signal.sourceStrategyId
            )
            sourceChip(
                icon: "doc.text.magnifyingglass",
                label: L10n.Dashboard.signalSourceSnapshot,
                value: signal.sourceFeatureSnapshotId
            )
            Spacer()
            if let created = signal.createdAt.split(separator: "T").last {
                Text(String(created.prefix(5)))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    @ViewBuilder
    private func sourceChip(icon: String, label: String, value: String?) -> some View {
        let hasValue = !(value ?? "").isEmpty
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .medium))
            Text(label.uppercased())
                .font(PulseFonts.micro)
                .textCase(.uppercase)
            if hasValue, let v = value {
                Text(v)
                    .font(PulseFonts.micro)
                    .fontWeight(.bold)
            } else {
                Text(L10n.Dashboard.sourceNotTraced)
                    .font(PulseFonts.micro)
            }
        }
        .foregroundStyle(hasValue ? PulseColors.cyan : colors.textMuted)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill((hasValue ? PulseColors.cyan : colors.textMuted).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .stroke((hasValue ? PulseColors.cyan : colors.textMuted).opacity(0.20), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func directionTag(_ dir: String?) -> some View {
        let lower = (dir ?? "neutral").lowercased()
        let color: Color
        let text: String
        switch lower {
        case "long", "buy": (color, text) = (PulseColors.accent, L10n.Dashboard.long)
        case "short", "sell": (color, text) = (PulseColors.danger, L10n.Dashboard.short)
        default: (color, text) = (colors.textMuted, "—")
        }
        return Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(color.opacity(0.10))
            )
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value >= 0.7 { return PulseColors.accent }
        if value >= 0.4 { return PulseColors.cyan }
        return PulseColors.warning
    }
}
