// ToastOverlayView.swift — 全局 Toast 通知覆盖层

import SwiftUI

struct ToastOverlayView: View {
    let toastManager: ToastManager

    var body: some View {
        VStack(spacing: PulseSpacing.xs) {
            ForEach(Array(toastManager.toasts.enumerated()), id: \.element.id) { index, toast in
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: toast.type.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(toast.type.color)

                    Text(toast.message)
                        .font(PulseFonts.caption)
                        .foregroundStyle(Color(hex: "0F1524"))

                    Spacer()
                }
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(Color(hex: "FFFFFF"))
                )
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(Color(hex: "E6E9F2"), lineWidth: 1))
                .shadow(color: Color(hex: "3D5AFE").opacity(0.12), radius: 12, y: 4)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                .transition(.move(edge: .top).combined(with: .opacity))
                .staggeredAppearance(index: index, baseDelay: 0.02)
            }
            Spacer()
        }
        .padding(.top, PulseSpacing.lg)
        .padding(.horizontal, PulseSpacing.lg)
        .animation(.spring(duration: 0.3), value: toastManager.toasts.map(\.id))
        .allowsHitTesting(!toastManager.toasts.isEmpty)
    }
}
