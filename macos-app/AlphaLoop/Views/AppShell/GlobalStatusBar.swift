// GlobalStatusBar.swift — Two-row top bar for the entire app.
//
//   Row 1 — brand + mode pill + main actions (language / theme / command palette /
//           notifications / emergency stop). Breadcrumb ("// 当前页") only when
//           the active route is NOT `.dashboard` (Dashboard has its own page
//           header to avoid duplication).
//   Row 2 — DashboardStatusStrip (provider / exchange / redis / freqtrade /
//           risk / positions / last update). Always present, fed by the live
//           network client (mock or live).

import SwiftUI

struct GlobalStatusBar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsState.self) private var settingsState
    @Environment(\.networkClient) private var networkClient

    @State private var showNotifications = false
    @State private var showEmergencyConfirm = false
    @State private var notificationViewModel: NotificationViewModel?
    @State private var statusVM = TopBarStatusViewModel()

    var body: some View {
        VStack(spacing: 0) {
            row1
            row2
        }
        .background(
            Rectangle()
                .fill(colors.surface.opacity(0.5))
                .overlay(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
        }
        .task {
            if notificationViewModel == nil {
                notificationViewModel = NotificationViewModel(client: networkClient)
            }
            statusVM.bind(client: networkClient)
            await statusVM.refresh()
        }
    }

    // MARK: - Row 1: brand + mode + actions

    private var row1: some View {
        HStack(spacing: PulseSpacing.md) {
            // Left: breadcrumb (only for non-Dashboard routes)
            if appState.selectedRoute != .dashboard {
                HStack(spacing: PulseSpacing.xxs) {
                    Text("//")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                    Text(appState.selectedRoute.label)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                .id(settingsState.language)
            } else {
                HStack(spacing: PulseSpacing.xs) {
                    Text("弈机")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.textPrimary)
                    Text("AlphaLoop")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                        .tracking(2)
                }
            }

            ModePill(mode: currentMode)

            Spacer()

            // Right: language / theme / search / notifications / emergency stop
            HStack(spacing: PulseSpacing.sm) {
                Button { settingsState.toggleLanguage() } label: {
                    Text(settingsState.language == .zhCN ? "中" : "EN")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .help(settingsState.language == .zhCN ? "Switch to English" : "切换到中文")

                Button { themeManager.toggle() } label: {
                    Image(systemName: themeManager.current == .dark ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .help(themeManager.current == .dark ? L10n.zh("切换明亮模式", en: "Light mode") : L10n.zh("切换暗黑模式", en: "Dark mode"))

                Button { appState.showCommandPalette.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("k", modifiers: .command)
                .help(L10n.zh("搜索 (⌘K)", en: "Search (⌘K)"))

                Button { showNotifications.toggle() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textMuted)
                            .frame(width: 24, height: 24)
                            .hoverGlassStyle(cornerRadius: PulseRadii.md)
                        if let vm = notificationViewModel, vm.unreadCount > 0 {
                            Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                                .font(PulseFonts.micro)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(PulseColors.danger))
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotifications) {
                    if let vm = notificationViewModel {
                        NotificationPopover(viewModel: vm) {
                            showNotifications = false
                            appState.selectedRoute = .systemSettings
                        }
                    }
                }

                Button { showEmergencyConfirm = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 11))
                        Text(L10n.Dashboard.actionEmergencyStop)
                            .font(PulseFonts.micro)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    .foregroundStyle(PulseColors.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.danger.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(PulseColors.danger.opacity(0.30), lineWidth: 0.7)
                    )
                }
                .buttonStyle(.plain)
                .help(L10n.Dashboard.haltDescription)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 40)
        .confirmDialog(
            isPresented: $showEmergencyConfirm,
            title: L10n.Dashboard.confirmHaltTitle,
            message: L10n.Dashboard.confirmHaltMessage,
            confirmLabel: L10n.Dashboard.haltAllTrading,
            confirmStyle: .danger,
            onConfirm: {
                showEmergencyConfirm = false
                Task { await statusVM.emergencyStop() }
            }
        )
    }

    // MARK: - Row 2: status strip

    private var row2: some View {
        DashboardStatusStrip(
            system: statusVM.system,
            risk: statusVM.risk,
            providerHealth: statusVM.providerHealth,
            positions: statusVM.positions,
            lastUpdated: statusVM.lastUpdated
        )
        .padding(.horizontal, PulseSpacing.md)
        .padding(.bottom, 6)
    }

    // MARK: - Mode

    private var currentMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: statusVM.system?.liveReadinessState,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }
}

// MARK: - Top Bar Status ViewModel

@Observable
@MainActor
final class TopBarStatusViewModel {
    var system: SystemOverviewResponse?
    var risk: RiskOverviewResponse?
    var providerHealth: ProviderHealthSummary?
    var positions: [PositionData] = []
    var lastUpdated: Date?

    private var client: NetworkClientProtocol?
    private var pollingTask: Task<Void, Never>?

    func bind(client: NetworkClientProtocol) {
        self.client = client
        startPolling()
    }

    func refresh() async {
        guard let client else { return }
        async let overview: () = loadOverview(client: client)
        async let providers: () = loadProviders(client: client)
        async let positions: () = loadPositions(client: client)
        _ = await (overview, providers, positions)
        lastUpdated = Date()
    }

    func emergencyStop() async {
        guard let client else { return }
        let emergency = APIEmergency(client: client)
        _ = try? await emergency.emergencyStop(reason: "User triggered from top bar")
        await refresh()
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    private func loadOverview(client: NetworkClientProtocol) async {
        do {
            let api = APIOverview(client: client)
            let status = try await api.getGlobalStatus()
            // Map GlobalStatusBFFResponse → SystemOverviewResponse + RiskOverviewResponse
            system = SystemOverviewResponse(
                liveReadinessState: status.systemState,
                fastTrackLatencyMs: status.fastTrackLatencyMs,
                redisRttMs: status.redisRttMs,
                freqtradeState: status.freqtradeState,
                exchangeState: status.exchangeState
            )
            risk = RiskOverviewResponse(
                globalState: status.riskState,
                dailyLossRemainingPct: 0,
                weeklyLossRemainingPct: 0,
                emergencyLocked: status.emergencyLocked,
                reasonCodes: status.reasonCodes
            )
        } catch {
            // soft-fail; keep prior values
        }
    }

    private func loadProviders(client: NetworkClientProtocol) async {
        do {
            let api = APIOverview(client: client)
            providerHealth = try await api.getProviderHealth()
        } catch {
            // soft-fail
        }
    }

    private func loadPositions(client: NetworkClientProtocol) async {
        do {
            let api = APIExecutionBFF(client: client)
            let resp = try await api.getOrdersPositions()
            positions = resp.positions.map { pos in
                PositionData(
                    symbol: pos.symbol,
                    direction: pos.side,
                    size: pos.quantity,
                    entryPrice: pos.avgEntryPrice,
                    currentPrice: pos.currentPrice,
                    pnl: pos.unrealizedPnl,
                    pnlPct: pos.unrealizedPnlPct,
                    riskLevel: "low",
                    reasonCodes: pos.reasonCodes,
                    stateDifference: pos.stateDifference
                )
            }
        } catch {
            // soft-fail
        }
    }
}
