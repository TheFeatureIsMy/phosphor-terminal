// BacktestTopBar.swift — 48pt 顶 bar：run 切换 + segmented + New Run + Compare

import SwiftUI

struct BacktestTopBar: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors
    let onNewRun: () -> Void
    let onHistory: () -> Void
    let onCompare: () -> Void

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            RunSwitcher(onTap: onHistory)

            segmentedControl

            Spacer()

            Button(action: onNewRun) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text(L10n.BacktestLab.RunRail.newRun)
                        .font(PulseFonts.captionMedium)
                }
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, 6)
                .background(PulseColors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
            }
            .buttonStyle(.plain)

            if vm.comparedRunIds.count >= 2 {
                Button(action: onCompare) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.merge").font(.system(size: 11))
                        Text(L10n.BacktestLab.compare)
                        Text("\(vm.comparedRunIds.count)")
                            .font(PulseFonts.micro)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(colors.textMuted.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .font(PulseFonts.captionMedium)
                    .padding(.horizontal, PulseSpacing.md)
                    .padding(.vertical, 6)
                    .background(colors.surfaceHover.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                    .foregroundStyle(colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 48)
        .background(colors.background)
        .overlay(alignment: .bottom) { Rectangle().fill(colors.border).frame(height: 1) }
    }

    private var segmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(RunTab.allCases) { tab in
                Button { vm.switchTab(tab) } label: {
                    Text(tab == .backtest ? L10n.BacktestLab.backtestTab : L10n.BacktestLab.dryrunTab)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(vm.activeTab == tab ? colors.textPrimary : colors.textSecondary)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(vm.activeTab == tab ? PulseColors.accent.opacity(0.18) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
    }
}
