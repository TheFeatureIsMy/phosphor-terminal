// AIModelStatusCard.swift — AI model runtime status row.
// Driven by /api/ai/models/runtime. Shows each model's provider / state /
// memory footprint. Empty-state when no models registered.

import SwiftUI

struct AIModelStatusCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let models: [AIModelStatusRef]
    let dataSourceAvailable: Bool

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: L10n.Dashboard.aiModelStatus)
                    Spacer()
                    if dataSourceAvailable, !models.isEmpty {
                        Text("\(runningCount)/\(models.count)")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                if !dataSourceAvailable {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        title: L10n.Dashboard.dataSourceUnavailable,
                        description: ""
                    )
                    .frame(minHeight: 100)
                } else if models.isEmpty {
                    EmptyStateView(
                        icon: "cpu",
                        title: L10n.Dashboard.aiModelsNoData,
                        description: ""
                    )
                    .frame(minHeight: 100)
                } else {
                    VStack(spacing: PulseSpacing.xxs) {
                        ForEach(models) { model in
                            row(model)
                        }
                    }
                }
            }
        }
        .id(settingsState.language)
    }

    private var runningCount: Int {
        models.filter { $0.state.lowercased() == "running" || $0.state.lowercased() == "available" }.count
    }

    private func row(_ model: AIModelStatusRef) -> some View {
        let tone = toneForState(model.state)
        return HStack(spacing: PulseSpacing.xs) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
                .shadow(color: tone.color.opacity(0.4), radius: 2)
            Text(model.name)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)
            Text(model.provider)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
            Spacer()
            if let mem = model.gpuMemoryMb {
                Text("\(mem) MB")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
            Text(tone.label)
                .font(PulseFonts.micro)
                .foregroundStyle(tone.color)
                .textCase(.uppercase)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func toneForState(_ state: String) -> (color: Color, label: String) {
        switch state.lowercased() {
        case "running", "available", "loaded":
            return (PulseColors.StateColors.green, L10n.Dashboard.aiModelsLoaded)
        case "not_loaded", "missing", "unloaded":
            return (PulseColors.StateColors.red, L10n.Dashboard.aiModelsMissing)
        default:
            return (PulseColors.StateColors.amber, state.uppercased())
        }
    }
}
