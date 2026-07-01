// CrossMarketPressurePanel.swift — §5 跨市场压力

import SwiftUI

struct CrossMarketPressurePanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var cross: EvidenceLayerPayload? { detail.evidenceLayers?["cross_market"] }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.crossMarketPressure)
                if let layer = cross, layer.available, layer.quality >= 0.3 {
                    VStack(spacing: PulseSpacing.md) {
                        if let fr = layer.features["funding_rate_z"] {
                            PercentileBar(percentile: abs(fr.percentile ?? 0), label: L10n.Manipulation.featFundingRate)
                        }
                        HStack(spacing: PulseSpacing.md) {
                            FeatureMetric(key: "open_interest_change", features: layer.features, label: L10n.Manipulation.featOpenInterest)
                            FeatureMetric(key: "long_short_ratio", features: layer.features, label: L10n.Manipulation.featLongShortRatio)
                            FeatureMetric(key: "basis", features: layer.features, label: L10n.Manipulation.featBasis)
                        }
                    }
                } else {
                    Text(L10n.Manipulation.dataUnavailable)
                        .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct FeatureMetric: View {
    let key: String
    let features: [String: FeaturePayload]
    let label: String
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            if let f = features[key] {
                Text(f.display ?? String(format: "%.2f", f.value)).font(PulseFonts.tabular)
            } else {
                Text("—").font(PulseFonts.tabular).foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
