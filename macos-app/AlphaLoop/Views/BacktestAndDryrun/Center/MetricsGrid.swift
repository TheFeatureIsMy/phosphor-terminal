// MetricsGrid.swift — 2×4 紧凑数据卡

import SwiftUI

struct MetricsGrid: View {
    let run: BacktestRunV2
    @Environment(PulseColors.self) private var colors

    var body: some View {
        let metrics: [(String, String, Bool)] = [
            (L10n.zh("总收益率", en: "Total Return"), String(format: "%+.2f%%", run.totalReturn * 100), run.totalReturn >= 0),
            (L10n.zh("最大回撤", en: "Max Drawdown"), String(format: "%.2f%%", run.maxDrawdown * 100), false),
            (L10n.zh("夏普比率", en: "Sharpe Ratio"), String(format: "%.2f", run.sharpeRatio), run.sharpeRatio >= 1),
            (L10n.zh("胜率", en: "Win Rate"), String(format: "%.1f%%", run.winRate * 100), run.winRate >= 0.5),
            (L10n.zh("利润因子", en: "Profit Factor"), String(format: "%.2f", run.profitFactor), run.profitFactor >= 1),
            (L10n.zh("交易次数", en: "Total Trades"), "\(run.totalTrades)", true),
            (L10n.zh("实际成交", en: "Filled"), "\(run.trades.count)", true),
            (L10n.zh("平均持仓", en: "Avg Duration"), run.trades.first?.duration ?? "\u{2014}", true),
        ]

        LazyVGrid(columns: [GridItem(.flexible(), spacing: PulseSpacing.md), GridItem(.flexible(), spacing: PulseSpacing.md), GridItem(.flexible(), spacing: PulseSpacing.md), GridItem(.flexible())], spacing: PulseSpacing.md) {
            ForEach(metrics.indices, id: \.self) { idx in
                let m = metrics[idx]
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.1)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(m.2 ? PulseColors.accent : PulseColors.danger)
                    Text(m.0)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PulseSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(colors.surfaceHover.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
                )
            }
        }
    }
}
