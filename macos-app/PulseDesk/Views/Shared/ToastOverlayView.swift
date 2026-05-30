// ToastOverlayView.swift — 全局 Toast 通知覆盖层

import SwiftUI

struct ToastOverlayView: View {
    let toastManager: ToastManager

    var body: some View {
        VStack(spacing: PulseSpacing.xs) {
            ForEach(toastManager.toasts) { toast in
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: toast.type.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(toast.type.color)

                    Text(toast.message)
                        .font(PulseFonts.caption)
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.sm)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, PulseSpacing.lg)
        .padding(.horizontal, PulseSpacing.lg)
        .animation(.spring(duration: 0.3), value: toastManager.toasts.map(\.id))
        .allowsHitTesting(!toastManager.toasts.isEmpty)
    }
}
