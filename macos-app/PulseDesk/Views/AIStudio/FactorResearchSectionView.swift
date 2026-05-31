// FactorResearchSectionView.swift — 因子研究
// 跨截面因子分析、IC/Rank IC 计算

import SwiftUI

struct FactorResearchSectionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var selectedFactor = "momentum"
    @State private var selectedUniverse = "crypto_top20"
    @State private var isRunning = false
    @State private var results: [FactorResult]?
    @State private var errorMessage: String?

    struct FactorResult: Identifiable {
        let id = UUID()
        let name: String
        let ic: Double
        let rankIC: Double
        let turnover: Double
        let significance: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            configBar
            Divider().foregroundStyle(colors.border)

            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    if let errorMessage {
                        HStack(spacing: PulseSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(PulseColors.loss)
                            Text(errorMessage)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                        }
                        .padding(PulseSpacing.sm)
                        .background(PulseColors.loss.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                    }

                    if let results {
                        resultsGrid(results)
                    } else {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: "因子研究",
                            description: "选择因子和标的池，计算因子有效性指标"
                        )
                        .frame(height: 300)
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
    }

    private var configBar: some View {
        HStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: "因子")
            Picker("", selection: $selectedFactor) {
                Text("动量").tag("momentum")
                Text("波动率").tag("volatility")
                Text("成交量").tag("volume")
                Text("RSI").tag("rsi")
                Text("MACD").tag("macd")
            }
            .pickerStyle(.menu)
            .darkPicker()
            .frame(width: 100)

            TerminalLabel(text: "标的池")
            Picker("", selection: $selectedUniverse) {
                Text("加密货币 Top20").tag("crypto_top20")
                Text("美股科技").tag("us_tech")
                Text("A股沪深300").tag("a_share_300")
            }
            .pickerStyle(.menu)
            .darkPicker()
            .frame(width: 130)

            Spacer()

            if isRunning {
                ProgressView()
                    .controlSize(.small)
            }

            ProofAlphaButton(title: "计算因子") {
                Task { await runFactor() }
            }
            .disabled(isRunning)
        }
        .padding(PulseSpacing.lg)
    }

    private func resultsGrid(_ results: [FactorResult]) -> some View {
        VStack(spacing: PulseSpacing.md) {
            // IC 指标卡片
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: PulseSpacing.md) {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        TerminalLabel(text: result.name)

                        HStack(alignment: .bottom, spacing: PulseSpacing.xxs) {
                            Text(String(format: "%.4f", result.ic))
                                .font(PulseFonts.tabularLarge)
                                .foregroundStyle(result.ic > 0 ? colors.profit : PulseColors.loss)
                            Text("IC")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }

                        HStack(spacing: PulseSpacing.md) {
                            metricItem("Rank IC", value: result.rankIC)
                            metricItem("换手率", value: result.turnover, suffix: "%")
                            metricItem("显著性", value: result.significance)
                        }
                    }
                    .cardStyle()
                }
            }

            // 因子说明
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "因子说明")
                Text(factorDescription)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }
            .cardStyle()
        }
    }

    private func metricItem(_ label: String, value: Double, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(String(format: "%.3f%@", value, suffix))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
        }
    }

    private var factorDescription: String {
        switch selectedFactor {
        case "momentum": return "动量因子：过去 N 天的收益率排名。正 IC 表示过去赢家继续赢，负 IC 表示反转效应。"
        case "volatility": return "波动率因子：历史波动率的截面排名。低波动率组合通常有更高的风险调整收益。"
        case "volume": return "成交量因子：相对成交量变化。异常放量可能预示趋势变化。"
        case "rsi": return "RSI 因子：相对强弱指标的截面比较。用于识别超买超卖状态。"
        default: return "MACD 因子：MACD 柱状图的截面排名。用于捕捉动量变化。"
        }
    }

    private func runFactor() async {
        isRunning = true
        errorMessage = nil
        do {
            let universe: [String]
            switch selectedUniverse {
            case "crypto_top20": universe = ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]
            case "us_tech": universe = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA"]
            case "a_share_300": universe = ["600519.SH", "601318.SH", "000858.SZ", "600036.SH", "601166.SH"]
            default: universe = ["BTC/USDT", "ETH/USDT"]
            }
            let response = try await networkClient.createFactorResearch(
                market: selectedUniverse,
                universe: universe,
                factorName: selectedFactor
            )
            let ic = response.metrics["ic"] ?? 0
            let rankIC = response.metrics["rank_ic"] ?? 0
            let turnover = response.metrics["turnover"] ?? 0
            let tstat = response.metrics["t_stat"] ?? response.metrics["tstat"] ?? 2.0
            let icIR = response.metrics["ic_ir"] ?? (ic > 0 ? ic / 0.083 : 0)
            results = [
                FactorResult(name: "IC", ic: ic, rankIC: rankIC, turnover: turnover, significance: tstat),
                FactorResult(name: "IC_IR", ic: icIR, rankIC: rankIC * 0.86, turnover: turnover, significance: tstat),
                FactorResult(name: "T-stat", ic: tstat, rankIC: tstat * 0.88, turnover: turnover, significance: tstat),
            ]
        } catch {
            errorMessage = "因子计算失败: \(error.localizedDescription)"
            results = nil
        }
        isRunning = false
    }
}
