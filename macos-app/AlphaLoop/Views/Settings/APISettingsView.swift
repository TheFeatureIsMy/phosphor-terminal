// APISettingsView.swift — API 密钥管理

import SwiftUI

struct APISettingsView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var showSheet = false
    @State private var selectedProvider: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            TerminalLabel(text: L10n.zh("API 密钥", en: "API Keys"))

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                apiRow("Binance", configured: false)
                apiRow("Telegram Bot", configured: false)
                apiRow("OpenAI", configured: false)
            }
            .cardStyle()
        }
        .id(settingsState.language)
        .sheet(isPresented: $showSheet) {
            VStack {
                Text(L10n.zh("配置 \(selectedProvider)", en: "Configure \(selectedProvider)"))
                    .font(PulseFonts.displaySubheading)
                // stub — full implementation in later batch
            }
            .padding()
            .frame(width: 400, height: 300)
        }
    }

    private func apiRow(_ name: String, configured: Bool) -> some View {
        Button {
            selectedProvider = name
            showSheet = true
        } label: {
            HStack {
                Text(name)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                BadgeView(
                    text: configured ? L10n.zh("已配置", en: "Configured") : L10n.zh("未配置", en: "Not Configured"),
                    color: configured ? PulseColors.success : colors.textMuted
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.vertical, PulseSpacing.xxs)
        }
        .buttonStyle(.plain)
    }
}
