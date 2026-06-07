// ProofAlphaComponents.swift — ProofAlpha 核心交互组件
// TerminalLabel, BadgeDot, StatusDot, GlowText, GradientText

import SwiftUI


// MARK: - TerminalLabel — "// LABEL" 终端风格标签
struct TerminalLabel: View {
    @Environment(PulseColors.self) private var colors
    let text: String

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text("//")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(PulseColors.accent)

            Text(text)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)
        }
    }
}

// MARK: - BadgeDot — 圆点 + 标签徽章
struct BadgeDot: View {
    let color: Color
    let label: String
    var size: BadgeDotSize = .small

    enum BadgeDotSize {
        case small, medium

        var font: Font {
            switch self {
            case .small: return PulseFonts.micro
            case .medium: return PulseFonts.captionMedium
            }
        }

        var padding: (h: CGFloat, v: CGFloat) {
            switch self {
            case .small: return (6, 2)
            case .medium: return (8, 3)
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .small: return 5
            case .medium: return 6
            }
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: size.dotSize, height: size.dotSize)

            Text(label)
                .font(size.font)
                .foregroundStyle(color)
                .textCase(.uppercase)
        }
        .padding(.horizontal, size.padding.h)
        .padding(.vertical, size.padding.v)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - StatusDot — LED 脉冲状态指示器
struct StatusDot: View {
    let status: StatusType

    enum StatusType {
        case online, offline, loading

        var color: Color {
            switch self {
            case .online: return PulseColors.statusActive
            case .offline: return PulseColors.statusError
            case .loading: return PulseColors.cyan
            }
        }
    }

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // 外圈脉冲
            Circle()
                .fill(status.color.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.8 : 1.0)
                .opacity(isPulsing ? 0 : 0.75)
                .animation(
                    .easeOut(duration: 1.2)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // 内圈实心
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .shadow(color: status.color.opacity(0.5), radius: 4)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - GlowText — 霓虹绿发光文字
struct GlowText: View {
    let text: String
    var font: Font = PulseFonts.displayHeading

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(PulseColors.accent)
            .shadow(color: PulseColors.accent.opacity(0.5), radius: 10)
            .shadow(color: PulseColors.accent.opacity(0.25), radius: 20)
    }
}

// MARK: - GradientText — 渐变文字 (绿→青)
struct GradientText: View {
    let text: String
    var font: Font = PulseFonts.displayHeading

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: [PulseColors.accent, PulseColors.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

