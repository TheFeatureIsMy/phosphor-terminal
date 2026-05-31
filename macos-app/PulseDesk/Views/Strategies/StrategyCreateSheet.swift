// StrategyCreateSheet.swift — 新建策略弹窗

import SwiftUI

struct StrategyCreateSheet: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: StrategiesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: StrategyType = .maCross
    @State private var selectedExchange: Exchange = .binance
    @State private var selectedMarket: MarketType = .crypto

    var body: some View {
        VStack(spacing: PulseSpacing.lg) {
            // 标题
            HStack {
                Text("新建策略")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }

            // 表单
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // 策略名称
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("策略名称")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    TextField("输入策略名称", text: $name)
                        .darkTextField()
                }

                // 策略类型
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("策略类型")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    Picker("", selection: $selectedType) {
                        ForEach(StrategyType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 交易市场
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("交易市场")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    Picker("", selection: $selectedMarket) {
                        ForEach(MarketType.allCases) { market in
                            Label(market.label, systemImage: market.icon)
                                .tag(market)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(selectedMarket.constraintNote)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                // 交易所
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("交易所")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    Picker("", selection: $selectedExchange) {
                        ForEach(Exchange.allCases) { exchange in
                            Text(exchange.label).tag(exchange)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // 按钮
            HStack {
                ProofAlphaButton(title: "取消", action: { dismiss() }, style: .ghost)

                Spacer()

                ProofAlphaButton(title: "创建") {
                    Task {
                        await viewModel.create(name: name, type: selectedType, market: selectedMarket.rawValue, exchange: selectedExchange.rawValue)
                        dismiss()
                    }
                }
                .opacity(name.isEmpty ? 0.5 : 1.0)
                .disabled(name.isEmpty)
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: 420)
    }
}
