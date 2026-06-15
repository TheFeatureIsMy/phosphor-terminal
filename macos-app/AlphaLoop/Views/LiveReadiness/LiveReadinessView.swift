// LiveReadinessView.swift — 实盘准入 AI Safety Tribunal
// Editorial chapter layout matching MarketStructureView

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Environment(ToastManager.self) private var toastManager
    @Bindable var viewModel: LiveReadinessViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                pageHeader
                    .staggeredAppearance(index: 0)

                chapterVerdict
                    .staggeredAppearance(index: 1)

                chapterPreconditions
                    .staggeredAppearance(index: 2)

                chapterInfrastructure
                    .staggeredAppearance(index: 3)

                chapterCapital
                    .staggeredAppearance(index: 4)

                chapterLaunch
                    .staggeredAppearance(index: 5)
            }
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PulseSpacing.xl)
            .padding(.vertical, PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await viewModel.loadData() }
        .id(settingsState.language)
        .sheet(isPresented: $viewModel.showLaunchConfirmation) {
            LaunchConfirmationSheet(viewModel: viewModel)
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(alignment: .center, spacing: PulseSpacing.sm) {
                // Glyph badge
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(
                        LinearGradient(
                            colors: [stateColor.opacity(0.25), stateColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(stateColor.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("Ψ")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .italic()
                            .foregroundStyle(stateColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.zh("实盘准入", en: "Live Readiness"))
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(colors.textPrimary)
                    Text(L10n.zh("AI 安全评估", en: "AI SAFETY ASSESSMENT"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(stateColor.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(2)
                }

                Spacer()

                // State badge
                HStack(spacing: 6) {
                    stateLamp
                    Text(stateLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(stateColor)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(stateColor.opacity(0.12))
                )

                recheckButton
            }

            // Divider rule
            Rectangle()
                .fill(colors.border)
                .frame(height: 1)
                .padding(.top, PulseSpacing.xxs)
        }
    }

    @State private var lampPulse = false

    private var stateLamp: some View {
        Circle()
            .fill(stateColor)
            .frame(width: 8, height: 8)
            .shadow(color: stateColor.opacity(0.6), radius: lampPulse ? 6 : 2)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: lampPulse)
            .onAppear { lampPulse = true }
    }

    @State private var refreshSpin = false

    private var recheckButton: some View {
        Button {
            Task { await viewModel.runCheck() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .foregroundStyle(colors.textMuted)
                .rotationEffect(.degrees(viewModel.isChecking ? 360 : 0))
                .animation(
                    viewModel.isChecking
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: viewModel.isChecking
                )
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(PulseColors.accent.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isChecking)
    }

    // MARK: - I. VERDICT

    private var chapterVerdict: some View {
        chapterScaffold(
            numeral: "I",
            title: L10n.zh("评估结论", en: "VERDICT"),
            pose: L10n.zh("系统对实盘准入的综合判定", en: "the system's composite judgment on live readiness")
        ) {
            HStack(alignment: .top, spacing: PulseSpacing.xl) {
                // Left: Score ring
                ReadinessGaugeView(score: viewModel.data?.score ?? 0)

                // Right: State narrative + permissions
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    // State word (large, like regime word)
                    Text(stateLabel)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(stateColor)
                        .tracking(-1)

                    // Narrative description (serif italic)
                    Text(L10n.LiveReadiness.stateDescription(viewModel.data?.state ?? ""))
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(3)

                    // Permission meters
                    HStack(spacing: PulseSpacing.sm) {
                        permissionMeter(L10n.LiveReadiness.paper, enabled: viewModel.data?.canStartPaper ?? false)
                        permissionMeter(L10n.LiveReadiness.small, enabled: viewModel.data?.canStartLiveSmall ?? false)
                        permissionMeter(L10n.LiveReadiness.full, enabled: viewModel.data?.canStartFullLive ?? false)
                    }
                }
            }

            // Warnings
            let warnings = viewModel.data?.warnings ?? []
            if !warnings.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseColors.amber)
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, w in
                        Text("\u{201C}\(w["message"] ?? w["code"] ?? "")\u{201D}")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(PulseColors.amber.opacity(0.8))
                    }
                }
                .padding(PulseSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(PulseColors.amber.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .stroke(PulseColors.amber.opacity(0.12), lineWidth: 1)
                )
                .padding(.top, PulseSpacing.xs)
            }
        }
    }

    private func permissionMeter(_ label: String, enabled: Bool) -> some View {
        let meterColor = enabled ? PulseColors.accent : colors.textMuted

        return VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(enabled
                    ? L10n.zh("允许", en: "ALLOW")
                    : L10n.zh("禁止", en: "DENY"))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(meterColor)
            }

            // Mini bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    enabled
                        ? LinearGradient(colors: [meterColor.opacity(0.5), meterColor], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [colors.border.opacity(0.3), colors.border.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 4)
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // MARK: - II. PRECONDITIONS

    private var chapterPreconditions: some View {
        chapterScaffold(
            numeral: "II",
            title: L10n.zh("准入门禁", en: "PRECONDITIONS"),
            pose: L10n.zh("跨越实盘门槛前必须通过的七道检查", en: "seven gates that must clear before crossing the threshold")
        ) {
            GatePipelineView(gates: viewModel.strategyGates)
        }
    }

    // MARK: - III. INFRASTRUCTURE

    private var chapterInfrastructure: some View {
        chapterScaffold(
            numeral: "III",
            title: L10n.zh("基础设施", en: "INFRASTRUCTURE"),
            pose: L10n.zh("交易基础设施的生命体征", en: "the vital signs of the trading infrastructure")
        ) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                // System Health — meter tile grid
                systemHealthGrid

                // Risk Firewall
                riskFirewallSection
            }
        }
    }

    private var systemHealthGrid: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.LiveReadiness.systemHealth)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)

            let checks = viewModel.data?.checks ?? []
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: PulseSpacing.sm
            ) {
                ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                    healthMeterTile(check)
                }
            }
        }
    }

    private func healthMeterTile(_ check: ReadinessCheckResponse) -> some View {
        let color = checkStatusColor(check.status)

        return VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(check.label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(check.value)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                if !check.threshold.isEmpty {
                    Text(check.threshold)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.5), color],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // Risk Firewall

    private var riskFirewallSection: some View {
        Button {
            appState.selectedRoute = .riskCenter
        } label: {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    Text(L10n.LiveReadiness.riskFirewall)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(colors.textMuted)
                }

                // Three risk gauge bars
                riskBar(L10n.LiveReadiness.daily, used: viewModel.riskState.dailyLossUsed, limit: viewModel.riskState.dailyLossLimit, color: PulseColors.amber)
                riskBar(L10n.LiveReadiness.weekly, used: viewModel.riskState.weeklyLossUsed, limit: viewModel.riskState.weeklyLossLimit, color: PulseColors.cyan)
                riskBar(L10n.LiveReadiness.consecutive, used: viewModel.riskState.consecutiveLosses, limit: viewModel.riskState.consecutiveLimit, color: PulseColors.purple)

                Rectangle().fill(colors.border).frame(height: 1)

                // Status chips
                HStack(spacing: PulseSpacing.sm) {
                    chipBadge(
                        "\(L10n.LiveReadiness.killSwitch): \(viewModel.riskState.killSwitchActive ? L10n.zh("激活", en: "ON") : L10n.LiveReadiness.off)",
                        color: viewModel.riskState.killSwitchActive ? PulseColors.danger : PulseColors.accent
                    )
                    chipBadge(
                        "\(L10n.LiveReadiness.breaker): \(breakerLabel)",
                        color: breakerColor
                    )
                    Spacer()
                }
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(colors.surfaceHover.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func riskBar(_ label: String, used: Double, limit: Double, color: Color) -> some View {
        let ratio = limit > 0 ? min(used / limit, 1.0) : 0
        let isHot = ratio > 0.8
        let barColor = isHot ? PulseColors.danger : color

        return HStack(spacing: PulseSpacing.xs) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .frame(width: 48, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.border.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.5), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * ratio))
                        .shadow(color: barColor.opacity(isHot ? 0.4 : 0), radius: isHot ? 4 : 0)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.1f%%", ratio * 100))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(barColor)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private func chipBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .fill(color.opacity(0.12))
            )
    }

    private var breakerLabel: String {
        if viewModel.breakerState.shouldStop { return L10n.zh("触发", en: "TRIP") }
        if viewModel.breakerState.shouldCooldown { return L10n.zh("冷却", en: "COOL") }
        return L10n.LiveReadiness.normal
    }

    private var breakerColor: Color {
        if viewModel.breakerState.shouldStop { return PulseColors.danger }
        if viewModel.breakerState.shouldCooldown { return PulseColors.amber }
        return PulseColors.accent
    }

    // MARK: - IV. CAPITAL

    private var chapterCapital: some View {
        chapterScaffold(
            numeral: "IV",
            title: L10n.zh("资金配置", en: "CAPITAL"),
            pose: L10n.zh("投入的资源及其安全约束", en: "the resources committed and their safeguards")
        ) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // Capital meter tiles (2x2)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: PulseSpacing.sm
                ) {
                    capitalTile(
                        label: L10n.LiveReadiness.totalBudget,
                        value: viewModel.capitalConfig.totalBudget,
                        suffix: "USDT"
                    )
                    capitalTile(
                        label: L10n.LiveReadiness.stakePerTrade,
                        value: viewModel.capitalConfig.stakeAmount,
                        suffix: "USDT"
                    )
                    capitalTile(
                        label: L10n.LiveReadiness.maxOpenTrades,
                        value: viewModel.capitalConfig.maxOpenTrades,
                        suffix: ""
                    )
                    capitalTile(
                        label: L10n.LiveReadiness.maxDailyLoss,
                        value: viewModel.capitalConfig.maxDailyLossPct,
                        suffix: "%"
                    )
                }

                // Safety badges
                HStack(spacing: PulseSpacing.xs) {
                    chipBadge(L10n.LiveReadiness.noLeverage, color: PulseColors.accent)
                    chipBadge(L10n.LiveReadiness.spotOnly, color: PulseColors.accent)
                    chipBadge(L10n.LiveReadiness.humanConfirmRequired, color: PulseColors.accent)
                    chipBadge(L10n.LiveReadiness.autoTradeOff, color: PulseColors.accent)
                }

                // Exposure summary
                exposureSummary
            }
        }
    }

    private func capitalTile(label: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.textPrimary)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    private var exposureSummary: some View {
        let exposure = viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt)
        let overBudget = exposure > viewModel.capitalConfig.totalBudgetValue
        let pct = viewModel.capitalConfig.totalBudgetValue > 0
            ? (exposure / viewModel.capitalConfig.totalBudgetValue * 100) : 0
        let summaryColor = overBudget ? PulseColors.danger : PulseColors.accent

        return HStack(spacing: PulseSpacing.xs) {
            Image(systemName: overBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(summaryColor)
            Text(L10n.LiveReadiness.maxExposure)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(colors.textSecondary)
            Spacer()
            Text(String(format: "%.0f USDT", exposure))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(summaryColor)
            Text(String(format: "(%.0f%% %@)", pct, L10n.LiveReadiness.ofBudget))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(summaryColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(summaryColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - V. LAUNCH AUTHORIZATION

    private var chapterLaunch: some View {
        chapterScaffold(
            numeral: "V",
            title: L10n.zh("启动授权", en: "LAUNCH AUTHORIZATION"),
            pose: L10n.zh("最终授权决定", en: "the final authorization decision")
        ) {
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
    }

    // MARK: - Chapter Scaffold

    private func chapterScaffold<Content: View>(
        numeral: String,
        title: String,
        pose: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.sm) {
                Text(numeral)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(PulseColors.accent.opacity(0.8))
                    .frame(width: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PulseFonts.headline)
                        .foregroundStyle(colors.textPrimary)
                        .tracking(0.5)
                    Text("— \(pose)")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(colors.textMuted)
                }
            }

            content()
                .padding(.leading, 28 + PulseSpacing.sm)
        }
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
            // Warning glyph
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
                .font(.system(size: 18, weight: .bold, design: .serif))
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
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(colors.surfaceHover.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(colors.border, lineWidth: 1)
            )

            // Warning narrative
            Text("\u{201C}\\(L10n.LiveReadiness.confirmMessage)\u{201D}")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(PulseColors.amber)
                .multilineTextAlignment(.center)
                .padding(PulseSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(PulseColors.amber.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .stroke(PulseColors.amber.opacity(0.12), lineWidth: 1)
                )

            // Confirmation input
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("输入确认短语：", en: "Type confirmation phrase:"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textSecondary)

                Text("\u{201C}\\(requiredPhrase)\u{201D}")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseColors.amber)

                TextField("", text: $confirmText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(colors.surfaceHover.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(
                                confirmText == requiredPhrase
                                    ? PulseColors.accent.opacity(0.4)
                                    : colors.border,
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
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }
}
