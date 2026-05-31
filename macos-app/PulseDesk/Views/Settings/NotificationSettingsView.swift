// NotificationSettingsView.swift — 通知设置

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(SettingsState.self) private var settings
    @Environment(PulseColors.self) private var colors

    var body: some View {
        @Bindable var s = settings

        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("通知设置")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                row("Bot Token") { SecureField("Telegram Bot Token", text: $s.telegramBotToken).darkTextField() }
                row("Chat ID") { TextField("Telegram Chat ID", text: $s.telegramChatId).darkTextField() }
                Divider()
                toggleRow("风险事件通知", isOn: $s.notifyRiskEvents)
                toggleRow("交易执行通知", isOn: $s.notifyTradeExecuted)
                toggleRow("每日摘要", isOn: $s.notifyDailySummary)
                toggleRow("系统告警", isOn: $s.notifySystemAlerts)
            }
            .cardStyle()
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(PulseFonts.body).foregroundStyle(colors.textSecondary).frame(width: 100, alignment: .leading)
            content().frame(maxWidth: 320, alignment: .leading)
            Spacer()
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(PulseFonts.body).foregroundStyle(colors.textSecondary).frame(width: 140, alignment: .leading)
            Toggle("", isOn: isOn).tint(PulseColors.accent)
            Spacer()
        }
    }
}
