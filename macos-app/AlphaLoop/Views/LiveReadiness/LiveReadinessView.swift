// LiveReadinessView.swift — 实盘准入「地平线协议」
// Centered hero → horizontal gate corridor → telemetry triptych → command bar

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Environment(ToastManager.self) private var toastManager
    @Bindable var viewModel: LiveReadinessViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.xl) {
                scoreHero
                    .staggeredAppearance(index: 0)

                GatePipelineView(gates: viewModel.strategyGates)
                    .staggeredAppearance(index: 1)

                warningsBanner
                    .staggeredAppearance(index: 2)

                telemetryTriptych
                    .staggeredAppearance(index: 3)

                launchCommand
                    .staggeredAppearance(index: 4)
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .background(ambientBackground)
        .task { await viewModel.loadData() }
        .id(settingsState.language)
        .sheet(isPresented: $viewModel.showLaunchConfirmation) {
            LaunchConfirmationSheet(viewModel: viewModel)
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        VStack {
            LinearGradient(
                colors: [stateColor.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 400)
            Spacer()
        }
        .ignoresSafeArea()
    }

    // MARK: - 1. Score Hero

    private var scoreHero: some View {
        VStack(spacing: PulseSpacing.md) {
            // RE-CHECK button (top-right aligned)
            HStack {
                Spacer()
                recheckButton
            }

            // Orbital gauge
            ReadinessGaugeView(score: viewModel.data?.score ?? 0)

            // State lamp + label
            HStack(spacing: PulseSpacing.xs) {
                stateLamp
                Text(stateLabel)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stateColor)
                    .textCase(.uppercase)
                    .tracking(2)
            }

            // State description
            Text(L10n.LiveReadiness.stateDescription(viewModel.data?.state ?? ""))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            // Permission toggles
            HStack(spacing: PulseSpacing.md) {
                permissionBadge(L10n.LiveReadiness.paper, enabled: viewModel.data?.canStartPaper ?? false)
                permissionBadge(L10n.LiveReadiness.small, enabled: viewModel.data?.canStartLiveSmall ?? false)
                permissionBadge(L10n.LiveReadiness.full, enabled: viewModel.data?.canStartFullLive ?? false)
            }
        }
    }

    @State private var lampPulse = false

    private var stateLamp: some View {
        Circle()
            .fill(stateColor)
            .frame(width: 10, height: 10)
            .shadow(color: stateColor.opacity(0.6), radius: lampPulse ? 8 : 3)
            .scaleEffect(lampPulse ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: lampPulse)
            .onAppear { lampPulse = true }
    }

    private func permissionBadge(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(enabled ? PulseColors.accent : colors.textMuted.opacity(0.3))
                .frame(width: 6, height: 6)
                .shadow(color: enabled ? PulseColors.accent.opacity(0.4) : .clear, radius: 3)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(enabled ? PulseColors.accent : colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private var recheckButton: some View {
        Button {
            Task { await viewModel.runCheck() }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                if viewModel.isChecking {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                Text(L10n.LiveReadiness.recheck)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(colors.textSecondary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(colors.border.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isChecking)
    }

    // MARK: - 2. Warnings Banner

    @ViewBuilder
    private var warningsBanner: some View {
        let warnings = viewModel.data?.warnings ?? []
        if !warnings.isEmpty {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseColors.amber)

                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning["message"] ?? warning["code"] ?? "")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.amber.opacity(0.8))
                }

                Spacer()
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(PulseColors.amber.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(PulseColors.amber.opacity(0.1), lineWidth: 0.5)
            )
        }
    }

    // MARK: - 3. Telemetry Triptych

    private var telemetryTriptych: some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            systemHealthPanel
            riskFirewallPanel
            capitalPoolPanel
        }
    }

    // MARK: System Health

    private var systemHealthPanel: some View {
        telemetryPanel(title: L10n.LiveReadiness.systemHealth) {
            let checks = viewModel.data?.checks ?? []
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(checks.enumerated()), id: \.offset) { index, check in
                    healthRow(check)
                    if index < checks.count - 1 {
                        Divider().background(colors.border.opacity(0.15)).padding(.leading, 18)
                    }
                }
            }
        }
    }

    private func healthRow(_ check: ReadinessCheckResponse) -> some View {
        let statusColor = checkStatusColor(check.status)
        return HStack(spacing: PulseSpacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
                .shadow(color: statusColor.opacity(0.4), radius: 2)

            Text(check.label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(check.value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(statusColor)

            if !check.threshold.isEmpty {
                Text(check.threshold)
                    .font(.system(size: 8))
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: Risk Firewall

    private var riskFirewallPanel: some View {
        Button {
            appState.selectedRoute = .riskCenter
        } label: {
            telemetryPanel(
                title: L10n.LiveReadiness.riskFirewall,
                trailing: AnyView(
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(colors.textMuted)
                )
            ) {
                VStack(spacing: PulseSpacing.sm) {
                    riskBar(
                        label: L10n.LiveReadiness.daily,
                        used: viewModel.riskState.dailyLossUsed,
                        limit: viewModel.riskState.dailyLossLimit,
                        color: PulseColors.amber
                    )
                    riskBar(
                        label: L10n.LiveReadiness.weekly,
                        used: viewModel.riskState.weeklyLossUsed,
                        limit: viewModel.riskState.weeklyLossLimit,
                        color: PulseColors.cyan
                    )
                    riskBar(
                        label: L10n.LiveReadiness.consecutive,
                        used: viewModel.riskState.consecutiveLosses,
                        limit: viewModel.riskState.consecutiveLimit,
                        color: PulseColors.purple
                    )

                    Divider().background(colors.border.opacity(0.15))

                    // Status chips
                    HStack(spacing: PulseSpacing.xs) {
                        statusChip(
                            L10n.LiveReadiness.killSwitch,
                            value: viewModel.riskState.killSwitchActive
                                ? L10n.zh("激活", en: "ON") : L10n.LiveReadiness.off,
                            color: viewModel.riskState.killSwitchActive
                                ? PulseColors.danger : PulseColors.accent
                        )
                        statusChip(
                            L10n.LiveReadiness.breaker,
                            value: breakerStatusLabel,
                            color: breakerStatusColor
                        )
                        Spacer()
                    }
                }
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.bottom, PulseSpacing.xs)
            }
        }
        .buttonStyle(.plain)
    }

    private func riskBar(label: String, used: Double, limit: Double, color: Color) -> some View {
        let ratio = limit > 0 ? min(used / limit, 1.0) : 0
        let isHot = ratio > 0.8
        let barColor = isHot ? PulseColors.danger : color

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text(String(format: "%.1f%%", ratio * 100))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(colors.border.opacity(0.2))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor)
                        .frame(width: max(2, geo.size.width * ratio))
                        .shadow(color: barColor.opacity(isHot ? 0.4 : 0.15), radius: isHot ? 4 : 0)
                }
            }
            .frame(height: 4)
        }
    }

    private func statusChip(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .shadow(color: color.opacity(0.4), radius: 2)
            Text("\(label): \(value)")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .textCase(.uppercase)
        }
        .padding(.horizontal, PulseSpacing.xxs)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.06))
        )
    }

    private var breakerStatusLabel: String {
        if viewModel.breakerState.shouldStop { return L10n.zh("触发", en: "TRIP") }
        if viewModel.breakerState.shouldCooldown { return L10n.zh("冷却", en: "COOL") }
        return L10n.LiveReadiness.normal
    }

    private var breakerStatusColor: Color {
        if viewModel.breakerState.shouldStop { return PulseColors.danger }
        if viewModel.breakerState.shouldCooldown { return PulseColors.amber }
        return PulseColors.accent
    }

    // MARK: Capital Pool

    private var capitalPoolPanel: some View {
        telemetryPanel(title: L10n.LiveReadiness.capitalPool) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                capitalRow(L10n.LiveReadiness.totalBudget, value: viewModel.capitalConfig.totalBudget, unit: "USDT")
                capitalRow(L10n.LiveReadiness.stakePerTrade, value: viewModel.capitalConfig.stakeAmount, unit: "USDT")
                capitalRow(L10n.LiveReadiness.maxOpenTrades, value: viewModel.capitalConfig.maxOpenTrades, unit: "")
                capitalRow(L10n.LiveReadiness.maxDailyLoss, value: viewModel.capitalConfig.maxDailyLossPct, unit: "%")

                Divider().background(colors.border.opacity(0.15))

                // Safety badges
                HStack(spacing: PulseSpacing.xxs) {
                    safetyTag(L10n.LiveReadiness.noLeverage)
                    safetyTag(L10n.LiveReadiness.spotOnly)
                }
                HStack(spacing: PulseSpacing.xxs) {
                    safetyTag(L10n.LiveReadiness.humanConfirmRequired)
                    safetyTag(L10n.LiveReadiness.autoTradeOff)
                }

                Divider().background(colors.border.opacity(0.15))

                // Exposure summary
                exposureSummary
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.bottom, PulseSpacing.xs)
        }
    }

    private func capitalRow(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8))
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private func safetyTag(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(PulseColors.accent.opacity(0.7))
            .textCase(.uppercase)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(PulseColors.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(PulseColors.accent.opacity(0.1), lineWidth: 0.5)
            )
    }

    private var exposureSummary: some View {
        let exposure = viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt)
        let overBudget = exposure > viewModel.capitalConfig.totalBudgetValue
        let pct = viewModel.capitalConfig.totalBudgetValue > 0
            ? (exposure / viewModel.capitalConfig.totalBudgetValue * 100) : 0

        return HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: overBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)

            Text(L10n.LiveReadiness.maxExposure)
                .font(.system(size: 8))
                .foregroundStyle(colors.textMuted)

            Spacer()

            Text(String(format: "%.0f USDT", exposure))
                .font(PulseFonts.monoLabel)
                .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)

            Text(String(format: "(%.0f%%)", pct))
                .font(.system(size: 8))
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - Telemetry Panel Builder

    private func telemetryPanel<Content: View>(
        title: String,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                TerminalLabel(text: title)
                Spacer()
                if let trailing { trailing }
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)

            Divider().background(colors.border.opacity(0.15))

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - 4. Launch Command

    private var launchCommand: some View {
        LaunchConsoleView(
            blockingReasons: viewModel.data?.blockingReasons ?? [],
            canStartPaper: viewModel.data?.canStartPaper ?? false,
            canStartLiveSmall: viewModel.data?.canStartLiveSmall ?? false,
            canStartFullLive: viewModel.data?.canStartFullLive ?? false,
            onPaperTrade: {
                toastManager.info(L10n.zh("模拟交易功能尚未实现", en: "Paper trading not yet implemented"))
            },
            onGoLive: {
                viewModel.showLaunchConfirmation = true
            }
        )
    }

    // MARK: - Shared Helpers

    private var stateColor: Color {
        switch viewModel.data?.state ?? "" {
        case "LIVE_READY":          PulseColors.accent
        case "LIVE_SMALL_READY":    PulseColors.cyan
        case "PAPER_ONLY":          PulseColors.amber
        case "RISK_LOCKED":         PulseColors.danger
        case "EMERGENCY_LOCKED":    PulseColors.danger
        default:                    colors.textMuted
        }
    }

    private var stateLabel: String {
        switch viewModel.data?.state ?? "" {
        case "LIVE_READY":          L10n.LiveReadiness.liveReady
        case "LIVE_SMALL_READY":    L10n.LiveReadiness.liveSmallReady
        case "PAPER_ONLY":          L10n.LiveReadiness.paperOnly
        case "RISK_LOCKED":         L10n.LiveReadiness.riskLocked
        case "EMERGENCY_LOCKED":    L10n.LiveReadiness.emergencyLocked
        default:                    L10n.LiveReadiness.notReady
        }
    }

    private func checkStatusColor(_ status: String) -> Color {
        switch status {
        case "healthy":             PulseColors.accent
        case "warning":             PulseColors.amber
        case "critical", "failed":  PulseColors.danger
        default:                    colors.textMuted
        }
    }
}

