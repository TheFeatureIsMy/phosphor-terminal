// DryrunMonitorView.swift — 模拟监控页面
// 状态概览 + 运行中/已完成 Bot 列表

import SwiftUI

struct DryrunMonitorView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
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
                        TerminalLabel(text: "启动模拟盘")
                        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                            Text("策略版本 ID").font(PulseFonts.captionMedium).foregroundStyle(colors.textSecondary)
                            TextField("输入策略版本 ID...", text: $dryrunStrategyId).darkTextField()
                        }
                        HStack {
                            KryptonButton(title: "取消", action: {
                                withAnimation { showStartPanel = false }
                            }, style: .ghost)
                            Spacer()
                            KryptonButton(title: "启动", action: {
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
                    title: "暂无模拟运行",
                    description: "启动模拟运行后，Bot 状态将实时显示在此处"
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
                                TerminalLabel(text: "运行中")
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
                                    TerminalLabel(text: "已完成")

                                    Spacer()

                                    Button {
                                        withAnimation(PulseAnimation.easeOutMedium) {
                                            showCompletedRuns.toggle()
                                        }
                                    } label: {
                                        HStack(spacing: PulseSpacing.xxs) {
                                            Text(showCompletedRuns ? "收起" : "展开")
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
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
    }

    // MARK: - 标题栏

    private func headerBar(_ vm: DryrunMonitorViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            TerminalLabel(text: "模拟监控")

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
            .help("刷新")

            KryptonButton(title: "启动模拟", action: {
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
                title: "运行中",
                value: "\(vm.activeRuns.count)",
                color: PulseColors.statusActive
            )

            statCard(
                title: "已完成",
                value: "\(vm.completedRuns.count)",
                color: PulseColors.info
            )

            statCard(
                title: "平均时长",
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
