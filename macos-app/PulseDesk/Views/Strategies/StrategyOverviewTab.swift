// StrategyOverviewTab.swift — 策略概览标签
// 信息行 + 指标网格 + 参数列表

import SwiftUI

struct StrategyOverviewTab: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                // 基本信息
                infoSection

                // 指标
                if strategy.sharpeRatio != nil || strategy.maxDrawdown != nil {
                    metricsSection
                }

                // 参数
                parametersSection
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("基本信息")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            GlassCard(cardPadding: PulseSpacing.xs) {
                VStack(spacing: 1) {
                    infoRow("策略 ID", value: "\(strategy.id)")
                    infoRow("标签", value: strategy.tags.isEmpty ? "—" : strategy.tags.joined(separator: ", "))
                    infoRow("状态", value: strategy.status.label)
                    infoRow("市场", value: strategy.market)
                    infoRow("交易所", value: strategy.exchange)
                    infoRow("版本", value: "v\(strategy.version)")
                    infoRow("来源", value: strategy.source.rawValue)
                }
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("绩效指标")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            HStack(spacing: PulseSpacing.md) {
                if let sharpe = strategy.sharpeRatio {
                    metricCard("夏普比率", value: String(format: "%.2f", sharpe), color: PulseColors.accent)
                }
                if let dd = strategy.maxDrawdown {
                    metricCard("最大回撤", value: String(format: "%.1f%%", dd), color: PulseColors.loss)
                }
            }
        }
    }

    private func metricCard(_ label: String, value: String, color: Color) -> some View {
        GlassCard {
            VStack(spacing: PulseSpacing.xs) {
                Text(label)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                Text(value)
                    .font(PulseFonts.tabularLarge)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("策略参数")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            GlassCard(cardPadding: PulseSpacing.xs) {
                VStack(spacing: 1) {
                    ForEach(Array(strategy.parameters.keys.sorted()), id: \.self) { key in
                        if let anyVal = strategy.parameters[key] {
                            infoRow(key, value: "\(anyVal.value)")
                        }
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text(value)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }
}
