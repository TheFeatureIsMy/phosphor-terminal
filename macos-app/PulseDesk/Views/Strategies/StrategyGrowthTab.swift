// StrategyGrowthTab.swift — 策略增长分析
// SHAP 特征重要性 + 策略订单性能

import SwiftUI

struct StrategyGrowthTab: View {
    @Environment(PulseColors.self) private var colors
    let strategyId: String
    let client: NetworkClientProtocol

    @State private var isLoading = true
    @State private var shapFeatures: [(name: String, importance: Double)] = []
    @State private var performanceMetrics: [(label: String, value: String, color: Color)] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    performanceSection
                    shapSection
                }
                .padding(PulseSpacing.lg)
            }
        }
        .task { await loadGrowthData() }
    }

    // MARK: - Performance Overview

    private var performanceSection: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "策略性能")

                HStack(spacing: PulseSpacing.md) {
                    ForEach(Array(performanceMetrics.enumerated()), id: \.offset) { _, metric in
                        VStack(spacing: PulseSpacing.xxs) {
                            Text(metric.value)
                                .font(PulseFonts.tabular)
                                .foregroundStyle(metric.color)
                            Text(metric.label)
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - SHAP Feature Importance

    private var shapSection: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "SHAP 特征重要性")

                if shapFeatures.isEmpty {
                    Text("暂无 SHAP 分析数据")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                } else {
                    let maxVal = shapFeatures.map(\.importance).max() ?? 1.0
                    ForEach(Array(shapFeatures.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: PulseSpacing.sm) {
                            Text(feature.name)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(index))
                                    .frame(
                                        width: geo.size.width * (feature.importance / maxVal),
                                        height: 12
                                    )
                            }
                            .frame(height: 12)

                            Text(String(format: "%.3f", feature.importance))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textSecondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private func barColor(_ index: Int) -> Color {
        let barColors: [Color] = [PulseColors.accent, PulseColors.cyan, PulseColors.purple, PulseColors.amber, PulseColors.info]
        return barColors[index % barColors.count]
    }

    private func loadGrowthData() async {
        isLoading = true
        defer { isLoading = false }

        let attrAPI = APIAttribution(client: client)

        // 从 Attribution API 获取 SHAP 特征重要性
        if let response = try? await attrAPI.getFeatureImportance(
            features: ["RSI_14", "MACD_signal", "Volume_24h", "BollingerBand", "EMA_cross", "ATR_14"],
            values: [55, 0.002, 1500000, 70000, 1, 800]
        ) {
            shapFeatures = zip(response.features, response.importances).map { ($0, $1) }
        }

        // 从回测结果获取性能指标
        let strategiesAPI = APIStrategiesV2(client: client)
        if let backtests = try? await strategiesAPI.listBacktests(strategyId: Int(strategyId), limit: 1),
           let latest = backtests.first {
            performanceMetrics = [
                ("胜率", String(format: "%.1f%%", latest.winRate), PulseColors.success),
                ("盈亏比", String(format: "%.2f", latest.profitFactor), PulseColors.accent),
                ("Sharpe", String(format: "%.2f", latest.sharpeRatio), PulseColors.cyan),
                ("最大回撤", String(format: "%.1f%%", latest.maxDrawdown), PulseColors.warning),
                ("总收益", String(format: "%+.1f%%", latest.totalReturn), latest.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            ]
        } else {
            performanceMetrics = [
                ("胜率", "—", colors.textMuted),
                ("盈亏比", "—", colors.textMuted),
                ("Sharpe", "—", colors.textMuted),
                ("最大回撤", "—", colors.textMuted),
                ("总收益", "—", colors.textMuted)
            ]
        }
    }
}
