// LiveReadinessView.swift — 实盘准入「工业控制室」
// Rewritten: 3-zone layout using ReadinessGaugeView, GatePipelineView, LaunchConsoleView

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Environment(ToastManager.self) private var toastManager
    @Bindable var viewModel: LiveReadinessViewModel

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                mastheadCard
                    .staggeredAppearance(index: 0)

                twoColumnBody
                    .staggeredAppearance(index: 1)

                launchConsole
                    .staggeredAppearance(index: 2)
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await viewModel.loadData() }
        .id(settingsState.language)
        .sheet(isPresented: $viewModel.showLaunchConfirmation) {
            LaunchConfirmationSheet(viewModel: viewModel)
        }
    }

    // MARK: - 1. Masthead

    private var mastheadCard: some View {
        KryptonCard(emphasis: .bold) {
            HStack(spacing: PulseSpacing.lg) {
                // Left: Gauge
                ReadinessGaugeView(score: viewModel.data?.score ?? 0)
                    .frame(width: 180)
                    .padding(.vertical, PulseSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(colors.surfaceElevated)
                    )

                // Center: State info
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    // State lamp + label
                    HStack(spacing: PulseSpacing.xs) {
                        stateLamp
                        Text(stateLabel)
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(stateColor)
                    }

                    // Description
                    Text(L10n.LiveReadiness.stateDescription(viewModel.data?.state ?? ""))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(3)

                    // Permission toggles
                    HStack(spacing: PulseSpacing.sm) {
                        permissionIndicator(L10n.LiveReadiness.paper, enabled: viewModel.data?.canStartPaper ?? false)
                        permissionIndicator(L10n.LiveReadiness.small, enabled: viewModel.data?.canStartLiveSmall ?? false)
                        permissionIndicator(L10n.LiveReadiness.full, enabled: viewModel.data?.canStartFullLive ?? false)
                    }
                }

                Spacer(minLength: PulseSpacing.md)

                // Right: Re-check button
                Button {
                    Task { await viewModel.runCheck() }
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        if viewModel.isChecking {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        Text(L10n.LiveReadiness.recheck)
                            .font(PulseFonts.monoLabel)
                    }
                    .foregroundStyle(PulseColors.accent)
                    .padding(.horizontal, PulseSpacing.sm)
                    .padding(.vertical, PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.accent.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(PulseColors.accent.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isChecking)
            }
        }
    }

    // MARK: - Masthead Helpers

    @State private var lampPulse = false

    private var stateLamp: some View {
        Circle()
            .fill(stateColor)
            .frame(width: 14, height: 14)
            .shadow(color: stateColor.opacity(0.6), radius: lampPulse ? 8 : 3)
            .scaleEffect(lampPulse ? 1.15 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: lampPulse
            )
            .onAppear { lampPulse = true }
    }

    private func permissionIndicator(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: enabled ? "circle.circle.fill" : "circle.circle")
                .font(.system(size: 10))
            Text(label)
                .font(PulseFonts.micro)
        }
        .foregroundStyle(enabled ? PulseColors.accent : PulseColors.danger)
    }

    // MARK: - 2. Two-Column Body

    private var twoColumnBody: some View {
        HStack(alignment: .top, spacing: PulseSpacing.lg) {
            // Left column: Gate pipeline (fixed 380px)
            GatePipelineView(gates: viewModel.strategyGates)
                .frame(width: 380)

            // Right column: stacked panels
            VStack(spacing: PulseSpacing.lg) {
                systemHealthPanel
                riskFirewallPanel
                capitalReadoutPanel
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - System Health (3x2 grid)

    private var systemHealthPanel: some View {
        KryptonCard(emphasis: .subtle, cardPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    TerminalLabel(text: L10n.LiveReadiness.systemHealth)
                    Spacer()
                }
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.sm)

                Divider().background(colors.border)

                let checks = viewModel.data?.checks ?? []
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3),
                    spacing: 0
                ) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { index, check in
                        healthCell(check)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    private func healthCell(_ check: ReadinessCheckResponse) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            HStack(spacing: 4) {
                Circle()
                    .fill(checkStatusColor(check.status))
                    .frame(width: 6, height: 6)
                    .shadow(color: checkStatusColor(check.status).opacity(0.5), radius: 3)
                Text(check.label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }

            Text(check.value)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(checkStatusColor(check.status))

            if !check.threshold.isEmpty {
                Text(check.threshold)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.sm)
        .padding(.horizontal, PulseSpacing.xs)
        .background(
            checkStatusColor(check.status).opacity(0.03)
        )
        .overlay(
            Rectangle()
                .fill(colors.border.opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Risk Firewall

    private var riskFirewallPanel: some View {
        Button {
            appState.selectedRoute = .riskCenter
        } label: {
            KryptonCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    // Header
                    HStack {
                        TerminalLabel(text: L10n.LiveReadiness.riskFirewall)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(colors.textMuted)
                    }

                    // Three gauge bars
                    riskGaugeBar(
                        label: L10n.LiveReadiness.daily,
                        used: viewModel.riskState.dailyLossUsed,
                        limit: viewModel.riskState.dailyLossLimit,
                        color: PulseColors.amber
                    )
                    riskGaugeBar(
                        label: L10n.LiveReadiness.weekly,
                        used: viewModel.riskState.weeklyLossUsed,
                        limit: viewModel.riskState.weeklyLossLimit,
                        color: PulseColors.cyan
                    )
                    riskGaugeBar(
                        label: L10n.LiveReadiness.consecutive,
                        used: viewModel.riskState.consecutiveLosses,
                        limit: viewModel.riskState.consecutiveLimit,
                        color: PulseColors.purple
                    )

                    Divider().background(colors.border)

                    // Kill Switch + Breaker status chips
                    HStack(spacing: PulseSpacing.sm) {
                        statusChip(
                            label: L10n.LiveReadiness.killSwitch,
                            value: viewModel.riskState.killSwitchActive
                                ? L10n.zh("已激活", en: "ACTIVE")
                                : L10n.LiveReadiness.off,
                            color: viewModel.riskState.killSwitchActive
                                ? PulseColors.danger : PulseColors.accent
                        )
                        statusChip(
                            label: L10n.LiveReadiness.breaker,
                            value: breakerStatusLabel,
                            color: breakerStatusColor
                        )
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func riskGaugeBar(label: String, used: Double, limit: Double, color: Color) -> some View {
        let ratio = limit > 0 ? min(used / limit, 1.0) : 0
        let isHot = ratio > 0.8
        let barColor = isHot ? PulseColors.danger : color

        return HStack(spacing: PulseSpacing.xs) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.border.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: max(2, geo.size.width * ratio))
                        .shadow(color: barColor.opacity(0.4), radius: isHot ? 4 : 0)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.1f%%", ratio * 100))
                .font(PulseFonts.micro)
                .foregroundStyle(barColor)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private func statusChip(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
            Text(value)
                .font(PulseFonts.micro)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var breakerStatusLabel: String {
        if viewModel.breakerState.shouldStop { return L10n.zh("已触发", en: "TRIPPED") }
        if viewModel.breakerState.shouldCooldown { return L10n.zh("冷却中", en: "COOLDOWN") }
        return L10n.LiveReadiness.normal
    }

    private var breakerStatusColor: Color {
        if viewModel.breakerState.shouldStop { return PulseColors.danger }
        if viewModel.breakerState.shouldCooldown { return PulseColors.amber }
        return PulseColors.accent
    }

    // MARK: - Capital Readout

    private var capitalReadoutPanel: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.LiveReadiness.capitalPool)

                // 2x2 readout grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: PulseSpacing.sm
                ) {
                    readoutCell(
                        label: L10n.LiveReadiness.totalBudget,
                        value: viewModel.capitalConfig.totalBudget,
                        unit: "USDT",
                        icon: "dollarsign.circle"
                    )
                    readoutCell(
                        label: L10n.LiveReadiness.stakePerTrade,
                        value: viewModel.capitalConfig.stakeAmount,
                        unit: "USDT",
                        icon: "chart.bar"
                    )
                    readoutCell(
                        label: L10n.LiveReadiness.maxOpenTrades,
                        value: viewModel.capitalConfig.maxOpenTrades,
                        unit: "",
                        icon: "square.stack.3d.up"
                    )
                    readoutCell(
                        label: L10n.LiveReadiness.maxDailyLoss,
                        value: viewModel.capitalConfig.maxDailyLossPct,
                        unit: "%",
                        icon: "arrow.down.circle"
                    )
                }

                Divider().background(colors.border)

                // Safety badges row
                HStack(spacing: PulseSpacing.xs) {
                    safetyBadge(L10n.LiveReadiness.noLeverage, icon: "xmark.shield")
                    safetyBadge(L10n.LiveReadiness.spotOnly, icon: "banknote")
                    safetyBadge(L10n.LiveReadiness.humanConfirmRequired, icon: "person.badge.key")
                    safetyBadge(L10n.LiveReadiness.autoTradeOff, icon: "hand.raised")
                    Spacer()
                }

                // Exposure summary
                exposureSummary
            }
        }
    }

    private func readoutCell(label: String, value: String, unit: String, icon: String) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(PulseColors.cyan)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(PulseFonts.tabular)
                        .foregroundStyle(colors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
        }
        .padding(PulseSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface)
        )
    }

    private func safetyBadge(_ label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(PulseFonts.micro)
        }
        .foregroundStyle(PulseColors.accent)
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(PulseColors.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(PulseColors.accent.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var exposureSummary: some View {
        let exposure = viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt)
        let overBudget = exposure > viewModel.capitalConfig.totalBudgetValue
        let pct = viewModel.capitalConfig.totalBudgetValue > 0
            ? (exposure / viewModel.capitalConfig.totalBudgetValue * 100) : 0

        return HStack(spacing: PulseSpacing.xs) {
            Image(systemName: overBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)

            Text(L10n.LiveReadiness.maxExposure)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)

            Text(String(format: "%.0f USDT", exposure))
                .font(PulseFonts.monoLabel)
                .fontWeight(.bold)
                .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)

            Spacer()

            Text(String(format: "%.1f%% %@", pct, L10n.LiveReadiness.ofBudget))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(overBudget ? PulseColors.danger.opacity(0.06) : PulseColors.accent.opacity(0.04))
        )
    }

    // MARK: - 3. Launch Console

    private var launchConsole: some View {
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(PulseColors.amber)
                .shadow(color: PulseColors.amber.opacity(0.4), radius: 8)

            // Title
            Text(L10n.LiveReadiness.confirmTitle)
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

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
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(PulseColors.cyan.opacity(0.04))
            )

            // Warning message
            Text(L10n.LiveReadiness.confirmMessage)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.amber)
                .multilineTextAlignment(.center)
                .padding(PulseSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(PulseColors.amber.opacity(0.06))
                )

            // Confirmation phrase input
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("请输入确认短语：", en: "Type confirmation phrase:"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)

                Text("\"\(requiredPhrase)\"")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.amber)

                TextField("", text: $confirmText)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.body)
                    .padding(PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(
                                confirmText == requiredPhrase
                                    ? PulseColors.accent.opacity(0.5)
                                    : colors.border,
                                lineWidth: 1
                            )
                    )
            }

            // Buttons
            HStack(spacing: PulseSpacing.md) {
                Button(L10n.zh("取消", en: "Cancel")) {
                    dismiss()
                }
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
                            .font(PulseFonts.monoLabel)
                            .fontWeight(.bold)
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
                .fontWeight(.semibold)
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }
}
