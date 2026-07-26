// APISettingsView.swift - API 密钥管理（连接真实 provider API）

import SwiftUI

struct APISettingsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var providers: [ProviderConfigView] = []
    @State private var isLoading = false

    private var api: APIAIProviders { APIAIProviders(client: networkClient) }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            TerminalLabel(text: L10n.Settings.apiKeys)

            if isLoading {
                LoadingView(type: .detail)
            } else if providers.isEmpty {
                Text(L10n.zh("暂无已配置的 API 密钥", en: "No API keys configured"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            } else {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    ForEach(providers) { provider in
                        apiRow(provider)
                    }
                }
                .cardStyle()
            }
        }
        .id(settingsState.language)
        .task { await load() }
    }

    private func apiRow(_ provider: ProviderConfigView) -> some View {
        HStack {
            Image(systemName: iconForCategory(provider.category))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(provider.providerName.capitalized)")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Text(provider.category)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            BadgeView(
                text: credentialLabel(provider.credentialStatus),
                color: credentialColor(provider.credentialStatus)
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(colors.textMuted)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "llm": return "brain"
        case "cex": return "chart.bar"
        case "notification": return "bell"
        case "market_data": return "chart.line.uptrend.xyaxis"
        case "onchain": return "link.circle"
        case "social": return "bubble.left.and.bubble.right"
        case "news": return "newspaper"
        default: return "key"
        }
    }

    private func credentialLabel(_ status: String) -> String {
        switch status {
        case "configured": return L10n.zh("已配置", en: "Configured")
        case "missing": return L10n.zh("未配置", en: "Not Configured")
        case "invalid": return L10n.zh("无效", en: "Invalid")
        case "expired": return L10n.zh("过期", en: "Expired")
        default: return status
        }
    }

    private func credentialColor(_ status: String) -> Color {
        switch status {
        case "configured": return PulseColors.success
        case "missing": return colors.textMuted
        case "invalid", "expired": return PulseColors.danger
        default: return PulseColors.warning
        }
    }

    private func load() async {
        isLoading = true
        do {
            providers = try await api.listProviders()
        } catch {
            providers = []
        }
        isLoading = false
    }
}
