// BacktestLabView.swift — 回测实验室主视图（九段装配）
// Nine-section narrative flow: Config → Status → Summary → Curve → TradeList → Compare → Risk → Promotion → DataSource
// Run Rail (left, 240pt) + ScrollView (right, sections)

import SwiftUI

struct BacktestLabView: View {
    @State private var viewModel = BacktestLabViewModel()
    @State private var showingNewRunSheet = false
    @Environment(\.networkClient) private var networkClient
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                runRail
                    .frame(width: 240)
                    .background(Color.black.opacity(0.2))
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                        ConfigPanel(viewModel: viewModel)
                        StatusPanel(viewModel: viewModel)
                        SummaryPanel(viewModel: viewModel)
                        CurvePanel(viewModel: viewModel)
                        TradeListPanel(viewModel: viewModel)
                        ComparePanel(viewModel: viewModel)
                        RiskPanel(viewModel: viewModel)
                        PromotionPanel(viewModel: viewModel)
                        DataSourceFooter(viewModel: viewModel)
                    }
                    .padding(PulseSpacing.lg)
                }
            }
        }
        .sheet(isPresented: $showingNewRunSheet) {
            NewRunSheet(viewModel: viewModel)
        }
        .task {
            viewModel.networkClient = networkClient
            await viewModel.loadAvailableStrategies()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private var header: some View {
        HStack {
            Text(L10n.BacktestLab.title)
                .font(PulseFonts.displaySubheading)
            Spacer(minLength: 12)
            strategyPicker
            if networkClient is MockNetworkClient {
                Text(L10n.BacktestLab.mockBadge)
                    .font(PulseFonts.caption.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Button { showingNewRunSheet = true } label: { Image(systemName: "plus") }
                .disabled(viewModel.phase == .running)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    private var runRail: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.runRail).font(PulseFonts.headline).padding(PulseSpacing.sm)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    ForEach(viewModel.recentBacktests) { run in
                        RunRailRow(run: run, isSelected: viewModel.selectedRun?.id == run.id,
                                   isCompared: viewModel.comparedRunIds.contains(run.id)) {
                            Task { await viewModel.selectRun(run) }
                        } onCompare: {
                            Task { await viewModel.toggleCompare(runId: run.id) }
                        }
                    }
                    if viewModel.recentBacktests.isEmpty {
                        Text(L10n.BacktestLab.runEmpty).foregroundStyle(.secondary).padding()
                    }
                }
            }
        }
    }

    private var strategyPicker: some View {
        Picker(L10n.BacktestLab.strategyPicker, selection: Binding(
            get: { viewModel.selectedStrategy },
            set: { s in if let s { Task { await viewModel.selectStrategy(s) } } }
        )) {
            Text(L10n.BacktestLab.noStrategy).tag(nil as StrategyV2?)
            ForEach(viewModel.availableStrategies) { Text($0.name).tag(Optional($0)) }
        }
    }
}

struct RunRailRow: View {
    let run: BacktestRunV2
    let isSelected: Bool
    let isCompared: Bool
    let onTap: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onTap) {
                    Text("#\(run.id)").font(PulseFonts.body.weight(isSelected ? .bold : .regular))
                }.buttonStyle(.plain)
                Spacer()
                Button(action: onCompare) {
                    Image(systemName: isCompared ? "checkmark.square.fill" : "square")
                }.buttonStyle(.plain)
            }
            Text(String(format: "%.2f%%", run.totalReturn * 100))
                .font(PulseFonts.caption.monospacedDigit())
                .foregroundStyle(run.totalReturn >= 0 ? .green : .red)
            Text(run.startDate + " → " + run.endDate).font(PulseFonts.caption).foregroundStyle(.secondary)
        }
        .padding(PulseSpacing.xs)
        .background(isSelected ? PulseColors.accent.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }
}
