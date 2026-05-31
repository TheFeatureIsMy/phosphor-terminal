// ActivityFeedView.swift — 风险事件活动流
// 左侧彩色边框 + 图标 + 消息 + 时间戳

import SwiftUI

struct ActivityFeedView: View {
    @Environment(PulseColors.self) private var colors
    let events: [RiskEvent]
    @State private var animateBars = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("风险事件")
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)

                if events.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.shield",
                        title: "一切正常",
                        description: "暂无风险事件"
                    )
                } else {
                    VStack(spacing: PulseSpacing.xs) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            eventRow(event, index: index)
                                .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateBars = true }
        }
    }

    private func eventRow(_ event: RiskEvent, index: Int) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            // 左侧严重程度色条
            RoundedRectangle(cornerRadius: 2)
                .fill(event.severity.color)
                .frame(width: 3)
                .scaleEffect(y: animateBars ? 1 : 0, anchor: .top)
                .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05), value: animateBars)

            // 图标
            Image(systemName: event.eventType.icon)
                .font(.system(size: 14))
                .foregroundStyle(event.severity.color)
                .frame(width: 24)

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(event.description ?? "未知事件")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)

                if let action = event.actionTaken {
                    Text("处理: \(action)")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }

            Spacer()

            // 时间
            Text(timeAgo(event.createdAt))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.sm)
        .background(colors.surfaceHover.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .modifier(HoverBorderModifier())
    }

    private func timeAgo(_ isoDate: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoDate) else { return isoDate }
        let interval = -date.timeIntervalSinceNow
        if interval < 3600 { return "\(Int(interval / 60))分前" }
        if interval < 86400 { return "\(Int(interval / 3600))时前" }
        return "\(Int(interval / 86400))天前"
    }
}

// MARK: - 行悬停边框修饰器
private struct HoverBorderModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(isHovering ? colors.textPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
            }
    }
}
