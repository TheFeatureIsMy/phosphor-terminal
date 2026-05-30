// ToastView.swift — Toast 通知覆盖层

import SwiftUI

enum ToastType {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return PulseColors.success
        case .error: return PulseColors.danger
        case .warning: return PulseColors.warning
        case .info: return PulseColors.info
        }
    }
}

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
