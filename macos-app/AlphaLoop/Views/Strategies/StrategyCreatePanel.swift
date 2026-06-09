// StrategyCreatePanel.swift — v2.5 新建策略面板
// 使用液态玻璃背景，与全局风格一致

import SwiftUI

struct StrategyCreatePanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(\.networkClient) private var networkClient
    @Environment(SettingsState.self) private var settingsState

    @State private var name = ""
    @State private var isCreating = false

    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                TerminalLabel(text: L10n.zh("新建策略", en: "New Strategy"))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .background(colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("策略名称", en: "Strategy Name"))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textSecondary)
                TextField(L10n.zh("输入策略名称...", en: "Enter strategy name..."), text: $name)
                    .darkTextField()
            }

            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: "lightbulb")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.amber)
                Text(L10n.zh("创建后进入详情页，在 DSL 规则中编写策略逻辑", en: "After creation, define strategy logic in the DSL Rules tab"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            .padding(PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(PulseColors.amber.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(PulseColors.amber.opacity(0.1), lineWidth: 1)
                    )
            )

            HStack {
                KryptonButton(title: L10n.zh("取消", en: "Cancel"), action: onCancel, style: .ghost)
                Spacer()
                KryptonButton(title: isCreating ? L10n.zh("创建中...", en: "Creating...") : L10n.zh("创建策略", en: "Create Strategy")) {
                    Task { await doCreate() }
                }
                .opacity(name.isEmpty ? 0.5 : 1)
                .disabled(name.isEmpty || isCreating)
            }
        }
        .padding(PulseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 1)
        )
        .applyShadow(PulseShadow.elevated(colors))
    }

    private func doCreate() async {
        isCreating = true
        let api = APIStrategiesV2(client: networkClient)
        if let strategy = try? await api.create(name: name) {
            appState.selectedStrategyV2Id = strategy.id
            appState.selectedRoute = .strategyDetail
        }
        isCreating = false
    }
}
