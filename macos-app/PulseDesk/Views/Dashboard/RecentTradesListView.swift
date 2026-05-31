// RecentTradesListView.swift — 最近交易列表
// 紧凑型交易记录，显示交易对、方向、时间、盈亏

import SwiftUI

struct RecentTradesListView: View {
    @Environment(PulseColors.self) private var colors
    let orders: [Order]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text("最近交易")
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)

                if orders.isEmpty {
                    EmptyStateView(
                        icon: "arrow.left.arrow.right",
                        title: "暂无交易",
                        description: "策略执行后将在此显示"
                    )
                    .frame(minHeight: 120)
                } else {
                    VStack(spacing: 1) {
                        ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                            tradeRow(order)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }

    private func tradeRow(_ order: Order) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            // 方向
            Text(order.side.label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(order.side.color(colors))

            // 交易对
            Text(order.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            // 时间
            Text(timeAgo(order.timestamp))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)

            // 盈亏
            if let profit = order.profit {
                Text(String(format: "%+.0f", profit))
                    .font(PulseFonts.caption.weight(.medium))
                    .foregroundStyle(profit >= 0 ? colors.profit : PulseColors.loss)
            }
        }
        .padding(.vertical, PulseSpacing.xxs)
        .padding(.horizontal, PulseSpacing.xs)
        .modifier(HoverBackgroundModifier())
    }

    private func timeAgo(_ isoDate: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoDate) else { return isoDate }
        let interval = -date.timeIntervalSinceNow
        if interval < 3600 { return "\(Int(interval / 60))分前" }
        if interval < 86400 { return "\(Int(interval / 3600))时前" }
        return "\(Int(interval / 86400))天前"
    }
}

// MARK: - 行悬停背景修饰器
private struct HoverBackgroundModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? colors.surfaceHover.opacity(0.3) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
            }
    }
}
