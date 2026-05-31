// BacktestConfigView.swift — 回测配置面板
// 策略选择器 + 日期范围 + 初始资金 + 交易对选择 + 运行按钮

import SwiftUI

struct BacktestConfigView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: BacktestViewModel
    let strategies: [Strategy]

    private var selectedStrategy: Strategy? {
        strategies.first { $0.id == viewModel.selectedStrategyId }
    }

    private var selectedStrategyName: String {
        selectedStrategy?.name ?? "选择策略..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("回测配置")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            // 策略选择 — 自定义下拉
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                TerminalLabel(text: "选择策略")

                Menu {
                    ForEach(strategies) { strategy in
                        Button {
                            viewModel.selectedStrategyId = strategy.id
                        } label: {
                            HStack {
                                Text(strategy.name)
                                if viewModel.selectedStrategyId == strategy.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseColors.accent)
                        Text(selectedStrategyName)
                            .font(PulseFonts.body)
                            .foregroundStyle(selectedStrategy != nil ? colors.textPrimary : colors.textMuted)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.horizontal, PulseSpacing.sm)
                    .padding(.vertical, PulseSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
            }

            // 日期 + 资金
            HStack(spacing: PulseSpacing.md) {
                dateField("开始日期", icon: "calendar", text: $viewModel.startDate)
                dateField("结束日期", icon: "calendar.badge.plus", text: $viewModel.endDate)

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("初始资金")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    HStack(spacing: PulseSpacing.xs) {
                        Image(systemName: "dollarsign")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.textMuted)
                        TextField("10000", value: $viewModel.initialCapital, format: .number)
                            .textFieldStyle(.plain)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textPrimary)
                    }
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
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

    // MARK: - Styled date field

    private func dateField(_ label: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(colors.textMuted)
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
            }
            .padding(.horizontal, PulseSpacing.xs)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
        }
    }
}
