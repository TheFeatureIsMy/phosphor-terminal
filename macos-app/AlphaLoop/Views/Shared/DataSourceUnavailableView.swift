// DataSourceUnavailableView.swift — 后端数据源暂不可用空态
// 当 BFF endpoint 返回 state=data_source_unavailable 时显示。
// 参考 BackendUnavailableView.swift 风格：图标 + 标题 + 描述 + 重试按钮。
// debug 模式下显示 reasonCodes 列表。

import SwiftUI

struct DataSourceUnavailableView: View {
    @Environment(PulseColors.self) private var colors
    let reasonCodes: [String]
    let onRetry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: PulseSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PulseColors.warning.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(PulseColors.warning)
            }

            Text(L10n.System.dataSourceUnavailable)
                .font(PulseFonts.displayTitle)
                .foregroundStyle(colors.textPrimary)

            Text(L10n.System.dataSourceUnavailableDescription)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            // Debug: reason codes 详情
            if !reasonCodes.isEmpty {
                #if DEBUG
                VStack(spacing: PulseSpacing.xs) {
                    Text(L10n.System.dataSourceUnavailableDetails)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)

                    ForEach(reasonCodes, id: \.self) { code in
                        Text(code)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                }
                #endif
            }

            Spacer().frame(height: PulseSpacing.md)

            KryptonButton(
                title: isRetrying
                    ? L10n.Common.loading
                    : L10n.Common.retry
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
