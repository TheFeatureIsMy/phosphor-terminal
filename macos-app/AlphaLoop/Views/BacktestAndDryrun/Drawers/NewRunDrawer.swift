// NewRunDrawer.swift — 配置抽屉：symbol + timeframe + 策略 + Run 按钮

import SwiftUI

struct NewRunDrawer: View {
    @Binding var isPresented: Bool
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors
    @State private var symbol = "BTC/USDT"
    @State private var timeframe = "1h"
    @State private var strategyId: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            HStack {
                Text(L10n.zh("新建运行", en: "New Run"))
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                        .padding(7)
                        .background(colors.surfaceHover.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(colors.border, lineWidth: 1))
                        .foregroundStyle(colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(L10n.zh("交易对", en: "Symbol")).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                TextField("BTC/USDT", text: $symbol)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.tabular)
                    .padding(PulseSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(L10n.zh("周期", en: "Timeframe")).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                HStack(spacing: 2) {
                    ForEach(["5m", "15m", "1h", "4h"], id: \.self) { tf in
                        Button { timeframe = tf } label: {
                            Text(tf).font(PulseFonts.monoLabel)
                                .foregroundStyle(timeframe == tf ? colors.textPrimary : colors.textSecondary)
                                .padding(.horizontal, PulseSpacing.sm).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 5).fill(timeframe == tf ? PulseColors.accent.opacity(0.18) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
            }

            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(L10n.zh("策略 ID", en: "Strategy ID")).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                TextField("1", value: $strategyId, format: .number)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.tabular)
                    .padding(PulseSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
            }

            Spacer()

            Button {
                vm.newRun()
                isPresented = false
            } label: {
                Text(vm.activeTab == .backtest ? L10n.BacktestLab.backtestTab : L10n.BacktestLab.dryrunTab)
                    .font(PulseFonts.captionMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(PulseColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.lg)
    }
}
