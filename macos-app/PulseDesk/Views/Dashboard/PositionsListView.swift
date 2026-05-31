// PositionsListView.swift — 持仓列表
// 紧凑型列表显示交易对、方向、数量、未实现盈亏

import SwiftUI

struct PositionsListView: View {
    @Environment(PulseColors.self) private var colors
    let positions: [Position]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text("持仓 (\(positions.count))")
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)

                if positions.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "暂无持仓",
                        description: "运行策略后将在此显示"
                    )
                    .frame(minHeight: 120)
                } else {
                    VStack(spacing: 3) {
                        ForEach(Array(positions.enumerated()), id: \.element.id) { index, pos in
                            positionRow(pos)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }

    private func positionRow(_ pos: Position) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            // 方向标识
            Text(pos.side.label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pos.side.color(colors))
                )

            // 交易对
            Text(pos.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            // 数量
            Text(String(format: "%.4f", pos.quantity))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)

            // 未实现盈亏
            Text(String(format: "%+.0f", pos.unrealizedPnl))
                .font(PulseFonts.caption.weight(.medium))
                .foregroundStyle(pos.unrealizedPnl >= 0 ? colors.profit : PulseColors.loss)
        }
        .padding(.vertical, PulseSpacing.xxs)
        .padding(.horizontal, PulseSpacing.xs)
    }
}
