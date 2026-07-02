// ExecutionCenterView.swift — 执行中心

import SwiftUI

struct ExecutionCenterView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: ExecutionCenterViewModel?

    private var resolvedMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel?.centerData?.state,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveWireStrip(mode: resolvedMode)
            EmergencyStopBar(
                mode: resolvedMode,
                affectedRuns: viewModel?.centerData?.totalRunning ?? 0,
                emergencyLocked: viewModel?.centerData?.state == "emergency_locked",
                onStop: { await viewModel?.emergencyStop() },
                onResume: { await viewModel?.emergencyResume() }
            )
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
                                title: L10n.Execution.loadFailed,
                                description: error,
                                primaryAction: (title: L10n.Common.retry, action: { Task { await vm.loadCenter() } })
                            )
                        } else {
                            EmptyStateView(
                                icon: "play.circle",
                                title: L10n.Execution.noSessions,
                                description: L10n.Execution.noSessionsDesc
                            )
                        }
                    }
                }
                .padding(PulseSpacing.lg)
                .id(settingsState.language)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
        .riskAtmosphericBackground(tint: PulseColors.accent)
        .task {
            let vm = ExecutionCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadCenter()
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
                    Text(data.state == "error" ? L10n.Execution.systemError : L10n.Execution.engineError)
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
                title: L10n.Execution.runningSessions,
                value: "\(data.totalRunning)",
                icon: "play.circle.fill",
                color: PulseColors.StateColors.green
            )
            .staggeredAppearance(index: 0)

            summaryCard(
                title: L10n.Execution.positions,
                value: "\(data.totalOpenPositions)",
                icon: "chart.bar.fill",
                color: PulseColors.StateColors.orange
            )
            .staggeredAppearance(index: 1)

            summaryCard(
                title: L10n.Execution.pendingOrders,
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
                title: L10n.Execution.latency,
                value: "\(data.executionLatencyMs)ms",
                icon: "timer",
                color: latencyColor(data.executionLatencyMs)
            )
            .staggeredAppearance(index: 4)

        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        KryptonCard(emphasis: .subtle) {
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

    // MARK: - 会话列表

    private func sessionTableSection(_ data: ExecutionCenterBFFResponse) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Execution.executionSessions)

            if data.sessions.isEmpty {
                EmptyStateView(
                    icon: "play.slash",
                    title: L10n.Execution.noSessionsEmpty,
                    description: L10n.Execution.noSessionsEmptyDesc
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
                Text(L10n.Execution.positionsCount(session.openPositions))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                Text(L10n.Execution.pendingCount(session.pendingOrders))
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

}
