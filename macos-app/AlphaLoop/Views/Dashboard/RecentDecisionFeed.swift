// RecentDecisionFeed.swift — Recent Decisions feed for Dashboard Bento Grid
// Scrollable list of recent trading decisions with color-coded verbs and reason chips.

import SwiftUI

struct RecentDecisionFeed: View {
    @Environment(PulseColors.self) private var colors

    let decisions: [RecentDecisionResponse]

    @State private var hoveredIndex: Int?

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Label
                TerminalLabel(text: L10n.Dashboard.recentDecisions)

                if decisions.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: L10n.Dashboard.recentDecisions,
                        description: ""
                    )
                } else {
                    ScrollView {
                        VStack(spacing: PulseSpacing.xxs) {
                            ForEach(Array(decisions.enumerated()), id: \.offset) { index, decision in
                                decisionRow(decision, index: index)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
        }
    }

    // MARK: - Decision Row

    private func decisionRow(_ decision: RecentDecisionResponse, index: Int) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Time
            Text(decision.time ?? "--:--")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(minWidth: 44, alignment: .leading)

            // Symbol + Decision verb
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xxs) {
                    Text(decision.symbol)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    Text(decision.decision.uppercased())
                        .font(PulseFonts.micro)
                        .foregroundStyle(decisionColor(decision.decision))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(decisionColor(decision.decision).opacity(0.10))
                        )
                }

                // Reason chips
                if !decision.reasonCodes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(decision.reasonCodes, id: \.self) { code in
                            Text(code)
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                                        .fill(colors.surface)
                                )
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(hoveredIndex == index ? colors.surfaceHover : Color.clear)
        )
        .onHover { isHovering in
            withAnimation(PulseAnimation.easeOutFast) {
                hoveredIndex = isHovering ? index : nil
            }
        }
    }

    // MARK: - Decision Color

    private func decisionColor(_ decision: String) -> Color {
        switch decision.lowercased() {
        case let d where d.contains("execute"): return PulseColors.accent
        case let d where d.contains("hold"): return PulseColors.cyan
        case let d where d.contains("reduce"): return PulseColors.StateColors.amber
        case let d where d.contains("reject"): return PulseColors.StateColors.red
        default: return colors.textSecondary
        }
    }
}
