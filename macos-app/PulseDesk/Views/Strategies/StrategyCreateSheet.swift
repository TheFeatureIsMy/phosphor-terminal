// StrategyCreateSheet.swift — 新建策略弹窗（自定义暗黑表单）

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
            // 标题栏
            HStack {
                TerminalLabel(text: "新建策略")
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }

            // 表单
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                // 策略名称
                nameField

                // 策略类型 — 自定义卡片选择器
                typeSelector

                // 交易市场 — 自定义卡片选择器
                marketSelector

                Text(selectedMarket.constraintNote)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.top, PulseSpacing.xxs)

                // 交易所 — 自定义下拉按钮组
                exchangeSelector
            }

            Spacer().frame(height: PulseSpacing.md)

            // 按钮
            HStack {
                ProofAlphaButton(title: "取消", action: { dismiss() }, style: .ghost)
                Spacer()
                ProofAlphaButton(title: "创建策略") {
                    Task {
                        await viewModel.create(name: name, market: selectedMarket.rawValue, exchange: selectedExchange.rawValue)
                        dismiss()
                    }
                }
                .opacity(name.isEmpty ? 0.5 : 1.0)
                .disabled(name.isEmpty)
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: 480)
    }

    // MARK: - 策略名称
    private var nameField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            TerminalLabel(text: "策略名称")
            TextField("输入策略名称", text: $name)
                .textFieldStyle(.plain)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(!name.isEmpty ? PulseColors.accent.opacity(0.3) : colors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - 策略类型选择器（自定义按钮组）
    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: "策略类型")

            VStack(spacing: PulseSpacing.xxs) {
                ForEach(StrategyType.allCases) { type in
                    typeOptionRow(type)
                }
            }
        }
    }

    private func typeOptionRow(_ type: StrategyType) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedType = type }
        } label: {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: iconForStrategy(type))
                    .font(.system(size: 14))
                    .foregroundStyle(selectedType == type ? type.color : colors.textMuted)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.label)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(selectedType == type ? colors.textPrimary : colors.textSecondary)
                    Text(descriptionForStrategy(type))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                if selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(type.color)
                } else {
                    Circle()
                        .stroke(colors.border, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(selectedType == type ? type.color.opacity(0.06) : colors.surface.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(selectedType == type ? type.color.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 交易市场选择器（自定义按钮组）
    private var marketSelector: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: "交易市场")

            HStack(spacing: PulseSpacing.xxs) {
                ForEach(MarketType.allCases) { market in
                    marketPill(market)
                }
            }
        }
    }

    private func marketPill(_ market: MarketType) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedMarket = market }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: market.icon)
                    .font(.system(size: 10))
                Text(market.label)
                    .font(PulseFonts.captionMedium)
            }
            .foregroundStyle(selectedMarket == market ? colors.background : colors.textSecondary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(selectedMarket == market ? PulseColors.accent : colors.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.96)
    }

    // MARK: - 交易所选择器
    private var exchangeSelector: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: "交易所")

            HStack(spacing: PulseSpacing.xxs) {
                ForEach(availableExchanges) { exchange in
                    exchangePill(exchange)
                }
            }
        }
    }

    private func exchangePill(_ exchange: Exchange) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedExchange = exchange }
        } label: {
            Text(exchange.label)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(selectedExchange == exchange ? colors.background : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(selectedExchange == exchange ? PulseColors.accent : colors.surface)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.96)
    }

    // MARK: - Available exchanges by market
    private var availableExchanges: [Exchange] {
        switch selectedMarket {
        case .crypto: return [.binance, .okx, .bybit, .gate]
        case .usStock: return [.alpaca, .ibkr]
        case .aShare: return [.joinquant, .eastmoney]
        }
    }

    // MARK: - Helpers
    private func iconForStrategy(_ type: StrategyType) -> String {
        switch type {
        case .maCross: return "arrow.left.arrow.right"
        case .breakout: return "arrow.up.right"
        case .grid: return "square.grid.3x3"
        case .meanReversion: return "arrow.triangle.branch"
        case .ragGenerated: return "brain.head.profile"
        }
    }

    private func descriptionForStrategy(_ type: StrategyType) -> String {
        switch type {
        case .maCross: return "均线金叉/死叉信号"
        case .breakout: return "价格突破关键阻力/支撑位"
        case .grid: return "区间震荡网格买卖"
        case .meanReversion: return "价格偏离均值后回归"
        case .ragGenerated: return "AI 知识库生成策略"
        }
    }
}
