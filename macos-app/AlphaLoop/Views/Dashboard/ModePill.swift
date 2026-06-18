// ModePill.swift — Mode indicator (LIVE / PAPER / DRYRUN / STOPPED / MOCK / NOT READY)
// Driven by the BFF `system.liveReadinessState` plus the iOS-side `isLiveMode`
// and `isMockMode` flags. Reused by the top bar and the Dashboard page header.

import SwiftUI

struct ModePill: View {
    enum Mode: Hashable {
        case live
        case paper
        case dryRun
        case stopped
        case mock
        case notReady
        case unknown

        var label: String {
            switch self {
            case .live: return L10n.Dashboard.modeLive
            case .paper: return L10n.Dashboard.modePaper
            case .dryRun: return L10n.Dashboard.modeDryRun
            case .stopped: return L10n.Dashboard.modeStopped
            case .mock: return L10n.Dashboard.modeMock
            case .notReady: return L10n.Dashboard.modeNotReady
            case .unknown: return L10n.Dashboard.modeNotReady
            }
        }

        var icon: String {
            switch self {
            case .live: return "bolt.fill"
            case .paper: return "doc.plaintext.fill"
            case .dryRun: return "play.rectangle.fill"
            case .stopped: return "stop.fill"
            case .mock: return "wand.and.stars"
            case .notReady, .unknown: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .live: return PulseColors.accent
            case .paper: return PulseColors.cyan
            case .dryRun: return PulseColors.purple
            case .stopped: return PulseColors.danger
            case .mock: return PulseColors.warning
            case .notReady, .unknown: return colors_for_unavailable()
            }
        }

        private func colors_for_unavailable() -> Color {
            // Defined as method so we can use the same alias for both color and live ambient.
            return Color.gray.opacity(0.6)
        }
    }

    let mode: Mode
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: mode.icon)
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .foregroundStyle(mode.color)
            Text(mode.label)
                .font(compact ? PulseFonts.micro : PulseFonts.monoLabel)
                .foregroundStyle(mode.color)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 2 : 4)
        .background(
            Capsule().fill(mode.color.opacity(0.10))
        )
        .overlay(
            Capsule().stroke(mode.color.opacity(0.30), lineWidth: 0.7)
        )
    }
}

extension ModePill.Mode {
    /// Derive mode from BFF state + iOS-side flags.
    static func resolve(
        liveReadinessState: String?,
        isLiveMode: Bool,
        isMockMode: Bool
    ) -> ModePill.Mode {
        if isMockMode { return .mock }
        let state = (liveReadinessState ?? "unknown").lowercased()
        switch state {
        case "live_ready", "live_small_ready", "live_full_ready", "live_running":
            return .live
        case "paper_only":
            return .paper
        case "dryrun", "dry_run":
            return .dryRun
        case "emergency_locked", "risk_locked", "stopped", "halted":
            return .stopped
        case "not_ready", "data_source_unavailable":
            return isLiveMode ? .notReady : .unknown
        default:
            return isLiveMode ? .notReady : .unknown
        }
    }
}
