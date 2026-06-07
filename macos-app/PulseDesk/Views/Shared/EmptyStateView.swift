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

    @State private var appeared = false

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            KryptonLogoView()
                .frame(width: 42, height: 42)
                .opacity(0.9)

            Text(title)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Text(description)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: PulseSpacing.sm) {
                if let primaryAction {
                    ProofAlphaButton(title: primaryAction.title, action: primaryAction.action)
                }
                if let secondaryAction {
                    ProofAlphaButton(title: secondaryAction.title, action: secondaryAction.action, style: .ghost)
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
