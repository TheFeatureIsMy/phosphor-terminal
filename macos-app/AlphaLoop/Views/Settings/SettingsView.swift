// SettingsView.swift - 系统设置页面
// 顶部 Tab 栏 + 下方内容面板

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settings
    @AppStorage("hideLearnAlphaLoopCard") private var hideLearnAlphaLoopCard: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            SettingsTabBar(selectedTab: $selectedTab)
            Divider().overlay(colors.border)
            ScrollView {
                settingsContent
                    .padding(PulseSpacing.lg)
            }
            .id(settings.language)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerSection: some View {
        QuantPageHeader(
            eyebrow: "SYSTEM",
            title: L10n.Settings.title,
            subtitle: L10n.zh("基础偏好 · 交易 · 数据源 · LLM · 通知 · 安全", en: "Preferences · Trading · Data · LLM · Notifications · Security")
        )
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .general:
            VStack(spacing: PulseSpacing.lg) {
                generalSection
                appearanceSection
                helpSection
                ProfileSettingsView()
            }
        case .trading:
            VStack(spacing: PulseSpacing.lg) {
                ExchangeSettingsView()
                RiskSettingsView()
            }
        case .dataProviders:
            DataSourcesView()
        case .llm:
            VStack(spacing: PulseSpacing.lg) {
                LLMProviderSettingsView()
            }
        case .notifications:
            NotificationSettingsView()
        case .security:
            VStack(spacing: PulseSpacing.lg) {
                McpServerSettingsView()
                securitySection
            }
        case .advanced:
            VStack(spacing: PulseSpacing.lg) {
                DataVacuumSettingsView()
                DangerZoneView()
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Settings.language)

            HStack {
                Text(L10n.Settings.language)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Picker("", selection: Bindable(settings).language) {
                    ForEach(Language.allCases) { lang in
                        Text("\(lang.flag) \(lang.displayName)")
                            .tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.language) { _, _ in
                    settings.scheduleSave()
                }
            }

            Divider().overlay(colors.border)

            HStack {
                Text(L10n.Settings.timezone)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text(TimeZone.current.identifier)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }

            Divider().overlay(colors.border)

            HStack {
                Text(L10n.Settings.dryRun)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Toggle("", isOn: Bindable(settings).dryRun)
                    .tint(PulseColors.accent)
                    .onChange(of: settings.dryRun) { _, _ in
                        settings.scheduleSave()
                    }
            }
        }
        .cardStyle()
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("外观", en: "Appearance"))
            HStack {
                Text(L10n.zh("主题", en: "Theme"))
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text(L10n.zh("暗黑赛博朋克", en: "Dark Cyberpunk"))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .cardStyle()
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Guide.title)
            HStack {
                Button {
                    UserGuide.open()
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                        Text(L10n.Guide.dashboardTitle)
                            .font(PulseFonts.body)
                    }
                    .foregroundStyle(colors.textPrimary)
                }
                .buttonStyle(.plain)
                .hoverGlassStyle(cornerRadius: PulseRadii.sm)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
            }
            HStack {
                Text(L10n.Guide.restoreCard)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { !hideLearnAlphaLoopCard },
                    set: { hideLearnAlphaLoopCard = !$0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
        .cardStyle()
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("安全与审计", en: "Security & Audit"))
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                securityRow(
                    icon: "lock.fill",
                    label: L10n.zh("API 密钥加密", en: "API Key Encryption"),
                    value: L10n.zh("Fernet 加密", en: "Fernet Encrypted")
                )
                securityRow(
                    icon: "eye.slash.fill",
                    label: L10n.zh("敏感信息", en: "Sensitive Info"),
                    value: L10n.zh("不明文展示", en: "Never Shown in Plaintext")
                )
                securityRow(
                    icon: "doc.text.magnifyingglass",
                    label: L10n.Settings.auditLog,
                    value: L10n.zh("Provider 变更已记录", en: "Provider Changes Logged")
                )
            }
        }
        .cardStyle()
    }

    private func securityRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
            Spacer()
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
        }
    }
}
