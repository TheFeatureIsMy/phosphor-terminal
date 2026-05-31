// BacktestConfigView.swift — 回测配置面板
// 策略选择器 + 日期范围 + 初始资金 + 交易对选择 + 运行按钮

import SwiftUI

struct BacktestConfigView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: BacktestViewModel
    let strategies: [Strategy]

    @State private var showStrategyPicker = false
    @State private var strategySearchText = ""

    private var selectedStrategy: Strategy? {
        strategies.first { $0.id == viewModel.selectedStrategyId }
    }

    private var selectedStrategyName: String {
        selectedStrategy?.name ?? "选择策略..."
    }

    private var filteredStrategyList: [Strategy] {
        if strategySearchText.isEmpty { return strategies }
        return strategies.filter { $0.name.localizedCaseInsensitiveContains(strategySearchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("回测配置")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            // 策略选择 — 自定义 Popover 下拉
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                TerminalLabel(text: "选择策略")

                Button {
                    showStrategyPicker.toggle()
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseColors.accent)
                        Text(selectedStrategyName)
                            .font(PulseFonts.body)
                            .foregroundStyle(selectedStrategy != nil ? colors.textPrimary : colors.textMuted)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.horizontal, PulseSpacing.sm)
                    .padding(.vertical, PulseSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(
                        showStrategyPicker ? PulseColors.accent.opacity(0.3) : colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showStrategyPicker, arrowEdge: .bottom) {
                    VStack(spacing: 0) {
                        // Search field
                        HStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(colors.textMuted)
                            TextField("搜索策略...", text: $strategySearchText)
                                .textFieldStyle(.plain).font(PulseFonts.caption)
                        }
                        .padding(PulseSpacing.xs)
                        .background(colors.surfaceElevated)

                        Divider().foregroundStyle(colors.border)

                        // Strategy list
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(filteredStrategyList) { strategy in
                                    Button {
                                        viewModel.selectedStrategyId = strategy.id
                                        showStrategyPicker = false
                                    } label: {
                                        HStack(spacing: PulseSpacing.sm) {
                                            Image(systemName: "chart.line.uptrend.xyaxis")
                                                .font(.system(size: 12))
                                                .foregroundStyle(PulseColors.accent)
                                                .frame(width: 18)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(strategy.name).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
                                                HStack(spacing: PulseSpacing.xxs) {
                                                    if let firstTag = strategy.tags.first {
                                                        Text(firstTag).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                                                        Text("\u{00B7}").foregroundStyle(colors.textMuted)
                                                    }
                                                    Text(strategy.status.label).font(PulseFonts.micro).foregroundStyle(strategy.status.color(colors))
                                                }
                                            }
                                            Spacer()
                                            if viewModel.selectedStrategyId == strategy.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 13)).foregroundStyle(PulseColors.accent)
                                            }
                                        }
                                        .padding(.horizontal, PulseSpacing.sm).padding(.vertical, PulseSpacing.xs)
                                        .background(viewModel.selectedStrategyId == strategy.id ? PulseColors.accent.opacity(0.06) : Color.clear)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    .frame(width: 300)
                    .background(colors.cardBackground)
                }
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
