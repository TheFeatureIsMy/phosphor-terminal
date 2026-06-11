// StrategyWorkspaceConsoleView.swift — 策略工作台
// 单页融合：Console 模式（聚合卡片）⇄ Canvas 模式（DSL 编辑器）
// Sidebar 已提供跨页面导航，本视图内部不再保留 TrackList 列。
// 策略切换通过 Header 下拉；右侧 Inspector 默认折叠为 36px 边栏。

import SwiftUI

struct StrategyWorkspaceConsoleView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Environment(\.networkClient) private var networkClient

    @State private var viewModel: StrategyWorkspaceViewModel?
    @State private var canvasVM: CanvasWebViewModel?
    @State private var showNewDraftSheet = false
    @State private var newDraftName: String = ""

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .id(settingsState.language)
        .task {
            if viewModel == nil {
                let vm = StrategyWorkspaceViewModel(client: networkClient)
                viewModel = vm
                await vm.loadList()
            }
        }
        .sheet(isPresented: $showNewDraftSheet) { newDraftSheet }
    }

    // MARK: - Root

    private func content(vm: StrategyWorkspaceViewModel) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                WorkspaceHeader(
                    vm: vm,
                    onSwitcherTap: { vm.switcherOpen.toggle() },
                    onNewDraft: { showNewDraftSheet = true },
                    onModeChange: { newMode in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            vm.mode = newMode
                        }
                        if newMode == .canvas {
                            ensureCanvasLoaded(vm: vm)
                        }
                    },
                    onValidate: { /* TODO hook */ },
                    onBacktest: { /* TODO hook */ },
                    onDryrun: { /* TODO hook */ },
                    onTransition: { t in Task { await vm.performTransition(t) } }
                )

                Divider().overlay(colors.border)

                ZStack {
                    if vm.selectedStrategy == nil {
                        emptyState
                    } else {
                        switch vm.mode {
                        case .console:
                            consoleMode(vm: vm)
                        case .canvas:
                            canvasMode(vm: vm)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Strategy switcher popover overlay
            if vm.switcherOpen {
                switcherOverlay(vm: vm)
            }

            // Inspector slide-in overlay
            if vm.mode == .console, let tab = vm.inspectorTab {
                inspectorOverlay(vm: vm, tab: tab)
            }
        }
    }

    // MARK: - Console mode

    private func consoleMode(vm: StrategyWorkspaceViewModel) -> some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LifecycleRailV2(currentStatus: vm.selectedStrategy?.status ?? "draft")
                    ConsoleKpiStrip(snapshot: vm.snapshot)
                        .padding(.top, 6)
                    sectionGrid(vm: vm)
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { syncingPill(vm: vm) }

            InspectorRail(
                activeTab: vm.inspectorTab,
                onTap: { tab in
                    if vm.inspectorTab == tab { vm.inspectorTab = nil }
                    else { vm.inspectorTab = tab }
                }
            )
        }
    }

    // MARK: - Canvas mode

    private func canvasMode(vm: StrategyWorkspaceViewModel) -> some View {
        ZStack {
            colors.background

            if let canvasVM {
                CanvasWebView(viewModel: canvasVM)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .progressViewStyle(.circular)
            }

            // Save/validate rail floating at top
            if let canvasVM {
                VStack {
                    CanvasActionRail(
                        vm: canvasVM,
                        versionLabel: versionLabel(vm),
                        onClose: { withAnimation(.easeInOut(duration: 0.18)) { vm.mode = .console } }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    Spacer()
                }
            }
        }
    }

    private func ensureCanvasLoaded(vm: StrategyWorkspaceViewModel) {
        guard let id = vm.selectedStrategyId else { return }
        // Reuse if already pointing at this strategy
        if canvasVM?.strategyId != id {
            let cvm = CanvasWebViewModel(strategyId: id, client: networkClient)
            canvasVM = cvm
        }
        // Push DSL from latest version (this is what fixed the "blank canvas" bug)
        if let raw = vm.snapshot?.latestVersion?.ruleDsl {
            let dict: [String: Any] = raw.mapValues { $0.value }
            canvasVM?.loadDSL(dict)
        }
    }

    private func versionLabel(_ vm: StrategyWorkspaceViewModel) -> String {
        guard let v = vm.snapshot?.latestVersion else { return L10n.Workbench.canvasNoVersion }
        return "v\(v.versionNo) · \(String(v.dslHash.prefix(8)))"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cpu")
                .font(.system(size: 28))
                .foregroundStyle(colors.textMuted)
            Text(L10n.Workbench.noStrategySelected)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)
            Text(L10n.Workbench.noStrategyHint)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncingPill(vm: StrategyWorkspaceViewModel) -> some View {
        Group {
            if vm.isLoadingSnapshot {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("syncing")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(colors.surfaceElevated)
                .clipShape(Capsule())
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Section grid

    private func sectionGrid(vm: StrategyWorkspaceViewModel) -> some View {
        let columns = [GridItem(.flexible(), spacing: 14),
                       GridItem(.flexible(), spacing: 14),
                       GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            RuntimeCard(run: vm.snapshot?.currentRun)
            VersionsCard(
                versions: vm.snapshot?.versions ?? [],
                onEdit: {
                    withAnimation(.easeInOut(duration: 0.18)) { vm.mode = .canvas }
                    ensureCanvasLoaded(vm: vm)
                }
            )
            RiskCard(risk: vm.snapshot?.risk)
            BacktestsCard(
                backtests: vm.snapshot?.backtests ?? [],
                onStart: { /* TODO */ }
            )
            DryrunCard(
                run: vm.snapshot?.currentRun,
                onStart: { /* TODO */ }
            )
            SignalCard(
                signals: vm.snapshot?.signals ?? [],
                onAttach: { /* TODO */ }
            )
        }
    }

    // MARK: - Switcher overlay (popover-like)

    private func switcherOverlay(vm: StrategyWorkspaceViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { vm.switcherOpen = false }

            StrategySwitcherPanel(
                vm: vm,
                onPick: { id in
                    Task {
                        await vm.select(strategyId: id)
                        // If we're in canvas mode, reload DSL for new strategy
                        if vm.mode == .canvas { ensureCanvasLoaded(vm: vm) }
                    }
                    vm.switcherOpen = false
                },
                onNewDraft: {
                    vm.switcherOpen = false
                    showNewDraftSheet = true
                }
            )
            .padding(.top, 56)
            .padding(.leading, 22)
        }
        .transition(.opacity)
    }

    // MARK: - Inspector overlay

    private func inspectorOverlay(vm: StrategyWorkspaceViewModel, tab: InspectorTab) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Color.black.opacity(0.001)
                .frame(width: 0)
            InspectorPanel(
                tab: tab,
                snapshot: vm.snapshot,
                onClose: { vm.inspectorTab = nil }
            )
            .padding(.trailing, 36) // leave the 36px rail visible
            .padding(.vertical, 10)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: - New draft sheet

    private var newDraftSheet: some View {
        VStack(spacing: PulseSpacing.md) {
            Text(L10n.Workbench.newDraft)
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)
            TextField(L10n.Strategies.enterName, text: $newDraftName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Button(L10n.Common.cancel) {
                    newDraftName = ""
                    showNewDraftSheet = false
                }
                Button(L10n.Common.confirm) {
                    if let vm = viewModel, !newDraftName.isEmpty {
                        let name = newDraftName
                        newDraftName = ""
                        showNewDraftSheet = false
                        Task {
                            let api = APIStrategiesV2(client: networkClient)
                            if let s = try? await api.create(name: name) {
                                vm.strategies.insert(s, at: 0)
                                await vm.select(strategyId: s.id)
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(PulseSpacing.lg)
        .frame(width: 360)
    }
}
