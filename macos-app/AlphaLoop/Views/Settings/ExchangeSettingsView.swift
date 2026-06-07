// ExchangeSettingsView.swift — 交易所配置

import SwiftUI

struct ExchangeSettingsView: View {
    @Environment(SettingsState.self) private var settings
    @Environment(PulseColors.self) private var colors

    var body: some View {
        @Bindable var s = settings

        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("交易所配置")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                settingsRow("交易所") {
                    Picker("", selection: $s.exchange) {
                        ForEach(Exchange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .darkPicker()
                }

                settingsRow("交易模式") {
                    Picker("", selection: $s.tradingMode) {
                        ForEach(TradingMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .darkSegmentedPicker()
                }

                settingsRow("API Key") {
                    SecureField("输入 API Key", text: $s.apiKey)
                        .darkTextField()
                }

                settingsRow("API Secret") {
                    SecureField("输入 API Secret", text: $s.apiSecret)
                        .darkTextField()
                }

                settingsRow("模拟交易") {
                    Toggle("", isOn: $s.dryRun)
                        .tint(PulseColors.accent)
                }
            }
            .cardStyle()
        }
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
