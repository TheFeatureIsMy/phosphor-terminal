// ExchangeSettingsView.swift — 交易所配置

import SwiftUI

struct ExchangeSettingsView: View {
    @Environment(SettingsState.self) private var settings
    @Environment(PulseColors.self) private var colors

    var body: some View {
        @Bindable var s = settings

        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text(L10n.zh("交易所配置", en: "Exchange Configuration"))
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                settingsRow(L10n.zh("交易所", en: "Exchange")) {
                    Picker("", selection: $s.exchange) {
                        ForEach(Exchange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .darkPicker()
                }

                settingsRow(L10n.zh("交易模式", en: "Trading Mode")) {
                    Picker("", selection: $s.tradingMode) {
                        ForEach(TradingMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .darkSegmentedPicker()
                }

                settingsRow("API Key") {
                    SecureField(L10n.zh("输入 API Key", en: "Enter API Key"), text: $s.apiKey)
                        .darkTextField()
                }

                settingsRow("API Secret") {
                    SecureField(L10n.zh("输入 API Secret", en: "Enter API Secret"), text: $s.apiSecret)
                        .darkTextField()
                }

                settingsRow(L10n.zh("模拟交易", en: "Paper Trading")) {
                    Toggle("", isOn: $s.dryRun)
                        .tint(PulseColors.accent)
                }
            }
            .cardStyle()
        }
        .id(settings.language)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            content()
                .frame(maxWidth: 320, alignment: .leading)
            Spacer()
        }
    }
}
