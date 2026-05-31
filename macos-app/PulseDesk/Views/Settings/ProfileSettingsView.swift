// ProfileSettingsView.swift — 个人资料设置

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AuthState.self) private var authState
    @Environment(PulseColors.self) private var colors

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var hasChanges = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("个人资料")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Circle()
                .fill(PulseColors.accent.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String((authState.user?.name ?? "T").prefix(1)).uppercased())
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseColors.accent)
                )
                .padding(.bottom, PulseSpacing.xs)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                row("用户名") {
                    TextField("", text: $name)
                        .darkTextField()
                        .onChange(of: name) { _, _ in hasChanges = true }
                }
                row("邮箱") {
                    TextField("", text: $email)
                        .darkTextField()
                        .onChange(of: email) { _, _ in hasChanges = true }
                }
                row("角色") { BadgeView(text: authState.user?.role ?? "trader", color: PulseColors.accent) }
                row("时区") { Text("Asia/Shanghai").font(PulseFonts.body).foregroundStyle(colors.textPrimary) }
                row("双因素认证") { BadgeView(text: "未启用", color: colors.textMuted) }
            }
            .cardStyle()

            if hasChanges {
                ProofAlphaButton(title: "保存") {
                    // stub save action
                    hasChanges = false
                }
                .padding(.top, PulseSpacing.sm)
            }
        }
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
