// StrategyMetaPanel.swift — Strategy name, type, DSL hash, mode, engine, exec time.

import SwiftUI

struct StrategyMetaPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.Context.strategyMeta).font(PulseFonts.caption.weight(.semibold))
            if let s = vm.selectedStrategy {
                metaRow(L10n.BacktestLab.Context.strategy, value: s.name)
                metaRow(L10n.BacktestLab.Context.strategyType, value: s.strategyType)
                if let run = vm.currentBacktestRun, let hash = run.dslHash {
                    metaRow(L10n.BacktestLab.Context.dslHash, value: String(hash.prefix(8)))
                }
                metaRow(L10n.BacktestLab.Context.mode, value: vm.activeTab == .backtest
                    ? L10n.BacktestLab.backtestTab : L10n.BacktestLab.dryrunTab)
            }
            if let run = vm.currentBacktestRun {
                metaRow(L10n.BacktestLab.Context.engine, value: "Freqtrade")
                if let completed = run.completedAt {
                    metaRow(L10n.BacktestLab.Context.execTime, value: completed)
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.surfaceHover.opacity(0.35), in: RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
            Spacer()
            Text(value).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
        }
    }
}
