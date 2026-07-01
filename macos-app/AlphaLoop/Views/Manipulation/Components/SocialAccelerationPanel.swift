// SocialAccelerationPanel.swift — §6 社交加速（data_quality<0.3 整段 Data unavailable）

import SwiftUI

struct SocialAccelerationPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var social: EvidenceLayerPayload? { detail.evidenceLayers?["D_social"] }
    private var isUnavailable: Bool {
        guard let l = social else { return true }
        return !l.available || l.quality < 0.3
    }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.socialAcceleration)
                if isUnavailable {
                    HStack(spacing: PulseSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(PulseColors.amber)
                        Text(L10n.Manipulation.dataUnavailable).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                } else if let layer = social {
                    VStack(spacing: PulseSpacing.md) {
                        if let mention = layer.features["mention_velocity"] {
                            PercentileBar(percentile: mention.percentile ?? 0, label: L10n.Manipulation.featMentionVelocity)
                        }
                        if let sentiment = layer.features["sentiment_extremity"] {
                            PercentileBar(percentile: sentiment.percentile ?? 0, label: L10n.Manipulation.featSentimentExtremity)
                        }
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}
