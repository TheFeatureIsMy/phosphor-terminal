// LiveWireStrip.swift — 2pt full-width ambient mode indicator
// Shown at the top of every page to convey the current trading mode at a glance.
// LIVE red / PAPER amber / DRYRUN purple / MOCK gray / STOPPED red pulse / else muted.

import SwiftUI

struct LiveWireStrip: View {
    let mode: ModePill.Mode

    @State private var pulse = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: stripColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(
                isEmergency
                    ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear {
                if isEmergency { pulse = true }
            }
            .onChange(of: mode) { newMode in
                pulse = newMode == .stopped
            }
    }

    private var isEmergency: Bool {
        mode == .stopped
    }

    private var stripColors: [Color] {
        switch mode {
        case .live:
            return [PulseColors.danger.opacity(0.7), PulseColors.danger, PulseColors.danger.opacity(0.7)]
        case .paper:
            return [PulseColors.warning.opacity(0.7), PulseColors.warning, PulseColors.warning.opacity(0.7)]
        case .dryRun:
            return [PulseColors.purple.opacity(0.7), PulseColors.purple, PulseColors.purple.opacity(0.7)]
        case .mock:
            return [Color.gray.opacity(0.5), Color.gray, Color.gray.opacity(0.5)]
        case .stopped:
            return [PulseColors.danger, Color.white.opacity(0.6), PulseColors.danger]
        case .notReady, .unknown:
            return [Color.gray.opacity(0.3), Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
        }
    }
}
