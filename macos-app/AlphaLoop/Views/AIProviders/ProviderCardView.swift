// ProviderCardView.swift — AI Provider 卡片（保留兼容性）
// 注意：AIProvidersView 已内联卡片实现，此文件保留供其他页面引用

import SwiftUI

struct ProviderCardView: View {
    @Environment(PulseColors.self) private var colors
    let provider: AIProviderInfo
    let onTest: () -> Void

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    Image(systemName: iconForProvider)
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(provider.isAvailable ? PulseColors.accent : colors.textMuted)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(provider.name)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text(provider.type)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    Spacer()

                    StatusDot(status: provider.isAvailable ? .online : .offline)
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
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                }
            }
        }
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
