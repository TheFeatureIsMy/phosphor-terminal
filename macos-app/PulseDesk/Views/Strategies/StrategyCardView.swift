// StrategyCardView.swift — v2.5 策略卡片
// 使用 ProofAlphaCard 保持与全局卡片风格一致

import SwiftUI

struct StrategyCardView: View {
    @Environment(PulseColors.self) private var colors
    let strategy: StrategyV2
    let onTap: () -> Void
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    HStack(spacing: PulseSpacing.xxs) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(strategy.statusLabel)
                            .font(PulseFonts.caption)
                            .foregroundStyle(statusColor)
                    }
                    Spacer()
                    Text(strategy.strategyType)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
                }

                Text(strategy.name)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: PulseSpacing.xs) {
                    Text(strategy.sourceType)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                    if let desc = strategy.description, !desc.isEmpty {
                        Text("·").foregroundStyle(colors.textMuted)
                        Text(desc)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                            .lineLimit(1)
                    }
                }

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button {
                onRename?()
            } label: {
                Label(L10n.Common.rename, systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label(L10n.Common.delete, systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        switch strategy.status {
        case "draft": return PulseColors.info
        case "active": return PulseColors.statusActive
        case "paused": return PulseColors.statusPaused
        case "archived": return PulseColors.statusError
        default: return PulseColors.info
        }
    }
}
