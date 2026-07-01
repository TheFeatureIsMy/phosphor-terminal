// HistoryDrawer.swift — 历史 run 列表 + compare checkbox

import SwiftUI

struct HistoryDrawer: View {
    @Binding var isPresented: Bool
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                Text(L10n.BacktestLab.historyDrawerTitle)
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

            TextField(L10n.zh("搜索交易对", en: "Search symbol"), text: $query)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))

            ScrollView {
                VStack(spacing: PulseSpacing.xs) {
                    if vm.activeTab == .backtest {
                        ForEach(vm.recentBacktests.filter { query.isEmpty || ($0.symbols.first?.localizedCaseInsensitiveContains(query) ?? false) }) { run in
                            backtestRow(run)
                        }
                    } else {
                        ForEach(vm.dryrunRuns.filter { query.isEmpty || ($0.symbols.first?.localizedCaseInsensitiveContains(query) ?? false) }) { run in
                            dryrunRow(run)
                        }
                    }
                }
            }

            HStack {
                Text(L10n.zh("点击勾选对比，点击行切换", en: "Tap checkbox to compare, tap row to focus"))
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Spacer()
            }
        }
        .padding(PulseSpacing.lg)
    }

    private func backtestRow(_ run: BacktestRunV2) -> some View {
        Button { Task { await vm.selectRun(run) }; isPresented = false } label: {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: vm.comparedRunIds.contains(run.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(PulseColors.accent)
                Text("#\(run.id)").font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
                Text(run.symbols.first ?? "—").font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                Spacer()
                Text(String(format: "%+.1f%%", run.totalReturn * 100))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(run.totalReturn >= 0 ? PulseColors.accent : PulseColors.danger)
            }
            .padding(PulseSpacing.sm)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surfaceHover.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { Task { await vm.toggleCompare(runId: run.id) } })
    }

    private func dryrunRow(_ run: DryRunRunV2) -> some View {
        Button { Task { await vm.selectDryrunRun(run) }; isPresented = false } label: {
            HStack(spacing: PulseSpacing.sm) {
                Circle().fill(run.status == "running" ? PulseColors.accent : colors.textMuted).frame(width: 8, height: 8)
                Text("#\(run.id)").font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
                Text(run.symbols.first ?? "—").font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                Spacer()
                Text(run.status.uppercased())
                    .font(PulseFonts.micro)
                    .foregroundStyle(run.status == "running" ? PulseColors.accent : colors.textMuted)
            }
            .padding(PulseSpacing.sm)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surfaceHover.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
