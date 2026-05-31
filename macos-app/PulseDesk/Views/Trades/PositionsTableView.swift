// PositionsTableView.swift — 持仓表格
// 可展开行 + PnL 着色 + 未来迷你图表占位

import SwiftUI

struct PositionsTableView: View {
    @Environment(PulseColors.self) private var colors
    let positions: [Position]

    @State private var expandedIndex: Int? = nil

    private var firstDataSource: DataSourceStatus? {
        positions.first(where: { $0.dataSource != nil })?.dataSource
    }

    var body: some View {
        ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                // 数据来源
                HStack {
                    DataSourceBadge(status: firstDataSource)
                    Spacer()
                }
                .padding(.bottom, PulseSpacing.xxs)

                // 数据行
                ForEach(Array(positions.enumerated()), id: \.element.id) { index, pos in
                    positionRow(pos, index: index)
                        .staggeredAppearance(index: index, baseDelay: 0.02)

                    if index < positions.count - 1 {
                        Divider()
                            .foregroundStyle(colors.border.opacity(0.5))
                    }
                }
            }
        }
    }

    private func positionRow(_ pos: Position, index: Int) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(PulseAnimation.springDefault) {
                    expandedIndex = (expandedIndex == index) ? nil : index
                }
            } label: {
                HStack(spacing: PulseSpacing.sm) {
                    // PnL direction bar
                    RoundedRectangle(cornerRadius: 1)
                        .fill(pos.unrealizedPnl >= 0 ? colors.profit : colors.loss)
                        .frame(width: 3, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(pos.symbol)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        HStack(spacing: PulseSpacing.xxs) {
                            Text(pos.side.label)
                                .font(PulseFonts.micro)
                                .foregroundStyle(pos.side.color(colors))
                            Text("\u{00B7}")
                                .foregroundStyle(colors.textMuted)
                            Text("\(String(format: "%.4f", pos.quantity)) @ \(String(format: "%.2f", pos.avgPrice))")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%+.2f", pos.unrealizedPnl))
                            .font(PulseFonts.tabular.weight(.medium))
                            .foregroundStyle(pos.unrealizedPnl >= 0 ? colors.profit : colors.loss)
                        Text(pnlPercent(pos))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    Image(systemName: expandedIndex == index ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 16)
                }
                .padding(.vertical, PulseSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedIndex == index {
                VStack(spacing: PulseSpacing.xs) {
                    Divider()
                        .foregroundStyle(colors.border)

                    HStack(spacing: PulseSpacing.lg) {
                        posDetail("止损", pos.stopLossPrice.map { String(format: "%.2f", $0) } ?? "\u{2014}")
                        posDetail("止盈", pos.takeProfitPrice.map { String(format: "%.2f", $0) } ?? "\u{2014}")
                        posDetail("开仓时间", fmtDate(pos.openedAt))
                        posDetail("状态", "持仓中")
                    }

                    // Placeholder for future mini chart
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.surface)
                        .frame(height: 60)
                        .overlay(
                            HStack(spacing: PulseSpacing.xxs) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 11))
                                    .foregroundStyle(colors.textMuted)
                                Text("收益走势 \u{2014} 需要后端按持仓代码返回历史盈亏数据")
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                            }
                        )
                }
                .padding(.bottom, PulseSpacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(index % 2 == 0 ? colors.surface.opacity(0.3) : Color.clear)
        )
    }

    private func posDetail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
        }
    }

    private func pnlPercent(_ pos: Position) -> String {
        let cost = pos.quantity * pos.avgPrice
        guard cost != 0 else { return "\u{2014}" }
        return String(format: "%+.1f%%", (pos.unrealizedPnl / cost) * 100)
    }

    private func fmtDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}
