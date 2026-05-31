// BacktestConfigView.swift — 回测配置面板
// 策略选择器 + 日期范围 + 初始资金 + 交易对选择 + 运行按钮

import SwiftUI

struct BacktestConfigView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: BacktestViewModel
    let strategies: [Strategy]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("回测配置")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            // 策略选择
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                HStack(spacing: PulseSpacing.xs) {
                    Text("策略")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    if let selectedId = viewModel.selectedStrategyId,
                       let selected = strategies.first(where: { $0.id == selectedId }) {
                        Text(selected.name)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.accent)
                    }
                }
                Picker("", selection: $viewModel.selectedStrategyId) {
                    Text("选择策略").tag(nil as Int?)
                    ForEach(strategies) { strategy in
                        Text(strategy.name).tag(strategy.id as Int?)
                    }
                }
                .pickerStyle(.menu)
                .darkPicker()
            }

            // 日期 + 资金
            HStack(spacing: PulseSpacing.md) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("开始日期")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    TextField("2025-01-01", text: $viewModel.startDate)
                        .darkTextField()
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("结束日期")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    TextField("2025-12-31", text: $viewModel.endDate)
                        .darkTextField()
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("初始资金 ($)")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    TextField("10000", value: $viewModel.initialCapital, format: .number)
                        .darkTextField()
                }
            }

            // 交易对选择
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text("交易对")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textSecondary)
                HStack(spacing: PulseSpacing.xs) {
                    ForEach(MockData.symbols, id: \.self) { symbol in
                        let isSelected = viewModel.selectedSymbols.contains(symbol)
                        Button {
                            if isSelected {
                                viewModel.selectedSymbols.remove(symbol)
                            } else {
                                viewModel.selectedSymbols.insert(symbol)
                            }
                        } label: {
                            Text(symbol)
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(isSelected ? colors.textPrimary : colors.textSecondary)
                                .padding(.horizontal, PulseSpacing.xs)
                                .padding(.vertical, PulseSpacing.xxs)
                                .background(
                                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                                        .fill(isSelected ? PulseColors.accent : colors.surfaceHover)
                                )
                        }
                        .buttonStyle(.plain)
                        .pressEffect(scale: 0.92)
                    }
                }
            }

            // 运行按钮
            HStack {
                Spacer()
                ProofAlphaButton(title: "运行回测") {
                    Task { await viewModel.run() }
                }
                .opacity(!viewModel.canRun || viewModel.isRunning ? 0.5 : 1.0)
                .disabled(!viewModel.canRun || viewModel.isRunning)
            }
        }
        .cardStyle()
    }
}
