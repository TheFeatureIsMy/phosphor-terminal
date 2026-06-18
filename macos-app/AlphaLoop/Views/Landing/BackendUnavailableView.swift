// BackendUnavailableView.swift — 后端不可达错误页
// 当后端服务无法连接时显示，提供重试按钮和日志链接

import SwiftUI

struct BackendUnavailableView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @Environment(AppState.self) private var appState
    let onRetry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: PulseSpacing.lg) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(PulseColors.danger.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(PulseColors.danger)
                }

                Text(L10n.System.backendUnavailable)
                    .font(PulseFonts.displayTitle)
                    .foregroundStyle(colors.textPrimary)

                Text(L10n.System.backendUnavailableDescription)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                Spacer().frame(height: PulseSpacing.md)

                KryptonButton(
                    title: isRetrying
                        ? L10n.Common.loading
                        : L10n.System.retryConnection
                ) {
                    isRetrying = true
                    Task {
                        await onRetry()
                        isRetrying = false
                    }
                }
                .frame(maxWidth: 240)
                .disabled(isRetrying)

                Spacer()
            }
            .padding(.horizontal, PulseSpacing.xl)
        }
    }
}
