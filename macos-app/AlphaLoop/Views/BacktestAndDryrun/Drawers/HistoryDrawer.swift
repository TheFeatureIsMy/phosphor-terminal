// HistoryDrawer.swift — 历史 run 列表 + compare checkbox

import SwiftUI

struct HistoryDrawer: View {
    @Binding var isPresented: Bool
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors
    @State private var query = ""

    private var filtered: [BacktestRunV2] {
        let list = vm.activeTab == .backtest ? vm.recentBacktests : []
        if query.isEmpty { return list }
        return list.filter { $0.symbols.first?.localizedCaseInsensitiveContains(query) ?? false }
    }

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
                    ForEach(filtered) { run in
                        HStack(spacing: PulseSpacing.sm) {
                            Button {
                                Task { await vm.toggleCompare(runId: run.id) }
                            } label: {
                                Image(systemName: vm.comparedRunIds.contains(run.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(PulseColors.accent)
                            }
                            .buttonStyle(.plain)

                            Button { Task { await vm.selectRun(run) }; isPresented = false } label: {
                                Text("#\(run.id)").font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
                                Text(run.symbols.first ?? "—").font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                                Spacer()
                                Text(String(format: "%+.1f%%", run.totalReturn * 100))
                                    .font(PulseFonts.tabular)
                                    .foregroundStyle(run.totalReturn >= 0 ? PulseColors.accent : PulseColors.danger)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(PulseSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surfaceHover.opacity(0.3)))
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
}
