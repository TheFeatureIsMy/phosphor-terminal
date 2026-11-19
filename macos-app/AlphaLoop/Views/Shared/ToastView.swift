// ToastView.swift — Toast 通知覆盖层

import SwiftUI

struct ToastView: View {
    @Environment(PulseColors.self) private var colors
    let type: ToastType
    let message: String

    var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(type.color)

            Text(message)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
        }
        .cardStyle(padding: PulseSpacing.sm)
    }
}
