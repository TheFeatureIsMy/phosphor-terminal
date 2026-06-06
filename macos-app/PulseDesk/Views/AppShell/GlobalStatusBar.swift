// GlobalStatusBar.swift — 跨页面顶部全局状态栏

import SwiftUI

struct GlobalStatusBar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var currentTime = Date()
    @State private var showNotifications = false
    @State private var notificationViewModel: NotificationViewModel?
    @State private var globalStatus: GlobalStatusBFFResponse?
    @State private var showReasonBar = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let pollTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            mainBar
            if showReasonBar, let status = globalStatus, !status.reasonCodes.isEmpty {
                reasonBar(codes: status.reasonCodes)
            }
        }
    }

    private var mainBar: some View {
        HStack(spacing: PulseSpacing.md) {
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

            // Mock mode indicator
            if !appState.isLiveMode {
                HStack(spacing: 3) {
                    Circle().fill(PulseColors.StateColors.yellow).frame(width: 5, height: 5)
                    Text("MOCK")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.StateColors.yellow)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PulseColors.StateColors.yellow.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: PulseSpacing.sm) {
                statusChip(label: "System", value: globalStatus?.systemState ?? "—", state: systemStateColor)
                statusChip(label: "Risk", value: globalStatus?.riskState ?? "—", state: riskStateColor)
                statusChip(label: "FT", value: "\(globalStatus?.fastTrackLatencyMs ?? 0)ms", state: latencyColor)
                statusChip(label: "Freqtrade", value: globalStatus?.freqtradeState ?? "—", state: freqtradeColor)
                statusChip(label: "Redis", value: "\(globalStatus?.redisRttMs ?? 0)ms", state: PulseColors.StateColors.green)
                statusChip(label: "Exchange", value: globalStatus?.exchangeState ?? "—", state: exchangeColor)
                statusChip(label: "Positions", value: "\(globalStatus?.openPositions ?? 0)", state: PulseColors.StateColors.green)

                if globalStatus?.emergencyLocked == true {
                    emergencyBadge
                }
            }

            Circle().fill(colors.textMuted).frame(width: 2, height: 2)

            Text(timeFormatter.string(from: currentTime))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .onReceive(timer) { time in currentTime = time }

            Button { appState.showCommandPalette.toggle() } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            Button { showNotifications.toggle() } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.textMuted)
                    if let vm = notificationViewModel, vm.unreadCount > 0 {
                        Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(PulseColors.danger))
                            .offset(x: 5, y: -5)
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
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
        }
        .task {
            if notificationViewModel == nil {
                notificationViewModel = NotificationViewModel(client: networkClient)
            }
            await loadGlobalStatus()
        }
        .onReceive(pollTimer) { _ in
            Task { await loadGlobalStatus() }
        }
    }

    private func reasonBar(codes: [String]) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(PulseColors.StateColors.red)
            Text(codes.joined(separator: " · "))
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.StateColors.red)
            Spacer()
            Button("Dismiss") { withAnimation { showReasonBar = false } }
                .font(PulseFonts.micro)
                .buttonStyle(.plain)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xxs)
        .background(PulseColors.StateColors.red.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func statusChip(label: String, value: String, state: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(state).frame(width: 5, height: 5)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
        }
    }

    private var emergencyBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill").font(.system(size: 8))
            Text("EMERGENCY").font(PulseFonts.micro)
        }
        .foregroundStyle(PulseColors.StateColors.red)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(PulseColors.StateColors.red.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - State Colors
    private var systemStateColor: Color {
        guard let state = globalStatus?.systemState else { return PulseColors.StateColors.gray }
        switch state {
        case "LIVE_READY", "LIVE_SMALL_READY": return PulseColors.StateColors.green
        case "PAPER_ONLY": return PulseColors.StateColors.yellow
        case "RISK_LOCKED", "EMERGENCY_LOCKED": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private var riskStateColor: Color {
        guard let state = globalStatus?.riskState else { return PulseColors.StateColors.gray }
        switch state {
        case "normal": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "blocked", "locked": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private var latencyColor: Color {
        guard let ms = globalStatus?.fastTrackLatencyMs else { return PulseColors.StateColors.gray }
        if ms < 100 { return PulseColors.StateColors.green }
        if ms < 200 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.red
    }

    private var freqtradeColor: Color {
        guard let state = globalStatus?.freqtradeState else { return PulseColors.StateColors.gray }
        return state == "healthy" ? PulseColors.StateColors.green : PulseColors.StateColors.red
    }

    private var exchangeColor: Color {
        guard let state = globalStatus?.exchangeState else { return PulseColors.StateColors.gray }
        return state == "ok" ? PulseColors.StateColors.green : PulseColors.StateColors.yellow
    }

    // MARK: - Data Loading (Real API)
    private func loadGlobalStatus() async {
        let api = APIOverview(client: networkClient)
        do {
            let response = try await api.getGlobalStatus()
            globalStatus = response
            if response.emergencyLocked || !response.reasonCodes.isEmpty {
                withAnimation { showReasonBar = true }
            } else {
                withAnimation { showReasonBar = false }
            }
        } catch {
            // Keep existing data on error
        }
    }
}
