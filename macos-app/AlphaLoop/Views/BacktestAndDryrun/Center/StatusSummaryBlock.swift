// StatusSummaryBlock.swift — Status + summary metrics (with vs-last delta).

import SwiftUI

struct StatusSummaryBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionSummary, dataNote: dataNote) {
            HStack(spacing: PulseSpacing.md) {
                statusCard
                summaryCard
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun else { return "" }
        return "\(run.totalTrades) trades"
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Circle()
                    .fill(vm.phase == .failed ? PulseColors.danger : PulseColors.success)
                    .frame(width: 8, height: 8)
                Text(vm.phase == .failed
                     ? L10n.BacktestLab.statusFailed
                     : L10n.BacktestLab.statusCompleted)
                    .font(PulseFonts.caption.weight(.semibold))
            }
            if vm.phase == .failed, let err = vm.errorMessage {
                Text(err).font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        HStack(spacing: PulseSpacing.lg) {
            metric(L10n.BacktestLab.kpiReturn,
                   value: runValue(\.totalReturn),
                   isPercent: true,
                   signPrefix: true)
            metric(L10n.BacktestLab.kpiMaxDD,
                   value: runValue(\.maxDrawdown),
                   isPercent: true)
            metric(L10n.BacktestLab.kpiWinRate,
                   value: runValue(\.winRate),
                   isPercent: true)
            metric(L10n.BacktestLab.kpiProfitFactor,
                   value: runValue(\.profitFactor),
                   isPercent: false)
        }
    }

    private func runValue(_ keyPath: KeyPath<BacktestRunV2, Double>) -> Double {
        vm.currentBacktestRun?[keyPath: keyPath] ?? 0
    }

    private func metric(_ label: String, value: Double, isPercent: Bool, signPrefix: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
            if isPercent {
                let displayVal = value * 100
                Text(signPrefix
                     ? String(format: "%+.2f%%", displayVal)
                     : String(format: "%.2f%%", displayVal))
                    .font(PulseFonts.body.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
            } else {
                Text(String(format: "%.2f", value))
                    .font(PulseFonts.body.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
            }
        }
    }
}
