// WhaleConcentrationPanel.swift — §4 巨鲸与筹码集中；含共享 PercentileBar

import SwiftUI

/// 共享分位条：一条横条标记当前值在历史分位的位置
struct PercentileBar: View {
    let percentile: Double  // 0...1
    let label: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Text(label).font(PulseFonts.tabular)
                Spacer()
                Text("P\(Int(percentile * 100))").font(PulseFonts.micro).foregroundStyle(percentile > 0.9 ? PulseColors.danger : colors.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(colors.border).frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [PulseColors.accent, PulseColors.danger], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * percentile), height: 6)
                    Circle().fill(Color.white).frame(width: 8, height: 8)
                        .offset(x: max(0, geo.size.width * percentile - 4))
                }
            }
            .frame(height: 6)
        }
    }
}

struct WhaleConcentrationPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var onchain: EvidenceLayerPayload? { detail.evidenceLayers?["onchain"] }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.whaleConcentration)
                if let layer = onchain, layer.available, layer.quality >= 0.3 {
                    VStack(spacing: PulseSpacing.md) {
                        if let top10 = layer.features["top10_concentration"] {
                            PercentileBar(percentile: top10.percentile ?? 0, label: L10n.Manipulation.featTop10Concentration)
                        }
                        if let inflow = layer.features["exchange_inflow"] {
                            PercentileBar(percentile: inflow.percentile ?? 0, label: L10n.Manipulation.featExchangeInflow)
                        }
                        MetricGrid(features: layer.features, keys: ["whale_transfer_24h"])
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

private struct MetricGrid: View {
    let features: [String: FeaturePayload]
    let keys: [String]
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            ForEach(keys, id: \.self) { k in
                if let f = features[k] {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.replacingOccurrences(of: "_", with: " ")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        Text(f.display ?? String(format: "%.2f", f.value)).font(PulseFonts.tabular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