// MARK: - Launch Confirmation Sheet

private struct LaunchConfirmationSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LiveReadinessViewModel
    @State private var confirmText = ""
    @State private var isLaunching = false

    private var requiredPhrase: String { L10n.LiveReadiness.confirmPhrase }

    var body: some View {
        VStack(spacing: PulseSpacing.lg) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PulseColors.amber.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PulseColors.amber)
                    .shadow(color: PulseColors.amber.opacity(0.3), radius: 8)
            }

            Text(L10n.LiveReadiness.confirmTitle)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
                .textCase(.uppercase)
                .tracking(1)

            // Capital summary
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                summaryRow(L10n.LiveReadiness.totalBudget, viewModel.capitalConfig.totalBudget + " USDT")
                summaryRow(L10n.LiveReadiness.stakePerTrade, viewModel.capitalConfig.stakeAmount + " USDT")
                summaryRow(L10n.LiveReadiness.maxOpenTrades, viewModel.capitalConfig.maxOpenTrades)
                summaryRow(
                    L10n.LiveReadiness.maxExposure,
                    String(format: "%.0f USDT", viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt))
                )
                summaryRow(L10n.LiveReadiness.maxDailyLoss, viewModel.capitalConfig.maxDailyLossPct + "%")
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface)
            )

            // Warning
            Text(L10n.LiveReadiness.confirmMessage)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.amber)
                .multilineTextAlignment(.center)
                .padding(PulseSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .fill(PulseColors.amber.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(PulseColors.amber.opacity(0.1), lineWidth: 0.5)
                )

            // Confirmation input
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("输入确认短语：", en: "Type confirmation phrase:"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textSecondary)

                Text("\"\(requiredPhrase)\"")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.amber)

                TextField("", text: $confirmText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(
                                confirmText == requiredPhrase
                                    ? PulseColors.accent.opacity(0.4)
                                    : colors.border.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }

            // Buttons
            HStack(spacing: PulseSpacing.md) {
                Button(L10n.zh("取消", en: "Cancel")) { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button {
                    isLaunching = true
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        isLaunching = false
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isLaunching {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(L10n.LiveReadiness.goLive)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .textCase(.uppercase)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PulseColors.accent)
                .controlSize(.regular)
                .disabled(confirmText != requiredPhrase || isLaunching)
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: 440)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }
}
