// EvidenceLayerMatrix.swift — §3 5 Layer × score 条 + data_quality 徽章（不展开 feature）

import SwiftUI

struct EvidenceLayerMatrix: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private let layerOrder: [(key: String, label: String)] = [
        ("A_price", L10n.Manipulation.layerPrice),
        ("B_orderbook", L10n.Manipulation.layerOrderbook),
        ("C_onchain", L10n.Manipulation.layerOnchain),
        ("D_social", L10n.Manipulation.layerSocial),
        ("E_cross_market", L10n.Manipulation.layerCrossMarket),
    ]

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.evidenceMatrix)
                if let layers = detail.evidenceLayers, !layers.isEmpty {
                    VStack(spacing: PulseSpacing.md) {
                        ForEach(layerOrder, id: \.key) { entry in
                            if let layer = layers[entry.key] {
                                EvidenceLayerRow(label: entry.label, layer: layer)
                            }
                        }
                    }
                } else {
                    Text(L10n.Manipulation.dataUnavailable)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct EvidenceLayerRow: View {
    let label: String
    let layer: EvidenceLayerPayload
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Text(label).font(PulseFonts.tabular)
                Spacer()
                if !layer.available || layer.quality < 0.3 {
                    Label(L10n.Manipulation.dataUnavailable, systemImage: "exclamationmark.triangle")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.amber)
                } else {
                    Text("quality \(Int(layer.quality * 100))%")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
            if layer.available {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(colors.border).frame(height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(layer.score > 0.8 ? PulseColors.danger : PulseColors.accent)
                            .frame(width: max(2, geo.size.width * layer.score), height: 6)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text(String(format: "%.2f", layer.score)).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    Spacer()
                }
            }
        }
    }
}
