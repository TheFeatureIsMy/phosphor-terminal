// SettingsView.swift — 系统设置页面
// 顶部 Tab 栏 + 下方内容面板

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                TerminalLabel(text: L10n.Settings.title)
                Spacer()
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.vertical, PulseSpacing.sm)

            // Tab bar
            SettingsTabBar(selectedTab: $selectedTab)

            Divider().overlay(colors.border)

            // Content
            ScrollView {
                settingsContent
                    .padding(PulseSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .general:
            VStack(spacing: PulseSpacing.lg) {
                languageSection
                ProfileSettingsView()
            }
        case .trading:
            VStack(spacing: PulseSpacing.lg) {
                ExchangeSettingsView()
                RiskSettingsView()
            }
        case .notifications:
            NotificationSettingsView()
        case .api:
            APISettingsView()
        case .services:
            McpServerSettingsView()
        case .data:
            DataVacuumSettingsView()
        case .advanced:
            DangerZoneView()
        }
    }

    // MARK: - 语言选择

    private var languageSection: some View {
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
        }
        .cardStyle()
    }
}
