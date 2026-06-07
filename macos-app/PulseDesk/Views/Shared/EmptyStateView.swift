// EmptyStateView.swift — 空状态视图
// 图标 + 标题 + 描述 + 可选操作按钮，带浮动和入场动画

import SwiftUI

struct EmptyStateView: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let title: String
    let description: String
    var primaryAction: (title: String, action: () -> Void)?
    var secondaryAction: (title: String, action: () -> Void)?

    @State private var floatOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(PulseColors.accent.opacity(0.6))
                .offset(y: floatOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(
                            .spring(response: 2.0, dampingFraction: 0.3)
                            .repeatForever(autoreverses: true)
                        ) {
                            floatOffset = -6
                        }
                    }
                }

            Text(title)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Text(description)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: PulseSpacing.sm) {
                if let primaryAction {
                    KryptonButton(title: primaryAction.title, action: primaryAction.action)
                }
                if let secondaryAction {
                    KryptonButton(title: secondaryAction.title, action: secondaryAction.action, style: .ghost)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(PulseSpacing.xl)
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(
                PulseAnimation.springDefault.delay(0.05)
            ) {
                appeared = true
            }
        }
    }
}
