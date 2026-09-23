// LiveWireStrip.swift — VOLT 2pt 全宽氛围模式指示条
// LIVE 电光黄 / PAPER 琥珀 / DRYRUN 紫 / MOCK 灰 / STOPPED 红脉冲 / else 暗灰

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
            // VOLT: 电光黄氛围条
            return [PulseColors.accent.opacity(0.5), PulseColors.accent, PulseColors.accent.opacity(0.5)]
        case .paper:
            return [PulseColors.warning.opacity(0.7), PulseColors.warning, PulseColors.warning.opacity(0.7)]
        case .dryRun:
            return [PulseColors.violet.opacity(0.7), PulseColors.violet, PulseColors.violet.opacity(0.7)]
        case .mock:
            return [Color.gray.opacity(0.5), Color.gray, Color.gray.opacity(0.5)]
        case .stopped:
            return [PulseColors.danger.opacity(0.7), PulseColors.danger, PulseColors.danger.opacity(0.7)]
        case .notReady, .unknown:
            return [Color.gray.opacity(0.3), Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
        }
    }
}
