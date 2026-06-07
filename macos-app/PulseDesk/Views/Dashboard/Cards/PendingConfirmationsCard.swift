// PendingConfirmationsCard.swift — Bento 卡片: 需人工确认事项
import SwiftUI

struct PendingConfirmationsCard: View {
    @Environment(PulseColors.self) private var colors
    let confirmations: [PendingConfirmation]
    let onApprove: (String) -> Void
    let onReject: (String) -> Void

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: "需人工确认事项")
                    Spacer()
                    if !confirmations.isEmpty {
                        BadgeDot(color: KryptonColor.amber, label: "\(confirmations.count)", size: .small)
                    }
                }

                if confirmations.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("无待处理事项")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.vertical, PulseSpacing.sm)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: PulseSpacing.xs) {
                            ForEach(Array(confirmations.enumerated()), id: \.element.id) { index, item in
                                ConfirmationRow(item: item, onApprove: onApprove, onReject: onReject)
                                    .staggeredAppearance(index: index)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .hoverEffect()
    }
}

struct ConfirmationRow: View {
    @Environment(PulseColors.self) private var colors
    let item: PendingConfirmation
    let onApprove: (String) -> Void
    let onReject: (String) -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: typeIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(typeColor)
                    .frame(width: 16)
                    .shadow(color: typeColor.opacity(0.4), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(item.description)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: PulseSpacing.xs) {
                    Button {
                        onReject(item.id)
                    } label: {
                        Text("拒绝")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surface))
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain).pressEffect()

                    Button {
                        onApprove(item.id)
                    } label: {
                        Text("批准")
                            .font(PulseFonts.micro)
                            .foregroundStyle(KryptonColor.background)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(KryptonColor.amber))
                            .shadow(color: KryptonColor.amber.opacity(0.25), radius: 6)
                    }
                    .buttonStyle(.plain).pressEffect()
                }
            }
        }
        .padding(PulseSpacing.sm)
        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(isHovered ? KryptonColor.surfaceHover : colors.surface.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(isHovered ? colors.borderHover : colors.border, lineWidth: 0.5))
        .onHover { h in
            withAnimation(PulseAnimation.easeOutFast) { isHovered = h }
        }
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
        case "dry_run": return KryptonColor.amber
        case "risk_release": return PulseColors.purple
        default: return colors.textMuted
        }
    }
}
