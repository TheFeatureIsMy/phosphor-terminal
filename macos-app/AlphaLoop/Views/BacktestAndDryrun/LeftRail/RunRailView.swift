// RunRailView.swift — Left rail: run history + compare selection + new run.

import SwiftUI

struct RunRailView: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 0) {
            newRunButton
            Divider().background(colors.border)
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    if vm.activeTab == .backtest {
                        backtestList
                    } else {
                        dryrunList
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
    }

    // MARK: - New Run button

    private var newRunButton: some View {
        Button {
            vm.newRun()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text(L10n.BacktestLab.RunRail.newRun)
            }
            .font(PulseFonts.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .padding(PulseSpacing.md)
    }

    // MARK: - Backtest list

    private var backtestList: some View {
        ForEach(vm.recentBacktests) { run in
            runRow(run)
        }
    }

    private func runRow(_ run: BacktestRunV2) -> some View {
        let isSelected = vm.selectedRun?.id == run.id
        let isCompared = vm.comparedRunIds.contains(run.id)
        return HStack(spacing: 8) {
            Image(systemName: isCompared ? "checkmark.square.fill" : "square")
                .foregroundStyle(isCompared ? PulseColors.accent : colors.textMuted)
                .onTapGesture {
                    Task { await vm.toggleCompare(runId: run.id) }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(run.id)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                Text(String(format: "%+.1f%%", run.totalReturn * 100))
                    .font(PulseFonts.caption)
                    .foregroundStyle(run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            }
            Spacer()
            if isSelected {
                Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(isSelected ? colors.surface.opacity(0.5) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await vm.selectRun(run) }
        }
    }

    // MARK: - Dryrun list

    private var dryrunList: some View {
        ForEach(vm.dryrunRuns) { run in
            dryrunRow(run)
        }
    }

    private func dryrunRow(_ run: DryRunRunV2) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dryrunStatusColor(run.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(run.id)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                Text("\(run.openTrades) open · \(String(format: "%+.2f", run.totalProfit))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textSecondary)
            }
            Spacer()
            if run.status == "running" {
                Button(L10n.BacktestLab.RunRail.stop) {
                    Task { await vm.stopDryrun(id: run.id) }
                }
                .font(PulseFonts.micro)
                .foregroundStyle(PulseColors.danger)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private func dryrunStatusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.success
        case "failed": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}
