// BacktestLabView.swift — Three-column linked-flow backtest/dryrun lab.
//
// Left rail (240pt): RunRailView — run history + compare + new run.
// Center (flexible): tab bar + scrollable section cards (filled in Tasks 9-11).
// Right rail (280pt): ContextRailView — context inspector (filled in Task 10).

import SwiftUI

struct BacktestLabView: View {
    @State private var viewModel = BacktestLabViewModel()
    @State private var showingNewRunSheet = false
    @Environment(\.networkClient) private var networkClient
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RunRailView()
                .frame(width: 240)
                .background(colors.surface.opacity(0.3))

            centerColumn
                .frame(maxWidth: .infinity)

            ContextRailView()
                .frame(width: 280)
                .background(colors.surface.opacity(0.3))
        }
        .background(colors.background.ignoresSafeArea())
        .sheet(isPresented: $showingNewRunSheet) {
            NewRunSheet(viewModel: viewModel)
        }
        .task {
            viewModel.networkClient = networkClient
            await viewModel.loadInitial()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Center column

    private var centerColumn: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    SectionCard(title: L10n.BacktestLab.sectionConfig, locked: false) {
                        Text("Config Panel — Task 9")
                            .foregroundStyle(colors.textSecondary)
                    }
                    if vm.phase == .completed || vm.phase == .failed {
                        SectionCard(title: L10n.BacktestLab.sectionStatus, locked: false) {
                            Text("Status Summary — Task 9")
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                    if vm.phase == .completed {
                        SectionCard(title: L10n.BacktestLab.sectionCurve, locked: false) {
                            Text("Equity Curve — Task 9")
                                .foregroundStyle(colors.textSecondary)
                        }
                        SectionCard(title: L10n.BacktestLab.sectionTradeList, locked: false) {
                            Text("Trade List — Task 9")
                                .foregroundStyle(colors.textSecondary)
                        }
                        if vm.comparedRunIds.count >= 2 {
                            SectionCard(title: L10n.BacktestLab.sectionCompare, locked: false) {
                                Text("Compare — Task 9")
                                    .foregroundStyle(colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(RunTab.allCases) { tab in
                let isActive = vm.activeTab == tab
                Button {
                    vm.switchTab(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .backtest ? "clock.arrow.circlepath" : "play.circle")
                        Text(tab == .backtest ? L10n.BacktestLab.backtestTab : L10n.BacktestLab.dryrunTab)
                    }
                    .font(PulseFonts.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? PulseColors.accent : colors.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    private var vm: BacktestLabViewModel { viewModel }
}
