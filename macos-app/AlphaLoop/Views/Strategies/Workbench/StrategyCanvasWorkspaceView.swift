// StrategyCanvasWorkspaceView.swift — Workbench shell assembly (Plan 2026-06-18 Task 18).
// ZStack: background → CanvasWebView → HUD overlay → status bar overlay → floating panel overlay.
// Wires ⌘1–⌘6 shortcuts and CanvasBridge callbacks (selectionChanged / graphStats) into the VM.

import SwiftUI

struct StrategyCanvasWorkspaceView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors

    @State private var vm: StrategyWorkspaceViewModel?
    @State private var canvasVM: CanvasWebViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .id(settingsState.language)
        .task {
            if vm == nil {
                let v = StrategyWorkspaceViewModel(client: networkClient)
                vm = v
                await v.loadList()
                if let id = appState.selectedStrategyV2Id {
                    await v.select(strategyId: id)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: StrategyWorkspaceViewModel) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()

            // Canvas full-screen
            if let canvasVM {
                CanvasWebView(viewModel: canvasVM)
            } else {
                Color.clear
            }

            // HUD (top) + Status bar (bottom) overlay
            VStack(spacing: 0) {
                WorkbenchHUD(vm: vm) { panel in vm.togglePanel(panel) }
                Spacer()
                WorkbenchStatusBar(
                    validationState: validationState(from: vm),
                    version: vm.latestVersion,
                    nodeCount: vm.canvasNodeCount,
                    edgeCount: vm.canvasEdgeCount
                )
            }

            // Floating panel overlay (top-trailing)
            if let panel = vm.activePanel {
                HStack {
                    Spacer()
                    panelView(panel: panel, vm: vm)
                        .padding(.top, 56)
                        .padding(.trailing, 16)
                        .padding(.bottom, 40)
                }
                .frame(maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(true)
            }
        }
        .onAppear { ensureCanvasLoaded(vm) }
        .onChange(of: vm.selectedStrategyId) { _, _ in ensureCanvasLoaded(vm) }
        .onChange(of: vm.snapshot?.latestVersionId) { _, _ in ensureCanvasLoaded(vm) }
        .onChange(of: vm.selectedStrategy?.status) { _, newStatus in
            if newStatus == "archived" { canvasVM?.setReadOnly(true) }
        }
        .background {
            // ⌘1–⌘6 panel toggles (hidden shortcut buttons)
            ForEach(WorkbenchPanel.allCases) { p in
                Button("") { vm.togglePanel(p) }
                    .keyboardShortcut(p.shortcut, modifiers: .command)
                    .hidden()
            }
        }
    }

    // MARK: - Panel routing

    @ViewBuilder
    private func panelView(panel: WorkbenchPanel, vm: StrategyWorkspaceViewModel) -> some View {
        switch panel {
        case .list:      StrategyListPanel(vm: vm)
        case .node:      NodeConfigPanel(vm: vm)
        case .version:   VersionsPanel(vm: vm)
        case .risk:      RiskBindingPanel(vm: vm)
        case .backtest:  BacktestDryrunPanel(vm: vm)
        case .readiness: ReadinessPanel(vm: vm)
        }
    }

    // MARK: - Canvas lifecycle

    private func ensureCanvasLoaded(_ vm: StrategyWorkspaceViewModel) {
        guard let id = vm.selectedStrategyId else { return }
        if canvasVM?.strategyId != id {
            let model = CanvasWebViewModel(strategyId: id, client: networkClient)
            // Wire bridge → workbench VM
            model.onSelectionChanged = { selection in
                vm.selectedCanvasNodeId = selection?.id
            }
            model.onGraphStats = { stats in
                vm.canvasNodeCount = stats.nodeCount
                vm.canvasEdgeCount = stats.edgeCount
                switch stats.validation {
                case "valid":    vm.canvasValidationValid = true
                case "invalid":  vm.canvasValidationValid = false
                default:         vm.canvasValidationValid = nil
                }
            }
            canvasVM = model
        }
        guard let canvasVM else { return }

        // Push latest DSL into the canvas when a version is loaded
        if let raw = vm.latestVersion?.ruleDsl {
            canvasVM.loadDSL(raw.mapValues { $0.value })
        }

        // Archive gate
        if vm.selectedStrategy?.status == "archived" {
            canvasVM.setReadOnly(true)
        }
    }

    // MARK: - Validation state mapping

    private func validationState(from vm: StrategyWorkspaceViewModel) -> CanvasValidationState {
        if vm.canvasValidationValid == true { return .valid }
        if vm.canvasValidationValid == false { return .invalid(count: 0) }
        return .unvalidated
    }
}
