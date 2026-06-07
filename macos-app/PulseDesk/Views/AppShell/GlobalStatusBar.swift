// GlobalStatusBar.swift — Krypton Pro 顶部控制甲板

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

    private let pollTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            controlDeck
            if showReasonBar, let status = globalStatus, !status.reasonCodes.isEmpty {
                reasonBar(codes: status.reasonCodes)
            }
        }
    }

    private var controlDeck: some View {
        HStack(spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PulseSpacing.xxs) {
                    Text("KRYPTON PRO")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.accent)
                        .tracking(1.8)
                    Text("//")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.accent)
                    Text(appState.selectedRoute.label)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                Text(routeSubtitle)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            LiveModeIndicator(isLive: appState.isLiveMode, emergencyLocked: globalStatus?.emergencyLocked == true)
            EmergencyPauseButton(isLive: appState.isLiveMode) {
                // Pause all trading — TODO wire to backend
                print("[Emergency] Pause all trading")
            }

            Spacer()

            HStack(spacing: PulseSpacing.xs) {
                KryptonStatusPill(label: "SYSTEM", value: globalStatus?.systemState ?? "—", state: systemStateColor)
                KryptonStatusPill(label: "RISK", value: globalStatus?.riskState ?? "—", state: riskStateColor)
                KryptonStatusPill(label: "FT", value: "\(globalStatus?.fastTrackLatencyMs ?? 0)ms", state: latencyColor)
                KryptonStatusPill(label: "FREQTRADE", value: globalStatus?.freqtradeState ?? "—", state: freqtradeColor)
                KryptonStatusPill(label: "REDIS", value: "\(globalStatus?.redisRttMs ?? 0)ms", state: PulseColors.StateColors.green)
                KryptonStatusPill(label: "EXCHANGE", value: globalStatus?.exchangeState ?? "—", state: exchangeColor)
                KryptonStatusPill(label: "POSITIONS", value: "\(globalStatus?.openPositions ?? 0)", state: PulseColors.StateColors.green)

                if globalStatus?.emergencyLocked == true {
                    emergencyBadge
                }
            }

            Circle().fill(colors.textMuted).frame(width: 2, height: 2)

            Text(timeFormatter.string(from: currentTime))
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .onReceive(pollTimer) { time in currentTime = time }

            Button {
                appState.showCommandPalette.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            Button {
                showNotifications.toggle()
            } label: {
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
        .padding(.vertical, PulseSpacing.md)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.border).frame(height: 1)
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

    private var routeSubtitle: String {
        switch appState.selectedRoute.section {
        case .overview: return "AI 多 Agent 总览、风控与执行态势"
        case .strategy: return "策略工作台、画布与模拟验证"
        case .structure: return "市场结构、矩阵与操纵雷达"
        case .execution: return "订单、持仓与对账总线"
        case .risk: return "止损保护、熔断与风险拦截"
        case .aiResearch: return "AI 投研、Agent 平台与信号中心"
        case .growth: return "复盘成长、失败聚类与策略优化"
        case .system: return "服务、数据源与终端设置"
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
            Button("Dismiss") {
                withAnimation { showReasonBar = false }
            }
            .font(PulseFonts.micro)
            .buttonStyle(.plain)
            .foregroundStyle(colors.textMuted)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xxs)
        .background(PulseColors.StateColors.red.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
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
