// EmergencyStopBar.swift — 48pt shared top bar for all 6 pages
// Left: ModePill (compact). Center: status text. Right: Emergency Stop / Resume button.
// Uses KryptonConfirmDialog for confirmation.

import SwiftUI

struct EmergencyStopBar: View {
    let mode: ModePill.Mode
    let affectedRuns: Int
    let emergencyLocked: Bool
    let onStop: () async -> Void
    let onResume: () async -> Void

    @Environment(PulseColors.self) private var colors
    @State private var showConfirm = false
    @State private var isActing = false

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            ModePill(mode: mode, compact: true)

            Divider().frame(height: 24)

            if emergencyLocked {
                Text(L10n.zh("紧急锁定中", en: "EMERGENCY LOCKED"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.danger)
            } else {
                Text("\(affectedRuns) \(L10n.zh("个策略运行中", en: "strategies running"))")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            Spacer()

            if emergencyLocked {
                Button {
                    showConfirm = true
                } label: {
                    Label(L10n.EmergencyStop.resume, systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(PulseColors.warning)
            } else {
                Button {
                    showConfirm = true
                } label: {
                    Label(L10n.EmergencyStop.emergencyStop, systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(PulseColors.danger)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(colors.surfaceHover.opacity(0.35))
        .overlay(Divider(), alignment: .bottom)
        .disabled(isActing)
        .sheet(isPresented: $showConfirm) {
            KryptonConfirmDialog(
                title: emergencyLocked
                    ? L10n.EmergencyStop.confirmResume
                    : L10n.EmergencyStop.confirmStop,
                message: confirmMessage,
                confirmLabel: emergencyLocked
                    ? L10n.EmergencyStop.resume
                    : L10n.EmergencyStop.emergencyStop,
                confirmStyle: emergencyLocked ? .warning : .danger,
                onConfirm: {
                    isActing = true
                    Task {
                        if emergencyLocked { await onResume() } else { await onStop() }
                        isActing = false
                    }
                    showConfirm = false
                },
                onCancel: { showConfirm = false }
            )
        }
    }

    // MARK: - Helpers

    private var confirmMessage: String {
        if emergencyLocked {
            return String(format: L10n.EmergencyStop.confirmResumeMessage, mode.label)
        }
        let base = String(
            format: L10n.EmergencyStop.confirmStopMessage,
            affectedRuns,
            mode.label
        )
        let modeNote = mode == .live
            ? L10n.EmergencyStop.liveModeWarning
            : L10n.EmergencyStop.paperModeNote
        return base + "\n\n" + modeNote
    }
}
