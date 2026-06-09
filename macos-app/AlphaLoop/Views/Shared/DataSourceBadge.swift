// DataSourceBadge.swift — 数据来源状态徽章
// 绿色=真实数据, 黄色=模拟数据, 灰色=无数据

import SwiftUI

struct DataSourceBadge: View {
    @Environment(PulseColors.self) private var colors
    let status: DataSourceStatus?

    private var label: String {
        guard let status = status else { return L10n.zh("无数据", en: "No Data") }
        if !status.available { return L10n.zh("无数据", en: "No Data") }
        return status.simulated ? L10n.zh("模拟数据", en: "Simulated") : L10n.zh("真实数据", en: "Live Data")
    }

    private var icon: String {
        guard let status = status else { return "questionmark.circle" }
        if !status.available { return "questionmark.circle" }
        return status.simulated ? "desktopcomputer" : "antenna.radiowaves.left.and.right"
    }

    private var color: Color {
        guard let status = status else { return colors.textMuted }
        if !status.available { return colors.textMuted }
        return status.simulated ? PulseColors.warning : PulseColors.success
    }

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .stroke(color.opacity(0.20), lineWidth: 0.5)
        )
    }
}
