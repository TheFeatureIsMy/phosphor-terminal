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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseSpacing.lg) {
                    if let vm = viewModel {
                        if vm.isLoading && vm.centerData == nil {
                            LoadingView(type: .detail)
                        } else if let data = vm.centerData {
                            pageHeader(data)
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
                .padding(.horizontal, 28)
                .padding(.top, PulseSpacing.md)
                .padding(.bottom, 40)
                .frame(maxWidth: PulseSpacing.contentMaxWidth)
                .frame(maxWidth: .infinity)
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

    // MARK: - 页面标题

    @ViewBuilder
    private func pageHeader(_ data: ExecutionCenterBFFResponse) -> some View {
        QuantPageHeader(
            eyebrow: "EXECUTION",
            title: L10n.zh("执行中心", en: "Execution Center"),
            subtitle: L10n.zh("\(data.totalRunning) 运行 · \(data.totalOpenPositions) 持仓 · \(data.totalPendingOrders) 挂单", en: "\(data.totalRunning) running · \(data.totalOpenPositions) positions · \(data.totalPendingOrders) pending")
        ) {
            HStack(spacing: PulseSpacing.xs) {
                // Status pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(data.state == "running" || data.state == "healthy" ? PulseColors.accent : PulseColors.warning)
                        .frame(width: 6, height: 6)
                        .shadow(color: (data.state == "running" || data.state == "healthy" ? PulseColors.accent : PulseColors.warning).opacity(0.6), radius: 4)
                    Text(data.state.uppercased())
                        .font(PulseFonts.mono(10, .semibold))
                        .foregroundStyle(colors.textSecondary)
                        .tracking(1.2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .stroke(colors.border, lineWidth: 1)
                )
            }
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
        MetricTileGrid(
            tiles: [
                MetricTileData(
                    label: L10n.Execution.runningSessions,
                    value: "\(data.totalRunning)",
                    valueColor: PulseColors.StateColors.green,
                    icon: "play.circle.fill"
                ),
                MetricTileData(
                    label: L10n.Execution.positions,
                    value: "\(data.totalOpenPositions)",
                    valueColor: PulseColors.StateColors.orange,
                    icon: "chart.bar.fill"
                ),
                MetricTileData(
                    label: L10n.Execution.pendingOrders,
                    value: "\(data.totalPendingOrders)",
                    valueColor: PulseColors.StateColors.yellow,
                    icon: "clock.fill"
                ),
                MetricTileData(
                    label: "Freqtrade",
                    value: heartbeatLabel(data.freqtradeHeartbeat),
                    valueColor: heartbeatColor(data.freqtradeHeartbeat),
                    icon: "heart.fill"
                ),
                MetricTileData(
                    label: L10n.Execution.latency,
                    value: "\(data.executionLatencyMs)ms",
                    valueColor: latencyColor(data.executionLatencyMs),
                    icon: "timer"
                ),
            ],
            columns: 5
        )
        .staggeredAppearance(index: 0)
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
            // Status dot with glow
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)
                .shadow(color: sessionStatusColor(session.status).opacity(0.5), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.strategyName)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xs) {
                    Text(session.symbol)
                        .font(PulseFonts.mono(11, .medium))
                        .foregroundStyle(colors.textMuted)
                    if !session.reasonCodes.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PulseColors.StateColors.yellow)
                            .help(session.reasonCodes.joined(separator: ", "))
                    }
                }
            }

            Spacer()

            // Mode tag — VOLT: mono + RoundedRectangle
            Text(session.mode.uppercased())
                .font(PulseFonts.mono(9.5, .semibold))
                .foregroundStyle(modeColor(session.mode))
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(modeColor(session.mode).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

            // Stats — mono numbers
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.Execution.positionsCount(session.openPositions))
                    .font(PulseFonts.mono(12, .medium))
                    .foregroundStyle(colors.textSecondary)
                Text(L10n.Execution.pendingCount(session.pendingOrders))
                    .font(PulseFonts.mono(11))
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border, lineWidth: 0.5)
        )
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
