// ProviderCardView.swift — AI Provider 卡片

import SwiftUI

struct ProviderCardView: View {
    @Environment(PulseColors.self) private var colors
    let provider: AIProviderInfo
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Image(systemName: iconForProvider)
                    .font(.system(size: 18))
                    .foregroundStyle(provider.isAvailable ? PulseColors.accent : colors.textMuted)

                VStack(alignment: .leading) {
                    Text(provider.name)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(provider.type)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                Circle()
                    .fill(provider.isAvailable ? PulseColors.success : PulseColors.danger)
                    .frame(width: 8, height: 8)
            }

            if let baseUrl = provider.baseUrl {
                Text(baseUrl)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .lineLimit(1)
            }

            HStack {
                if let count = provider.modelCount {
                    Text("\(count) 模型")
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.accent)
                }

                Spacer()

                Button("测试连接") { onTest() }
                    .buttonStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.accent)
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.card)
    }

    private var iconForProvider: String {
        switch provider.type {
        case "ollama": return "desktopcomputer"
        case "openai", "openai_compatible": return "cloud"
        case "anthropic": return "brain"
        default: return "server.rack"
        }
    }
}
