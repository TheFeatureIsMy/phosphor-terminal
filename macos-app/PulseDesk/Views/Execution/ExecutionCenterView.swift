// ExecutionCenterView.swift — 执行中心

import SwiftUI

struct ExecutionCenterView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var viewModel: ExecutionCenterViewModel?
    @State private var showEmergencyConfirm = false
    @State private var emergencyInProgress = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                if let vm = viewModel {
                    if vm.isLoading && vm.centerData == nil {
                        LoadingView(type: .detail)
                    } else if let data = vm.centerData {
                        stateBanner(data)
                        summaryCardsRow(data)
                        sessionTableSection(data)
                    } else if let error = vm.error {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: "加载失败",
                            description: error,
                            primaryAction: (title: "重试", action: { Task { await vm.loadCenter() } })
                        )
                    } else {
                        EmptyStateView(
                            icon: "play.circle",
                            title: "暂无执行会话",
                            description: "尚未启动任何策略会话"
                        )
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            let vm = ExecutionCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadCenter()
        }
        .alert("确认紧急停止", isPresented: $showEmergencyConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认停止", role: .destructive) {
                Task { await performEmergencyStop() }
            }
        } message: {
            Text("将立即停止所有运行中的策略会话并取消所有挂单。此操作不可撤销。")
        }
    }

    // MARK: - 状态警告横幅

    @ViewBuilder
    private func stateBanner(_ data: ExecutionCenterBFFResponse) -> some View {
        if data.state != "running" && data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: data.state == "error" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "error" ? "系统异常" : "执行引擎异常")
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

    // MARK: - 汇总卡片

    private func summaryCardsRow(_ data: ExecutionCenterBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            summaryCard(
                title: "运行会话",
                value: "\(data.totalRunning)",
                icon: "play.circle.fill",
                color: PulseColors.StateColors.green
            )
            .staggeredAppearance(index: 0)

            summaryCard(
                title: "持仓",
                value: "\(data.totalOpenPositions)",
                icon: "chart.bar.fill",
                color: PulseColors.StateColors.orange
            )
            .staggeredAppearance(index: 1)

            summaryCard(
                title: "挂单",
                value: "\(data.totalPendingOrders)",
                icon: "clock.fill",
                color: PulseColors.StateColors.yellow
            )
            .staggeredAppearance(index: 2)

            summaryCard(
                title: "Freqtrade",
                value: heartbeatLabel(data.freqtradeHeartbeat),
                icon: "heart.fill",
                color: heartbeatColor(data.freqtradeHeartbeat)
            )
            .staggeredAppearance(index: 3)

            summaryCard(
                title: "延迟",
                value: "\(data.executionLatencyMs)ms",
                icon: "timer",
                color: latencyColor(data.executionLatencyMs)
            )
            .staggeredAppearance(index: 4)

            Spacer()

            emergencyStopButton
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(title)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private var emergencyStopButton: some View {
        Button {
            showEmergencyConfirm = true
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                if emergencyInProgress {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                }
                Text("紧急停止")
                    .font(PulseFonts.captionMedium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(PulseColors.StateColors.red)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(emergencyInProgress)
    }

    // MARK: - 会话列表

    private func sessionTableSection(_ data: ExecutionCenterBFFResponse) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "执行会话")

            if data.sessions.isEmpty {
                EmptyStateView(
                    icon: "play.slash",
                    title: "暂无会话",
                    description: "当前没有运行中的策略会话"
                )
            } else {
                LazyVStack(spacing: PulseSpacing.xs) {
                    ForEach(Array(data.sessions.enumerated()), id: \.element.id) { index, session in
                        sessionRow(session)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ExecutionSessionResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.strategyName)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(session.symbol)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Text(session.mode)
                .font(PulseFonts.micro)
                .foregroundStyle(modeColor(session.mode))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(modeColor(session.mode).opacity(0.1))
                .clipShape(Capsule())

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.openPositions) 持仓")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                Text("\(session.pendingOrders) 挂单")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            if !session.reasonCodes.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseColors.StateColors.yellow)
                    .help(session.reasonCodes.joined(separator: ", "))
            }
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - 辅助方法

    private func sessionStatusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.StateColors.green
        case "paused": return PulseColors.StateColors.yellow
        case "stopped": return PulseColors.StateColors.gray
        case "error": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private func modeColor(_ mode: String) -> Color {
        switch mode {
        case "live_small": return PulseColors.StateColors.orange
        case "live": return PulseColors.StateColors.red
        case "dryrun": return PulseColors.StateColors.yellow
        case "paper": return PulseColors.StateColors.green
        default: return PulseColors.StateColors.gray
        }
    }

    private func heartbeatLabel(_ heartbeat: String) -> String {
        switch heartbeat {
        case "healthy": return "Healthy"
        case "degraded": return "Degraded"
        case "down": return "Down"
        default: return heartbeat.capitalized
        }
    }

    private func heartbeatColor(_ heartbeat: String) -> Color {
        switch heartbeat {
        case "healthy": return PulseColors.StateColors.green
        case "degraded": return PulseColors.StateColors.yellow
        case "down": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<100: return PulseColors.StateColors.green
        case ..<300: return PulseColors.StateColors.yellow
        default: return PulseColors.StateColors.orange
        }
    }

    private func performEmergencyStop() async {
        emergencyInProgress = true
        defer { emergencyInProgress = false }
        do {
            let _: [String: String] = try await networkClient.post(
                "/api/execution/emergency-stop",
                body: nil as String?,
                mock: { ["status": "executed"] }
            )
            // Reload center data after emergency stop
            await viewModel?.loadCenter()
        } catch {
            viewModel?.error = error.localizedDescription
        }
    }
}
