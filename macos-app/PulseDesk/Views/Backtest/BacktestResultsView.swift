// BacktestResultsView.swift — 回测结果展示
// 指标网格 + 权益曲线 + 交易列表

import SwiftUI

struct BacktestResultsView: View {
    @Environment(PulseColors.self) private var colors
    let backtest: Backtest

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            // 标题 + 状态
            HStack {
                Text("回测结果")
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)

                Spacer()

                DataSourceBadge(status: backtest.dataSource)

                BadgeView(
                    text: backtest.passed ? "通过" : "未通过",
                    color: backtest.passed ? PulseColors.success : PulseColors.danger
                )
            }

            // 指标网格
            metricsGrid

            // 权益曲线
            EquityCurveChart(points: backtest.result.equityCurve)

            // 交易列表
            tradesSection
        }
    }

    // MARK: - 指标网格
    private var metricsGrid: some View {
        let m = backtest.result.metrics
        typealias MetricItem = (label: String, value: String, color: Color)
        let items: [MetricItem] = [
            ("总收益", String(format: "%.1f%%", m.totalReturn), m.totalReturn >= 0 ? colors.profit : PulseColors.loss),
            ("夏普比率", String(format: "%.2f", m.sharpeRatio), PulseColors.accent),
            ("最大回撤", String(format: "%.1f%%", m.maxDrawdown), PulseColors.loss),
            ("胜率", String(format: "%.1f%%", m.winRate), colors.profit),
            ("盈亏比", String(format: "%.2f", m.profitFactor), PulseColors.accent),
            ("总交易", "\(m.totalTrades)", colors.textPrimary),
            ("平均持仓", m.avgTradeDuration, colors.textSecondary),
            ("最佳交易", String(format: "$%.0f", m.bestTrade), colors.profit),
        ]
        return LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120, maximum: 200), spacing: PulseSpacing.md)
        ], spacing: PulseSpacing.md) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                metricCard(item.label, value: item.value, color: item.color)
                    .staggeredAppearance(index: index)
                    .hoverEffect()
            }
        }
    }

    private func metricCard(_ label: String, value: String, color: Color) -> some View {
        GlassCard(cardPadding: PulseSpacing.sm) {
            VStack(spacing: PulseSpacing.xxs) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 交易列表
    private var tradesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("交易记录 (\(backtest.result.trades.count))")
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.bottom, PulseSpacing.sm)

                ForEach(Array(backtest.result.trades.enumerated()), id: \.element.id) { index, trade in
                    HStack(spacing: PulseSpacing.xs) {
                        Text(trade.side.label)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(trade.side.color(colors))
                        Text(trade.symbol)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textPrimary)
                        Spacer()
                        if let profit = trade.profit {
                            Text(String(format: "%+.0f", profit))
                                .font(PulseFonts.caption)
                                .foregroundStyle(profit >= 0 ? colors.profit : PulseColors.loss)
                        }
                    }
                    .padding(.vertical, PulseSpacing.xxs)
                    if index < backtest.result.trades.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}
