// PositionsTableView.swift — 持仓表格
// 自适应列宽 + PnL 着色

import SwiftUI

struct PositionsTableView: View {
    @Environment(PulseColors.self) private var colors
    let positions: [Position]

    // 列宽比例（总和=100）
    private let colSymbol: CGFloat = 14
    private let colSide: CGFloat = 10
    private let colQty: CGFloat = 12
    private let colAvg: CGFloat = 14
    private let colPnL: CGFloat = 14
    private let colSL: CGFloat = 12
    private let colTP: CGFloat = 12
    private let colStatus: CGFloat = 12
    private let colTotal: CGFloat = 100

    private var firstDataSource: DataSourceStatus? {
        positions.first(where: { $0.dataSource != nil })?.dataSource
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 数据来源
            HStack {
                DataSourceBadge(status: firstDataSource)
                Spacer()
            }
            .padding(.bottom, PulseSpacing.xxs)

            headerRow
            Divider().foregroundStyle(colors.border)

            ForEach(Array(positions.enumerated()), id: \.element.id) { index, pos in
                dataRow(pos)
                    .staggeredAppearance(index: index, baseDelay: 0.02)
                    .background(index % 2 == 0 ? colors.surface.opacity(0.3) : Color.clear)
            }
        }
        .padding(PulseSpacing.md)
    }

    private var headerRow: some View {
        HStack(spacing: PulseSpacing.xs) {
            hCell("交易对", ratio: colSymbol)
            hCell("方向", ratio: colSide)
            hCell("数量", ratio: colQty, alignment: .trailing)
            hCell("均价", ratio: colAvg, alignment: .trailing)
            hCell("未实现盈亏", ratio: colPnL, alignment: .trailing)
            hCell("止损", ratio: colSL, alignment: .trailing)
            hCell("止盈", ratio: colTP, alignment: .trailing)
            hCell("状态", ratio: colStatus)
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    private func hCell(_ title: String, ratio: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: alignment)
            .layoutPriority(ratio / colTotal)
    }

    private func dataRow(_ pos: Position) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Text(pos.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .layoutPriority(colSymbol / colTotal)

            Text(pos.side.label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(pos.side.color(colors))
                .layoutPriority(colSide / colTotal)

            Text(String(format: "%.4f", pos.quantity))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colQty / colTotal)

            Text(String(format: "%.2f", pos.avgPrice))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colAvg / colTotal)

            Text(String(format: "%+.2f", pos.unrealizedPnl))
                .font(PulseFonts.caption.weight(.medium))
                .foregroundStyle(pos.unrealizedPnl >= 0 ? colors.profit : PulseColors.loss)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colPnL / colTotal)

            Text(pos.stopLossPrice.map { String(format: "%.2f", $0) } ?? "-")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colSL / colTotal)

            Text(pos.takeProfitPrice.map { String(format: "%.2f", $0) } ?? "-")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colTP / colTotal)

            BadgeView(text: "持仓中", color: PulseColors.statusActive, size: .small)
                .layoutPriority(colStatus / colTotal)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }
}
