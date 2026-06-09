// ProfileSettingsView.swift — 个人资料设置

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AuthState.self) private var authState
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var hasChanges = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text(L10n.zh("个人资料", en: "Profile"))
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Circle()
                .fill(PulseColors.accent.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String((authState.user?.name ?? "T").prefix(1)).uppercased())
                        .font(PulseFonts.monoLarge)
                        .foregroundStyle(PulseColors.accent)
                )
                .padding(.bottom, PulseSpacing.xs)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                row(L10n.zh("用户名", en: "Username")) {
                    TextField("", text: $name)
                        .darkTextField()
                        .onChange(of: name) { _, _ in hasChanges = true }
                }
                row(L10n.zh("邮箱", en: "Email")) {
                    TextField("", text: $email)
                        .darkTextField()
                        .onChange(of: email) { _, _ in hasChanges = true }
                }
                row(L10n.zh("角色", en: "Role")) { BadgeView(text: authState.user?.role ?? "trader", color: PulseColors.accent) }
                row(L10n.zh("时区", en: "Timezone")) { Text("Asia/Shanghai").font(PulseFonts.body).foregroundStyle(colors.textPrimary) }
                row(L10n.zh("双因素认证", en: "2FA")) { BadgeView(text: L10n.zh("未启用", en: "Not Enabled"), color: colors.textMuted) }
            }
            .cardStyle()

            if hasChanges {
                KryptonButton(title: L10n.zh("保存", en: "Save")) {
                    // stub save action
                    hasChanges = false
                }
                .padding(.top, PulseSpacing.sm)
            }
        }
        .id(settingsState.language)
        .onAppear {
            name = authState.user?.name ?? ""
            email = authState.user?.email ?? ""
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(PulseFonts.body).foregroundStyle(colors.textSecondary).frame(width: 80, alignment: .leading)
            content()
            Spacer()
        }
    }
}
