// APISettingsView.swift — API 密钥管理

import SwiftUI

struct APISettingsView: View {
    @Environment(PulseColors.self) private var colors
    @State private var showSheet = false
    @State private var selectedProvider: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            TerminalLabel(text: "API 密钥")

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                apiRow("Binance", configured: false)
                apiRow("Telegram Bot", configured: false)
                apiRow("OpenAI", configured: false)
            }
            .cardStyle()
        }
        .sheet(isPresented: $showSheet) {
            VStack {
                Text("配置 \(selectedProvider)")
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
                    text: configured ? "已配置" : "未配置",
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
