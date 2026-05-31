// BadgeView.swift — 状态徽章组件

import SwiftUI

enum BadgeSize {
    case small, medium

    var font: Font {
        switch self {
        case .small: return PulseFonts.monoLabel
        case .medium: return PulseFonts.captionMedium
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .medium: return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        }
    }
}

struct BadgeView: View {
    let text: String
    let color: Color
    var size: BadgeSize = .medium

    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundStyle(color)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(color.opacity(0.12), lineWidth: 0.5)
            )
    }
}
