// BacktestResultCardView.swift — 回测结果指标卡

import SwiftUI

struct BacktestResultCardView: View {
    @Environment(PulseColors.self) private var colors
    let run: BacktestRunV2

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            // Header
            HStack {
                Image(systemName: run.status == "completed" ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundStyle(run.status == "completed" ? PulseColors.success : PulseColors.warning)
                Text(run.status == "completed" ? "回测完成" : run.status)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)

                Spacer()

                Text("\(run.startDate) → \(run.endDate)")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }

            if run.status == "completed" {
                metricsGrid
            }

            if let error = run.errorMessage {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PulseColors.danger)
                    Text(error)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger)
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // MARK: - Metrics grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: PulseSpacing.sm) {
            metricCell("总收益率", value: pct(run.totalReturn), color: run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            metricCell("夏普比率", value: fmt(run.sharpeRatio), color: run.sharpeRatio >= 1 ? PulseColors.success : PulseColors.warning)
            metricCell("最大回撤", value: pct(run.maxDrawdown), color: PulseColors.danger)
            metricCell("胜率", value: pct(run.winRate), color: run.winRate >= 0.5 ? PulseColors.success : PulseColors.warning)
            metricCell("盈亏比", value: fmt(run.profitFactor), color: run.profitFactor >= 1 ? PulseColors.success : PulseColors.danger)
            metricCell("总交易", value: "\(run.totalTrades)", color: colors.textPrimary)
            metricCell("初始资金", value: "$\(Int(run.initialCapital))", color: colors.textSecondary)
            metricCell("交易对", value: run.symbols.joined(separator: ","), color: colors.textSecondary)
        }
    }

    private func metricCell(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.background.opacity(0.5))
        )
    }

    private func pct(_ v: Double) -> String { String(format: "%.2f%%", v * 100) }
    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}
