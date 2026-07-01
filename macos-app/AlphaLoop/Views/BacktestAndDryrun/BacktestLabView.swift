// BacktestLabView.swift — Backtest lab, single-column data-terminal layout.

import SwiftUI

struct BacktestLabView: View {
    @State private var viewModel = BacktestLabViewModel()
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors

    @State private var showNewRunDrawer = false
    @State private var showHistoryDrawer = false
    @State private var strategyContextExpanded = false
    @State private var tradeListExpanded = true
    @State private var compareMode = false

    var body: some View {
        VStack(spacing: 0) {
            BacktestTopBar(
                onNewRun: { showNewRunDrawer = true },
                onHistory: { showHistoryDrawer = true },
                onCompare: { compareMode.toggle() }
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                    if vm.phase == .running {
                        LoadingView(type: .detail)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PulseSpacing.xl)
                    } else if let run = vm.currentBacktestRun {
                        EquityCurveHero(run: run, comparedRuns: comparedRuns, compareMode: compareMode)
                            .frame(height: 360)

                        StrategyContextStrip(run: run, isExpanded: $strategyContextExpanded)

                        MetricsGrid(run: run)

                        TradeListTable(trades: run.trades, isExpanded: $tradeListExpanded)
                    } else if let error = vm.errorMessage {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: L10n.zh("加载失败", en: "Load Failed"),
                            description: error,
                            primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.loadInitial() } })
                        )
                        .padding(PulseSpacing.xl)
                    } else {
                        EmptyStateView(
                            icon: "chart.line.uptrend.xyaxis",
                            title: L10n.zh("选择一个运行查看结果", en: "Select a run to view results"),
                            description: L10n.zh("从历史记录选择，或新建一次回测。", en: "Pick from history, or start a new backtest.")
                        )
                        .padding(PulseSpacing.xl)
                    }
                }
                .padding(PulseSpacing.lg)
                .frame(maxWidth: 1280, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(colors.background.ignoresSafeArea())
        .environment(viewModel)
        .task {
            viewModel.networkClient = networkClient
            await vm.loadInitial()
        }
        .onDisappear { vm.onDisappear() }
    }

    private var comparedRuns: [BacktestRunV2] {
        vm.recentBacktests.filter { vm.comparedRunIds.contains($0.id) }
    }

    private var vm: BacktestLabViewModel { viewModel }
}

// 临时占位 — Task 2-4 替换
struct EquityCurveHero: View {
    let run: BacktestRunV2
    let comparedRuns: [BacktestRunV2]
    let compareMode: Bool
    var body: some View { EmptyView() }
}
struct StrategyContextStrip: View {
    let run: BacktestRunV2
    @Binding var isExpanded: Bool
    var body: some View { EmptyView() }
}
struct MetricsGrid: View {
    let run: BacktestRunV2
    var body: some View { EmptyView() }
}
struct TradeListTable: View {
    let trades: [TradeRow]
    @Binding var isExpanded: Bool
    var body: some View { EmptyView() }
}
