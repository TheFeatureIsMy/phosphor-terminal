// ReconciliationBusView.swift — 对账总线

import SwiftUI

struct ReconciliationBusView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var viewModel: ExecutionCenterViewModel?

    var body: some View {
        VStack(spacing: 0) {
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
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "加载失败",
                        description: error,
                        primaryAction: (title: "重试", action: { Task { await vm.loadReconciliationBus() } })
                    )
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "暂无对账数据",
                        description: "尚未产生对账记录"
                    )
                }
            }
        }
        .task {
            let vm = ExecutionCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadReconciliationBus()
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: ExecutionCenterViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("对账总线")
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Text("Command Bus · State Lease · Exchange Finality")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Button {
                Task { await vm.loadReconciliationBus() }
            } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("刷新交易所状态")
                        .font(PulseFonts.monoLabel)
                }
                .foregroundStyle(PulseColors.accent)
            }
            .buttonStyle(.plain)
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
                    Text(data.state == "error" ? "对账异常" : "对账状态警告")
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
                    Text("暂无命令记录")
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
                    Text("暂无对账记录")
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
