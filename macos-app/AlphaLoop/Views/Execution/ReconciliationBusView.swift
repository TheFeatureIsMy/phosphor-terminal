// ReconciliationBusView.swift — 对账总线

import SwiftUI

struct ReconciliationBusView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: ExecutionCenterViewModel?
    @State private var showRetryBatchConfirm = false
    @State private var retryRunId: String?

    private var resolvedMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel?.reconciliationBus?.state,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    private var affectedRunCount: Int {
        viewModel?.reconciliationBus?.recentCommands.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveWireStrip(mode: resolvedMode)
            EmergencyStopBar(
                mode: resolvedMode,
                affectedRuns: affectedRunCount,
                emergencyLocked: viewModel?.reconciliationBus?.state == "emergency_locked",
                onStop: { await viewModel?.emergencyStop() },
                onResume: { await viewModel?.emergencyResume() }
            )

            if let vm = viewModel {
                if vm.isLoading && vm.reconciliationBus == nil {
                    LoadingView(type: .detail)
                } else if let data = vm.reconciliationBus {
                    // Header
                    headerSection(vm)

                    Divider().foregroundStyle(colors.border)

                    ScrollView {
                        VStack(spacing: PulseSpacing.lg) {
                            stateBanner(data)
                            commandBusSection(data.recentCommands)
                            reconciliationRunsSection(data.reconciliationRuns)
                        }
                        .padding(PulseSpacing.lg)
                    }
                    .id(settingsState.language)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.Reconciliation.loadFailed,
                        description: error,
                        primaryAction: (title: L10n.Reconciliation.retry, action: { Task { await vm.loadReconciliationBus() } })
                    )
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: L10n.Reconciliation.noData,
                        description: L10n.Reconciliation.noRecordsYet
                    )
                }
            }
        }
        .riskAtmosphericBackground(tint: PulseColors.accent)
        .task {
            let vm = ExecutionCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadReconciliationBus()
        }
        // Batch retry confirm
        .confirmDialog(
            isPresented: $showRetryBatchConfirm,
            title: L10n.Reconciliation.confirmRetry,
            message: String(
                format: L10n.Reconciliation.confirmRetryMessage,
                L10n.Reconciliation.retryReconciliation,
                resolvedMode.label
            ),
            confirmLabel: L10n.Reconciliation.retryReconciliation,
            confirmStyle: .warning,
            onConfirm: { Task { await viewModel?.retryReconciliationBatch() } }
        )
        // Single run retry confirm
        .confirmDialog(
            isPresented: .init(
                get: { retryRunId != nil },
                set: { if !$0 { retryRunId = nil } }
            ),
            title: L10n.Reconciliation.confirmRetry,
            message: String(
                format: L10n.Reconciliation.confirmRetryMessage,
                retryRunId ?? "",
                resolvedMode.label
            ),
            confirmLabel: L10n.Reconciliation.retry,
            confirmStyle: .warning,
            onConfirm: {
                guard let id = retryRunId else { return }
                Task { await viewModel?.retryReconciliationRun(id: id) }
                retryRunId = nil
            }
        )
    }

    // MARK: - Header

    private func headerSection(_ vm: ExecutionCenterViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Reconciliation.title)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Text("Command Bus · State Lease · Exchange Finality")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            HStack(spacing: PulseSpacing.sm) {
                Button {
                    showRetryBatchConfirm = true
                } label: {
                    Label(L10n.Reconciliation.retryReconciliation, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(PulseColors.warning)

                Button {
                    Task { await vm.loadReconciliationBus() }
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text(L10n.Reconciliation.refreshExchangeState)
                            .font(PulseFonts.monoLabel)
                    }
                    .foregroundStyle(PulseColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    // MARK: - 状态横幅

    @ViewBuilder
    private func stateBanner(_ data: ReconciliationBusBFFResponse) -> some View {
        if data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: data.state == "error" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "error" ? L10n.Reconciliation.reconciliationError : L10n.Reconciliation.reconciliationWarning)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !data.reasonCodes.isEmpty {
                        Text(data.reasonCodes.joined(separator: ", "))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill((data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke((data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Command Bus Timeline

    private func commandBusSection(_ commands: [CommandBusEventResponse]) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "Command Bus Timeline")

            if commands.isEmpty {
                HStack {
                    Spacer()
                    Text(L10n.Reconciliation.noCommandRecords)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                .padding(.vertical, PulseSpacing.md)
            } else {
                ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                    commandRow(command)
                        .staggeredAppearance(index: index)
                }
            }
        }
    }

    private func commandRow(_ command: CommandBusEventResponse) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Circle()
                .fill(commandStatusColor(command.status))
                .frame(width: 6, height: 6)

            Text(command.commandType)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)

            Text(command.id)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .lineLimit(1)

            Spacer()

            Text(command.status)
                .font(PulseFonts.micro)
                .foregroundStyle(commandStatusColor(command.status))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(commandStatusColor(command.status).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(PulseSpacing.xs)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Reconciliation Runs

    private func reconciliationRunsSection(_ runs: [ReconciliationRunResponse]) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "Reconciliation Runs")

            if runs.isEmpty {
                HStack {
                    Spacer()
                    Text(L10n.Reconciliation.noRuns)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                .padding(.vertical, PulseSpacing.md)
            } else {
                ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                    reconciliationRunRow(run)
                        .staggeredAppearance(index: index)
                }
            }
        }
    }

    private func reconciliationRunRow(_ run: ReconciliationRunResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Circle()
                .fill(reconStatusColor(run))
                .frame(width: 6, height: 6)

            Text(run.id)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            Text("\(run.discrepancies) discrepancies")
                .font(PulseFonts.caption)
                .foregroundStyle(run.discrepancies > 0 ? PulseColors.StateColors.orange : PulseColors.StateColors.green)

            Text(run.status)
                .font(PulseFonts.micro)
                .foregroundStyle(commandStatusColor(run.status))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(commandStatusColor(run.status).opacity(0.1))
                .clipShape(Capsule())

            // reason_codes 警告
            if !run.reasonCodes.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseColors.StateColors.yellow)
                    .help(run.reasonCodes.joined(separator: ", "))
            }

            // 内联重试按钮（失败/差异运行）
            if ["failed", "discrepancy"].contains(run.status.lowercased()) {
                Button {
                    retryRunId = run.id
                } label: {
                    Label(L10n.Reconciliation.retry, systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .tint(PulseColors.warning)
            }
        }
        .padding(PulseSpacing.xs)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - 辅助方法

    private func commandStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "success": return PulseColors.StateColors.green
        case "pending", "running", "in_progress": return PulseColors.StateColors.yellow
        case "failed", "error": return PulseColors.StateColors.red
        case "timeout": return PulseColors.StateColors.orange
        default: return PulseColors.StateColors.gray
        }
    }

    private func reconStatusColor(_ run: ReconciliationRunResponse) -> Color {
        if run.status == "completed" && run.discrepancies == 0 {
            return PulseColors.StateColors.green
        } else if run.discrepancies > 0 {
            return PulseColors.StateColors.orange
        } else {
            return commandStatusColor(run.status)
        }
    }
}
