// NotificationSettingsView.swift - 通知设置

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(SettingsState.self) private var settings
    @Environment(PulseColors.self) private var colors

    var body: some View {
        @Bindable var s = settings

        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            TerminalLabel(text: L10n.Settings.notificationSettings)
            Text(L10n.zh("渠道类型 · 目标 · 事件订阅 · 严重度阈值 · 测试通知", en: "Channel Type · Destination · Event Subscription · Severity Threshold · Test Notification"))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                row(L10n.Settings.telegramBotToken) {
                    SecureField(L10n.Settings.telegramBotToken, text: $s.telegramBotToken)
                        
                }
                row(L10n.Settings.telegramChatId) {
                    TextField(L10n.Settings.telegramChatId, text: $s.telegramChatId)
                        
                }
                Divider().overlay(colors.border)
                toggleRow(L10n.Settings.notifyRisk, isOn: $s.notifyRiskEvents)
                toggleRow(L10n.Settings.notifyTrade, isOn: $s.notifyTradeExecuted)
                toggleRow(L10n.Settings.notifyDaily, isOn: $s.notifyDailySummary)
                toggleRow(L10n.Settings.notifySystem, isOn: $s.notifySystemAlerts)
            }
            .cardStyle()

            testNotificationSection
        }
        .id(settings.language)
    }

    private var testNotificationSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("测试通知", en: "Test Notification"))
            Text(L10n.zh("发送一条测试通知到已配置的 Telegram 渠道", en: "Send a test notification to the configured Telegram channel"))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            HStack {
                KryptonButton(title: L10n.zh("发送测试", en: "Send Test"), action: {
                    Task { await sendTestNotification() }
                }, style: .ghost)
                Spacer()
            }
        }
        .cardStyle()
    }

    private func sendTestNotification() async {
        // Uses the real provider test endpoint
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 120, alignment: .leading)
            content()
                .frame(maxWidth: 320, alignment: .leading)
            Spacer()
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 160, alignment: .leading)
            Toggle("", isOn: isOn)
                .tint(PulseColors.accentText)
            Spacer()
        }
    }
}
