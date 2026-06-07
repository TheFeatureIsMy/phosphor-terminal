// RiskSettingsView.swift — 风控参数设置

import SwiftUI

struct RiskSettingsView: View {
    @Environment(SettingsState.self) private var settings
    @Environment(PulseColors.self) private var colors

    var body: some View {
        @Bindable var s = settings

        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("风控参数")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // Group 1: Loss
                percentRow("单笔最大亏损 (%)", value: $s.maxSingleLoss)
                percentRow("最大回撤 (%)", value: $s.maxDrawdown)
                percentRow("日回撤上限 (%)", value: $s.dailyDrawdown)

                Divider().foregroundStyle(colors.border)

                // Group 2: Position
                percentRow("最大持仓比例 (%)", value: $s.maxPositionSize)

                Divider().foregroundStyle(colors.border)

                // Group 3: Correlation
                intRow("关联组上限", value: $s.correlatedGroupLimit)
                numRow("相关性阈值", value: $s.correlationThreshold)

                Divider().foregroundStyle(colors.border)

                // Group 4: Auto
                settingsRow("自动暂停") {
                    Toggle("", isOn: $s.autoPause)
                        .tint(PulseColors.accent)
                }
            }
            .cardStyle()

            Button(action: resetDefaults) {
                Text("恢复默认")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .padding(.top, PulseSpacing.xs)
        }
    }

    private func resetDefaults() {
        settings.maxSingleLoss = 5.0
        settings.maxDrawdown = 20.0
        settings.dailyDrawdown = 10.0
        settings.maxPositionSize = 25.0
        settings.correlatedGroupLimit = 3
        settings.correlationThreshold = 0.7
        settings.autoPause = true
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(PulseFonts.body).foregroundStyle(colors.textSecondary).frame(width: 140, alignment: .leading)
            content().frame(maxWidth: 280, alignment: .leading)
            Spacer()
        }
    }

    private func percentRow(_ label: String, value: Binding<Double>) -> some View {
        settingsRow(label) {
            HStack(spacing: PulseSpacing.xs) {
                TextField("", value: value, format: .number)
                    .darkTextField()
                    .frame(width: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(value.wrappedValue < 0 || value.wrappedValue > 100 ? PulseColors.danger : Color.clear, lineWidth: 1)
                    )
                Slider(value: value, in: 0...100)
                    .frame(width: 120)
                Text("%")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    private func numRow(_ label: String, value: Binding<Double>) -> some View {
        settingsRow(label) {
            TextField("", value: value, format: .number)
                .darkTextField()
        }
    }

    private func intRow(_ label: String, value: Binding<Int>) -> some View {
        settingsRow(label) {
            TextField("", value: value, format: .number)
                .darkTextField()
        }
    }
}
