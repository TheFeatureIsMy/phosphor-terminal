// ExecutionRecordsView.swift — 执行记录页面
// 运行列表 + 模式/状态过滤 + 详情弹窗

import SwiftUI

struct ExecutionRecordsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: ExecutionRecordsViewModel?
    @State private var showDetailSheet = false

    var body: some View {
        Group {
            if let vm = viewModel {
                executionRecordsContent(vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ExecutionRecordsViewModel(client: networkClient)
            }
        }
        .task {
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func executionRecordsContent(_ vm: ExecutionRecordsViewModel) -> some View {
        VStack(spacing: 0) {
            headerBar(vm)
            Divider().foregroundStyle(colors.border)
            filterBar(vm)
            Divider().foregroundStyle(colors.border)

            if vm.isLoading {
                VStack {
                    Spacer()
                    LoadingView(type: .listRow)
                    LoadingView(type: .listRow)
                    LoadingView(type: .listRow)
                    Spacer()
                }
            } else if vm.filteredRuns.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: L10n.zh("暂无执行记录", en: "No Trade Logs"),
                    description: L10n.zh("启动回测或模拟运行后，记录将显示在此处", en: "Records will appear here after running a backtest or simulation")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PulseSpacing.xs) {
                        ForEach(Array(vm.filteredRuns.enumerated()), id: \.element.id) { index, run in
                            runRow(run, vm: vm)
                                .staggeredAppearance(index: index, baseDelay: 0.03)
                        }
                    }
                    .padding(.horizontal, PulseSpacing.lg)
                    .padding(.vertical, PulseSpacing.md)
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .id(settingsState.language)
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let run = vm.selectedRun {
                ExecutionDetailSheet(run: run, viewModel: vm)
                    .frame(minWidth: 640, minHeight: 480)
            }
        }
    }

    // MARK: - 标题栏

    private func headerBar(_ vm: ExecutionRecordsViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("执行记录", en: "TRADE LOG"))

            Text("\(vm.runs.count)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(PulseColors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(PulseColors.accent.opacity(0.08))
                )

            Spacer()

            Button {
                Task { await vm.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .help(L10n.zh("刷新", en: "Refresh"))
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 过滤栏

    private func filterBar(_ vm: ExecutionRecordsViewModel) -> some View {
        HStack(spacing: PulseSpacing.md) {
            // 模式过滤
            HStack(spacing: 2) {
                modePill(L10n.zh("全部", en: "All"), value: nil, vm: vm)
                modePill("backtest", value: "backtest", vm: vm)
                modePill("dryrun", value: "dryrun", vm: vm)
                modePill("live_small", value: "live_small", vm: vm)
            }

            Rectangle()
                .fill(colors.border)
                .frame(width: 1, height: 16)

            // 状态过滤
            HStack(spacing: 2) {
                statusPill(L10n.zh("全部", en: "All"), value: nil, vm: vm)
                statusPill("running", value: "running", vm: vm)
                statusPill("completed", value: "completed", vm: vm)
                statusPill("stopped", value: "stopped", vm: vm)
                statusPill("failed", value: "error", vm: vm)
            }

            Spacer()

            Text("\(vm.filteredRuns.count) " + L10n.zh("条", en: "records"))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xs)
    }

    private func modePill(_ label: String, value: String?, vm: ExecutionRecordsViewModel) -> some View {
        let isActive = vm.filterMode == value
        return Button {
            vm.filterMode = value
        } label: {
            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(isActive ? colors.background : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(isActive ? PulseColors.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func statusPill(_ label: String, value: String?, vm: ExecutionRecordsViewModel) -> some View {
        let isActive = vm.filterStatus == value
        return Button {
            vm.filterStatus = value
        } label: {
            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(isActive ? colors.background : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(isActive ? PulseColors.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 运行行

    private func runRow(_ run: StrategyRunV2, vm: ExecutionRecordsViewModel) -> some View {
        KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                // 模式徽章
                modeBadge(run.mode)

                // 策略版本 ID（截断）
                VStack(alignment: .leading, spacing: 2) {
                    Text(truncateUUID(run.strategyVersionId))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)

                    if let started = run.startedAt {
                        Text(formatDateTime(started))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()

                // 时长
                if let duration = computeDuration(start: run.startedAt, stop: run.stoppedAt) {
                    Text(duration)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textSecondary)
                }

                // 状态徽章
                BadgeView(
                    text: statusLabel(run.status),
                    color: statusColor(run.status),
                    size: .small
                )

                // 操作按钮
                Button {
                    vm.selectedRun = run
                    Task { await vm.loadRunDetails(run.id) }
                    showDetailSheet = true
                } label: {
                    Text(L10n.zh("查看订单", en: "Orders"))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                        .padding(.horizontal, PulseSpacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.button)
                                .stroke(PulseColors.accent.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    vm.selectedRun = run
                    Task { await vm.loadRunDetails(run.id) }
                    showDetailSheet = true
                } label: {
                    Text(L10n.zh("查看日志", en: "Logs"))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, PulseSpacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.button)
                                .stroke(colors.border, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.selectedRun = run
            Task { await vm.loadRunDetails(run.id) }
            showDetailSheet = true
        }
    }

    // MARK: - 模式徽章

    private func modeBadge(_ mode: String) -> some View {
        let (label, color) = modeInfo(mode)
        return BadgeDot(color: color, label: label, size: .small)
    }

    private func modeInfo(_ mode: String) -> (String, Color) {
        switch mode {
        case "backtest": return ("backtest", PulseColors.info)
        case "dryrun": return ("dryrun", PulseColors.warning)
        case "live_small": return ("live", PulseColors.danger)
        case "live": return ("live", PulseColors.danger)
        default: return (mode, colors.textMuted)
        }
    }

    // MARK: - 状态

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "running": return L10n.zh("运行中", en: "Running")
        case "completed": return L10n.zh("已完成", en: "Completed")
        case "stopped": return L10n.zh("已停止", en: "Stopped")
        case "error": return L10n.zh("失败", en: "Failed")
        case "starting": return L10n.zh("启动中", en: "Starting")
        case "degraded": return L10n.zh("降级", en: "Degraded")
        default: return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running", "starting": return PulseColors.statusActive
        case "completed": return PulseColors.info
        case "stopped": return colors.textMuted
        case "error": return PulseColors.statusError
        case "degraded": return PulseColors.warning
        default: return colors.textMuted
        }
    }

    // MARK: - 工具方法

    private func truncateUUID(_ uuid: String) -> String {
        if uuid.count > 12 {
            return String(uuid.prefix(8)) + "..."
        }
        return uuid
    }

    private func formatDateTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }

    private func computeDuration(start: String?, stop: String?) -> String? {
        guard let startStr = start else { return nil }
        let fmt = ISO8601DateFormatter()
        guard let startDate = fmt.date(from: startStr) else { return nil }
        let endDate: Date
        if let stopStr = stop, let stopDate = fmt.date(from: stopStr) {
            endDate = stopDate
        } else {
            endDate = Date()
        }
        let interval = endDate.timeIntervalSince(startDate)
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let h = Int(interval / 3600)
            let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h \(m)m"
        }
    }
}
