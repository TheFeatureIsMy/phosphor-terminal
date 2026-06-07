// DangerZoneView.swift — 危险操作区域

import SwiftUI

struct DangerZoneView: View {
    @Environment(PulseColors.self) private var colors
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("危险操作")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(PulseColors.danger)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("导出数据")
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text("导出所有策略和交易记录")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    KryptonButton(title: "导出", action: {}, style: .ghost)
                }
                .padding(.vertical, PulseSpacing.xs)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("删除账户")
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(PulseColors.danger)
                        Text("此操作不可撤销，所有数据将被永久删除")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    KryptonButton(title: "删除", action: { showDeleteConfirm = true }, style: .ghost)
                }
                .padding(.vertical, PulseSpacing.xs)
            }
            .cardStyle()
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {}
        } message: {
            Text("确定要删除账户吗？此操作不可撤销。")
        }
    }
}
