// DryrunMonitorView.swift — 模拟监控页面
// 状态概览 + 运行中/已完成 Bot 列表

import SwiftUI

struct DryrunMonitorView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: DryrunMonitorViewModel?
    @State private var showCompletedRuns = false
    @State private var showStartPanel = false
    @State private var dryrunStrategyId = ""

    var body: some View {
        Group {
            if let vm = viewModel {
                dryrunContent(vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DryrunMonitorViewModel(client: networkClient)
            }
        }
        .task {
            await viewModel?.load()
        }
        .overlay {
            if showStartPanel {
                PulseModalOverlay {
                    VStack(spacing: PulseSpacing.md) {
                        TerminalLabel(text: L10n.zh("启动模拟盘", en: "Start Paper Trading"))
                        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                            Text(L10n.zh("策略版本 ID", en: "Strategy Version ID")).font(PulseFonts.captionMedium).foregroundStyle(colors.textSecondary)
                            TextField(L10n.zh("输入策略版本 ID...", en: "Enter strategy version ID..."), text: $dryrunStrategyId).darkTextField()
                        }
                        HStack {
                            KryptonButton(title: L10n.zh("取消", en: "Cancel"), action: {
                                withAnimation { showStartPanel = false }
                            }, style: .ghost)
                            Spacer()
                            KryptonButton(title: L10n.zh("启动", en: "Start"), action: {
                                Task {
                                    let api = APIDryrunV2(client: networkClient)
                                    _ = try? await api.startDryrun(["strategy_version_id": dryrunStrategyId])
                                    showStartPanel = false
                                    await viewModel?.load()
                                }
                            })
                            .opacity(dryrunStrategyId.isEmpty ? 0.5 : 1)
                            .disabled(dryrunStrategyId.isEmpty)
                        }
                    }
                    .padding(PulseSpacing.lg)
                    .frame(width: 400)
                } onDismiss: {
                    withAnimation { showStartPanel = false }
                }
            }
        }
        .animation(PulseAnimation.springDefault, value: showStartPanel)
    }

    @ViewBuilder
    private func dryrunContent(_ vm: DryrunMonitorViewModel) -> some View {
        VStack(spacing: 0) {
            // 标题栏
            headerBar(vm)

            Divider()
                .foregroundStyle(colors.border)

            if vm.isLoading {
                VStack {
                    Spacer()
                    LoadingView(type: .grid)
                    Spacer()
                }
            } else if vm.runs.isEmpty {
                EmptyStateView(
                    icon: "play.circle",
                    title: L10n.zh("暂无模拟运行", en: "No Paper Trading Runs"),
                    description: L10n.zh("启动模拟运行后，Bot 状态将实时显示在此处", en: "Bot status will appear here once paper trading is started")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: PulseSpacing.md) {
                        // 状态概览
                        statusOverview(vm)

                        // 运行中
                        if !vm.activeRuns.isEmpty {
                            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                                TerminalLabel(text: L10n.zh("运行中", en: "Running"))
                                    .padding(.horizontal, PulseSpacing.lg)

                                LazyVStack(spacing: PulseSpacing.xs) {
                                    ForEach(Array(vm.activeRuns.enumerated()), id: \.element.id) { index, run in
                                        DryrunBotCard(
                                            run: run,
                                            onStop: { Task { await vm.stopDryrun(run.id) } },
                                            onViewDetail: { navigateToExecutionRecords() }
                                        )
                                        .staggeredAppearance(index: index, baseDelay: 0.04)
                                    }
                                }
                                .padding(.horizontal, PulseSpacing.lg)
                            }
                        }

                        // 已完成
                        if !vm.completedRuns.isEmpty {
                            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                                HStack {
                                    TerminalLabel(text: L10n.zh("已完成", en: "Completed"))

                                    Spacer()

                                    Button {
                                        withAnimation(PulseAnimation.easeOutMedium) {
                                            showCompletedRuns.toggle()
                                        }
                                    } label: {
                                        HStack(spacing: PulseSpacing.xxs) {
                                            Text(showCompletedRuns ? L10n.zh("收起", en: "Collapse") : L10n.zh("展开", en: "Expand"))
                                                .font(PulseFonts.monoLabel)
                                            Image(systemName: showCompletedRuns ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 9))
                                        }
                                        .foregroundStyle(colors.textMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, PulseSpacing.lg)

                                if showCompletedRuns {
                                    LazyVStack(spacing: PulseSpacing.xs) {
                                        ForEach(Array(vm.completedRuns.enumerated()), id: \.element.id) { index, run in
                                            DryrunBotCard(
                                                run: run,
                                                onStop: nil,
                                                onViewDetail: { navigateToExecutionRecords() }
                                            )
                                            .staggeredAppearance(index: index, baseDelay: 0.03)
                                        }
                                    }
                                    .padding(.horizontal, PulseSpacing.lg)
                                }
                            }
                        }
                    }
                    .padding(.vertical, PulseSpacing.md)
                }
                .id(settingsState.language)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
    }

    // MARK: - 标题栏

    private func headerBar(_ vm: DryrunMonitorViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("模拟监控", en: "Paper Trading Monitor"))

            Text("\(vm.activeRuns.count)")
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
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .help(L10n.zh("刷新", en: "Refresh"))

            KryptonButton(title: L10n.zh("启动模拟", en: "Start Paper Trading"), action: {
                showStartPanel = true
            }, style: .primary)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 状态概览

    private func statusOverview(_ vm: DryrunMonitorViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            statCard(
                title: L10n.zh("运行中", en: "Running"),
                value: "\(vm.activeRuns.count)",
                color: PulseColors.statusActive
            )

            statCard(
                title: L10n.zh("已完成", en: "Completed"),
                value: "\(vm.completedRuns.count)",
                color: PulseColors.info
            )

            statCard(
                title: L10n.zh("平均时长", en: "Avg Duration"),
                value: formatDuration(vm.avgDurationSeconds),
                color: PulseColors.accent
            )
        }
        .padding(.horizontal, PulseSpacing.lg)
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(title)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)

                Text(value)
                    .font(PulseFonts.tabularLarge)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 工具方法

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            let h = Int(seconds / 3600)
            let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h \(m)m"
        }
    }

    private func navigateToExecutionRecords() {
        appState.selectedRoute = .executionCenter
    }
}
