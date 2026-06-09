// DangerZoneView.swift — 危险操作区域

import SwiftUI

struct DangerZoneView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text(L10n.zh("危险操作", en: "Danger Zone"))
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(PulseColors.danger)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("导出数据", en: "Export Data"))
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text(L10n.zh("导出所有策略和交易记录", en: "Export all strategies and trade history"))
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    KryptonButton(title: L10n.zh("导出", en: "Export"), action: {}, style: .ghost)
                }
                .padding(.vertical, PulseSpacing.xs)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("删除账户", en: "Delete Account"))
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(PulseColors.danger)
                        Text(L10n.zh("此操作不可撤销，所有数据将被永久删除", en: "This action is irreversible. All data will be permanently deleted."))
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    KryptonButton(title: L10n.zh("删除", en: "Delete"), action: { showDeleteConfirm = true }, style: .ghost)
                }
                .padding(.vertical, PulseSpacing.xs)
            }
            .cardStyle()
        }
        .id(settingsState.language)
        .alert(L10n.zh("确认删除", en: "Confirm Deletion"), isPresented: $showDeleteConfirm) {
            Button(L10n.zh("取消", en: "Cancel"), role: .cancel) {}
            Button(L10n.zh("删除", en: "Delete"), role: .destructive) {}
        } message: {
            Text(L10n.zh("确定要删除账户吗？此操作不可撤销。", en: "Are you sure you want to delete your account? This action cannot be undone."))
        }
    }
}
