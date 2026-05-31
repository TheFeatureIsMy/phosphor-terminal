// OrdersTableView.swift — 订单表格
// 自适应列宽 + PnL 着色 + 状态徽章

import SwiftUI

struct OrdersTableView: View {
    @Environment(PulseColors.self) private var colors
    let orders: [Order]

    // 列宽比例（总和=10）
    private let colTime: CGFloat = 14
    private let colSymbol: CGFloat = 14
    private let colSide: CGFloat = 10
    private let colType: CGFloat = 10
    private let colQty: CGFloat = 12
    private let colPrice: CGFloat = 14
    private let colPnL: CGFloat = 14
    private let colStatus: CGFloat = 12
    private let colTotal: CGFloat = 100

    private var firstDataSource: DataSourceStatus? {
        orders.first(where: { $0.dataSource != nil })?.dataSource
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 数据来源
            HStack {
                DataSourceBadge(status: firstDataSource)
                Spacer()
            }
            .padding(.bottom, PulseSpacing.xxs)

            // 表头
            headerRow

            Divider()
                .foregroundStyle(colors.border)

            // 数据行
            ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                dataRow(order)
                    .staggeredAppearance(index: index, baseDelay: 0.02)
                    .background(index % 2 == 0 ? colors.surface.opacity(0.3) : Color.clear)
            }
        }
        .padding(PulseSpacing.md)
    }

    private var headerRow: some View {
        HStack(spacing: PulseSpacing.xs) {
            headerCell("时间", ratio: colTime)
            headerCell("交易对", ratio: colSymbol)
            headerCell("方向", ratio: colSide)
            headerCell("类型", ratio: colType)
            headerCell("数量", ratio: colQty, alignment: .trailing)
            headerCell("价格", ratio: colPrice, alignment: .trailing)
            headerCell("盈亏", ratio: colPnL, alignment: .trailing)
            headerCell("状态", ratio: colStatus)
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    private func headerCell(_ title: String, ratio: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: alignment)
            .frame(maxWidth: .infinity)
            .layoutPriority(ratio / colTotal)
    }

    private func dataRow(_ order: Order) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Text(formatDate(order.timestamp))
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .layoutPriority(colTime / colTotal)

            Text(order.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .layoutPriority(colSymbol / colTotal)

            Text(order.side.label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(order.side.color(colors))
                .layoutPriority(colSide / colTotal)

            Text(order.orderType.label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
                .layoutPriority(colType / colTotal)

            Text(String(format: "%.4f", order.quantity))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colQty / colTotal)

            Text(formatPrice(order.filledPrice ?? order.price))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colPrice / colTotal)

            Text(formatPnL(order.profit))
                .font(PulseFonts.caption.weight(.medium))
                .foregroundStyle((order.profit ?? 0) >= 0 ? colors.profit : PulseColors.loss)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(colPnL / colTotal)

            BadgeView(text: order.status.label, color: order.status.color(colors), size: .small)
                .layoutPriority(colStatus / colTotal)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    private func formatPrice(_ price: Double?) -> String {
        guard let p = price else { return "-" }
        return p >= 1000 ? String(format: "%.0f", p) : String(format: "%.2f", p)
    }

    private func formatPnL(_ pnl: Double?) -> String {
        guard let p = pnl else { return "-" }
        return String(format: "%+.2f", p)
    }
}
