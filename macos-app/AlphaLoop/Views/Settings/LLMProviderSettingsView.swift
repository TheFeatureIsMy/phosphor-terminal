// LLMProviderSettingsView.swift - LLM 供应商设置
// 连接真实 /api/admin/providers?category=llm API

import SwiftUI

struct LLMProviderSettingsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var providers: [ProviderConfigView] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var testingId: Int?

    private var api: APIAIProviders { APIAIProviders(client: networkClient) }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            headerSection
            if isLoading {
                LoadingView(type: .detail)
            } else if let error = error {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: L10n.zh("加载失败", en: "Load Failed"),
                    description: error,
                    primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await load() } })
                )
            } else if providers.isEmpty {
                EmptyStateView(
                    icon: "brain",
                    title: L10n.zh("暂无 LLM 供应商", en: "No LLM Providers"),
                    description: L10n.zh("尚未配置任何 LLM 供应商", en: "No LLM providers configured yet")
                )
            } else {
                providerList
            }
        }
        .id(settingsState.language)
        .task { await load() }
    }

    private var headerSection: some View {
        QuantPageHeader(
            eyebrow: "SYSTEM",
            title: L10n.zh("LLM 供应商设置", en: "LLM Provider Settings"),
            subtitle: L10n.zh("供应商 · 模型 · 超时 · 最大 token · 温度 · 测试调用", en: "Provider · Model · Timeout · Max Tokens · Temperature · Test Call")
        ) {
            Button {
                Task { await load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            ForEach(providers) { provider in
                providerCard(provider)
            }
        }
    }

    private func providerCard(_ provider: ProviderConfigView) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                // Header
                HStack {
                    Text(provider.providerName.capitalized)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    if let instance = provider.instanceName {
                        Text("(\(instance))")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    BadgeView(
                        text: credentialLabel(provider.credentialStatus),
                        color: credentialColor(provider.credentialStatus)
                    )
                    if provider.enabled {
                        BadgeView(text: L10n.zh("启用", en: "Enabled"), color: PulseColors.success)
                    } else {
                        BadgeView(text: L10n.zh("禁用", en: "Disabled"), color: colors.textMuted)
                    }
                }

                // Config details (non-sensitive)
                if let baseUrl = configValue(provider, key: "base_url") {
                    configRow(label: L10n.zh("Base URL", en: "Base URL"), value: baseUrl)
                }
                if let model = configValue(provider, key: "model") {
                    configRow(label: L10n.zh("默认模型", en: "Default Model"), value: model)
                }
                if let timeout = configValue(provider, key: "timeout") {
                    configRow(label: L10n.zh("超时", en: "Timeout"), value: "\(timeout)s")
                }
                if let maxTokens = configValue(provider, key: "max_tokens") {
                    configRow(label: L10n.zh("最大 Token", en: "Max Tokens"), value: maxTokens)
                }
                if let temperature = configValue(provider, key: "temperature") {
                    configRow(label: L10n.zh("温度", en: "Temperature"), value: temperature)
                }

                // Credential fields (masked - never show plaintext)
                if !provider.credentialsFields.isEmpty {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "lock.fill")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(L10n.zh("凭证字段: \(provider.credentialsFields.joined(separator: ", "))", en: "Credential Fields: \(provider.credentialsFields.joined(separator: ", "))"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                // Status info
                if let latency = provider.latencyMs {
                    configRow(label: L10n.zh("延迟", en: "Latency"), value: "\(latency)ms")
                }
                if let lastError = provider.lastError, !lastError.isEmpty {
                    HStack(alignment: .top, spacing: PulseSpacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.danger)
                        Text(lastError)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.danger)
                            .lineLimit(2)
                    }
                }

                // Actions
                HStack(spacing: PulseSpacing.sm) {
                    Spacer()
                    if testingId == provider.id {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        KryptonButton(title: L10n.zh("测试", en: "Test"), action: {
                            Task { await testProvider(provider) }
                        }, style: .ghost)
                    }
                    if provider.enabled {
                        KryptonButton(title: L10n.zh("禁用", en: "Disable"), action: {
                            Task { await toggleProvider(provider) }
                        }, style: .ghost)
                    } else {
                        KryptonButton(title: L10n.zh("启用", en: "Enable")) {
                            Task { await toggleProvider(provider) }
                        }
                    }
                }
            }
        }
    }

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func configValue(_ provider: ProviderConfigView, key: String) -> String? {
        guard let codable = provider.config[key] else { return nil }
        let val = codable.value
        if let s = val as? String { return s }
        if let i = val as? Int { return String(i) }
        if let d = val as? Double { return String(d) }
        return nil
    }

    private func credentialLabel(_ status: String) -> String {
        switch status {
        case "configured": return L10n.zh("已配置", en: "Configured")
        case "missing": return L10n.zh("未配置", en: "Missing")
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

    // MARK: - Actions

    private func load() async {
        isLoading = true
        error = nil
        do {
            providers = try await api.listProviders()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func testProvider(_ provider: ProviderConfigView) async {
        testingId = provider.id
        defer { testingId = nil }
        do {
            let result = try await api.testConnection(body: ProviderTestRequestBody(
                category: provider.category,
                providerName: provider.providerName,
                credentials: [:],
                config: [:]
            ))
            _ = result
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleProvider(_ provider: ProviderConfigView) async {
        do {
            let endpoint = provider.enabled ? "disable" : "enable"
            let _: ProviderConfigView = try await networkClient.post(
                "/api/admin/providers/\(provider.id)/\(endpoint)",
                body: nil
            )
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
