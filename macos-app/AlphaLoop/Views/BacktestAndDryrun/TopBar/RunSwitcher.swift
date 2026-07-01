// RunSwitcher.swift — 顶 bar 左侧 run 切换器按钮

import SwiftUI

struct RunSwitcher: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors
    let onTap: () -> Void

    private var title: String {
        if vm.activeTab == .backtest, let run = vm.currentBacktestRun {
            let sym = run.symbols.first ?? "—"
            return String(format: L10n.BacktestLab.runSwitcherTitle, run.id, sym, run.startDate)
        }
        return L10n.zh("选择运行", en: "Select run")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(colors.textSecondary)
                Text(title)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(colors.surfaceHover.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
