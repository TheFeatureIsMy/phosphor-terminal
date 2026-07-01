// LifecycleIndicator.swift — 操纵案例生命周期进度指示器 + 色板 helper
// 5-stage horizontal dot-and-line progress: suspected → accumulate → markup → distribute → collapse
// LifecycleStagePalette is shared with LifecycleTimeline component.

import SwiftUI

// MARK: - Lifecycle Stage Palette (色板与图标映射 helper)

enum LifecycleStagePalette {
    static let stages = ["suspected", "accumulate", "markup", "distribute", "collapse"]
    static func color(_ stage: String, colors: PulseColors) -> Color {
        switch stage {
        case "suspected": return colors.textMuted
        case "accumulate": return PulseColors.info
        case "markup": return PulseColors.accent
        case "distribute": return PulseColors.amber
        case "collapse": return PulseColors.danger
        default: return colors.textMuted
        }
    }
    static func icon(_ stage: String) -> String {
        switch stage {
        case "suspected": return "questionmark.circle"
        case "accumulate": return "arrow.down.right.circle"
        case "markup": return "arrow.up.right.circle"
        case "distribute": return "arrow.down.circle"
        case "collapse": return "exclamationmark.triangle"
        default: return "circle"
        }
    }
}

// MARK: - LifecycleIndicator (legacy, still used by CaseCardView)

struct LifecycleIndicator: View {
    @Environment(PulseColors.self) private var colors

    let currentStage: String

    // Ordered lifecycle stages
    private static let stages = ["suspected", "accumulate", "markup", "distribute", "collapse"]

    private var currentIndex: Int {
        Self.stages.firstIndex(of: currentStage.lowercased()) ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.stages.enumerated()), id: \.offset) { index, stage in
                stageNode(stage: stage, index: index)

                if index < Self.stages.count - 1 {
                    connectorLine(afterIndex: index)
                }
            }
        }
    }

    // MARK: - Stage Node (dot + label)

    private func stageNode(stage: String, index: Int) -> some View {
        let isCurrent = index == currentIndex
        let isReached = index <= currentIndex
        let color = isReached ? stageColor(stage) : colors.textMuted.opacity(0.3)
        let dotSize: CGFloat = isCurrent ? 14 : 10

        return VStack(spacing: PulseSpacing.xxs) {
            ZStack {
                // Pulsing glow ring for current stage
                if isCurrent {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .modifier(PulseGlowModifier(color: color))
                }

                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
            }
            .frame(width: 20, height: 20)

            Text(stageAbbreviation(stage))
                .font(PulseFonts.micro)
                .foregroundStyle(isReached ? color : colors.textMuted.opacity(0.4))
                .lineLimit(1)
                .fixedSize()
        }
    }

    // MARK: - Connector Line

    private func connectorLine(afterIndex index: Int) -> some View {
        let isReached = index < currentIndex
        let color = isReached
            ? stageColor(Self.stages[index])
            : colors.textMuted.opacity(0.15)

        return Rectangle()
            .fill(color)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10 + PulseSpacing.xxs) // align with dot center vertically
    }

    // MARK: - Stage Colors

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "suspected":  return PulseColors.amber
        case "accumulate": return PulseColors.cyan
        case "markup":     return PulseColors.accent
        case "distribute": return PulseColors.warning
        case "collapse":   return PulseColors.danger
        default:           return colors.textMuted
        }
    }

    // MARK: - Stage Abbreviation Labels

    private func stageAbbreviation(_ stage: String) -> String {
        switch stage {
        case "suspected":  return L10n.zh("疑似", en: "SUS")
        case "accumulate": return L10n.zh("建仓", en: "ACC")
        case "markup":     return L10n.zh("拉升", en: "MKP")
        case "distribute": return L10n.zh("派发", en: "DST")
        case "collapse":   return L10n.zh("崩盘", en: "COL")
        default:           return String(stage.prefix(3)).uppercased()
        }
    }
}

// MARK: - Pulse Glow Animation Modifier

private struct PulseGlowModifier: ViewModifier {
    let color: Color
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.0 : 0.6)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
