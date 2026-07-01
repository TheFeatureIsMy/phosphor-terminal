// TradeListTable.swift — 紧凑表格 + 折叠 + 前 20 行分页

import SwiftUI

struct TradeListTable: View {
    let trades: [TradeRow]
    @Binding var isExpanded: Bool
    @Environment(PulseColors.self) private var colors
    @State private var showAll = false

    private let pageSize = 20
    private var displayed: [TradeRow] { showAll ? trades : Array(trades.prefix(pageSize)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.BacktestLab.sectionTradeList)
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text("\(trades.count) \(L10n.zh("笔", en: "trades"))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(PulseSpacing.md)

            if isExpanded {
                if trades.isEmpty {
                    Text(L10n.BacktestLab.noTrades)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(PulseSpacing.md)
                } else {
                    headerRow
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, t in
                        tradeRow(idx + 1, t)
                    }
                    if !showAll && trades.count > pageSize {
                        Button { showAll = true } label: {
                            Text(L10n.BacktestLab.showAllTrades(trades.count))
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(PulseColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(PulseSpacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("#", width: 40)
            cell(L10n.zh("时间", en: "Time"), width: 120)
            cell(L10n.zh("方向", en: "Side"), width: 60)
            cell(L10n.zh("入场", en: "Entry"), width: 90)
            cell(L10n.zh("出场", en: "Exit"), width: 90)
            cell(L10n.zh("盈亏", en: "PnL"), width: 80)
            cell(L10n.zh("时长", en: "Duration"))
            Spacer()
        }
        .font(PulseFonts.monoLabel)
        .foregroundStyle(colors.textMuted)
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, 6)
        .background(colors.surfaceHover.opacity(0.2))
    }

    private func tradeRow(_ idx: Int, _ t: TradeRow) -> some View {
        HStack(spacing: 0) {
            cell("\(idx)", width: 40)
            cell(t.openTime.prefix(16).description, width: 120)
            cell(t.side.uppercased(), width: 60, color: t.side.uppercased() == "LONG" ? PulseColors.accent : PulseColors.danger)
            cell(String(format: "%.2f", t.openPrice), width: 90)
            cell(String(format: "%.2f", t.closePrice), width: 90)
            cell(String(format: "%+.2f", t.profit), width: 80, color: t.profit >= 0 ? PulseColors.accent : PulseColors.danger)
            cell(t.duration)
            Spacer()
        }
        .font(PulseFonts.tabular)
        .foregroundStyle(colors.textPrimary)
        .padding(.horizontal, PulseSpacing.md)
        .frame(height: 32)
        .background(colors.surfaceHover.opacity(0.1))
    }

    private func cell(_ text: String, width: CGFloat? = nil, color: Color? = nil) -> some View {
        Text(text)
            .foregroundStyle(color ?? colors.textPrimary)
            .frame(width: width, alignment: .leading)
    }
}
