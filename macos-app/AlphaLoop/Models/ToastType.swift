// ToastType.swift — shared toast kind (used by Services + Views)

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
