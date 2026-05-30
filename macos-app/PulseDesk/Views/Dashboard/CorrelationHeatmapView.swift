// CorrelationHeatmapView.swift — 相关性热力图

import SwiftUI

struct CorrelationHeatmapView: View {
    @Environment(PulseColors.self) private var colors
    let snapshots: [CorrelationSnapshot]

    private var symbols: [String] {
        let set = Set(snapshots.flatMap { [$0.symbolA, $0.symbolB] })
        return Array(set).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("资产相关性")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            if snapshots.isEmpty {
                Text("暂无相关性数据")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                let syms = symbols
                Grid(alignment: .center, horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        Color.clear.frame(width: 40, height: 20)
                        ForEach(syms, id: \.self) { sym in
                            Text(sym.prefix(4))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                    ForEach(syms, id: \.self) { rowSym in
                        GridRow {
                            Text(rowSym.prefix(4))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .frame(width: 40, alignment: .trailing)
                            ForEach(syms, id: \.self) { colSym in
                                let val = correlationValue(symA: rowSym, symB: colSym)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForCorrelation(val))
                                    .frame(height: 28)
                                    .overlay(
                                        Text(String(format: "%.1f", val))
                                            .font(PulseFonts.micro)
                                            .foregroundStyle(.white.opacity(0.8))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.card)
    }

    private func correlationValue(symA: String, symB: String) -> Double {
        if symA == symB { return 1.0 }
        return snapshots.first { s in
            (s.symbolA == symA && s.symbolB == symB) ||
            (s.symbolA == symB && s.symbolB == symA)
        }?.correlation ?? 0.0
    }

    private func colorForCorrelation(_ val: Double) -> Color {
        let absVal = abs(val)
        if val > 0.7 { return PulseColors.danger.opacity(absVal) }
        if val > 0.3 { return PulseColors.warning.opacity(absVal) }
        if val < -0.3 { return PulseColors.info.opacity(absVal) }
        return PulseColors.accent.opacity(0.1)
    }
}
