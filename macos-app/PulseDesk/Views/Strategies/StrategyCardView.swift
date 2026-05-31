// StrategyCardView.swift — 单个策略卡片
// 类型徽章 + 状态指示 + 策略名 + 指标 + 操作按钮

import SwiftUI

struct StrategyCardView: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy
    let onTap: () -> Void
    let onDeploy: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            // 顶部：状态
            HStack {
                HStack(spacing: PulseSpacing.xxs) {
                    Circle()
                        .fill(strategy.status.color(colors))
                        .frame(width: 6, height: 6)
                    Text(strategy.status.label)
                        .font(PulseFonts.caption)
                        .foregroundStyle(strategy.status.color(colors))
                }

                Spacer()
            }

            // 策略名称
            Text(strategy.name)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            // 元信息
            HStack(spacing: PulseSpacing.xs) {
                Text(strategy.market)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                Text("·")
                    .foregroundStyle(colors.textMuted)
                Text(strategy.exchange)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                Text("·")
                    .foregroundStyle(colors.textMuted)
                Text("v\(strategy.version)")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            // 指标
            HStack(spacing: PulseSpacing.lg) {
                if let sharpe = strategy.sharpeRatio {
                    metricItem("夏普", value: String(format: "%.2f", sharpe))
                }
                if let dd = strategy.maxDrawdown {
                    metricItem("回撤", value: String(format: "%.1f%%", dd))
                }
            }

            // 标签
            if !strategy.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(strategy.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .foregroundStyle(PulseColors.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(PulseColors.accent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if strategy.tags.count > 3 {
                        Text("+\(strategy.tags.count - 3)")
                            .font(.system(size: 9)).foregroundStyle(colors.textMuted)
                    }
                }
            }

            // 操作行
            HStack(spacing: PulseSpacing.xs) {
                if strategy.status == .active {
                    actionButton("停止", icon: "stop.fill", color: PulseColors.warning, action: onStop)
                } else if strategy.status == .paused || strategy.status == .draft || strategy.status == .backtested {
                    actionButton("部署", icon: "play.fill", color: PulseColors.statusActive, action: onDeploy)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
                .help("删除策略")

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.textMuted)
            }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(isHovering ? PulseGlass.accentBorderHover : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
        }
        .onTapGesture(perform: onTap)
        .contextMenu {
            if strategy.status == .active {
                Button("停止", action: onStop)
            } else {
                Button("部署", action: onDeploy)
            }
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
    }

    private func metricItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(colors.textPrimary)
        }
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(PulseFonts.captionMedium)
            }
            .foregroundStyle(color)
            .padding(.horizontal, PulseSpacing.xs)
            .padding(.vertical, PulseSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.95)
    }
}
