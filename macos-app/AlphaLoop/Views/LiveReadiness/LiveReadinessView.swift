// LiveReadinessView.swift — 实盘准入「发射控制台」

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: LiveReadinessViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                commandHeader
                systemHealthPanel
                strategyGatePipeline
                riskAndBreakerSummary
                capitalConfigPanel
                launchSequence
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await viewModel.loadData() }
    }

    // MARK: - 1. Command Header

    private var commandHeader: some View {
        HStack(spacing: PulseSpacing.lg) {
            ZStack {
                Circle().stroke(colors.border.opacity(0.3), lineWidth: 4).frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.data?.score ?? 0) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.4), radius: 8)
                VStack(spacing: 1) {
                    Text("\(viewModel.data?.score ?? 0)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(scoreColor)
                    Text(L10n.zh("分数", en: "SCORE"))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.textMuted)
                }
            }

            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: 6) {
                    Circle().fill(stateColor).frame(width: 8, height: 8)
                        .shadow(color: stateColor.opacity(0.6), radius: 4)
                    Text(stateLabel)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(stateColor)
                }
                Text(stateDescription)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: PulseSpacing.sm) {
                    permBadge(L10n.zh("模拟", en: "PAPER"), allowed: viewModel.data?.canStartPaper ?? false)
                    permBadge(L10n.zh("小仓", en: "SMALL"), allowed: viewModel.data?.canStartLiveSmall ?? false)
                    permBadge(L10n.zh("全仓", en: "FULL"), allowed: viewModel.data?.canStartFullLive ?? false)
                }
            }
            Spacer()

            Button {
                Task { await viewModel.runCheck() }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.isChecking {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                    }
                    Text(L10n.zh("重新检查", en: "RE-CHECK"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(PulseColors.cyan)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(PulseColors.cyan.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(PulseColors.cyan.opacity(0.2), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isChecking)
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(stateColor.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - 2. System Health

    private var systemHealthPanel: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            secTitle(L10n.zh("系统健康", en: "SYSTEM HEALTH"), icon: "server.rack", sub: L10n.zh("基础设施健康检查", en: "Infrastructure Health"))
            let checks = viewModel.data?.checks ?? []
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: PulseSpacing.xs) {
                ForEach(Array(checks.enumerated()), id: \.offset) { i, check in
                    sysCheckCell(check).staggeredAppearance(index: i)
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(panel)
    }

    private func sysCheckCell(_ c: ReadinessCheckResponse) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(chkColor(c.status)).frame(width: 6, height: 6)
                    .shadow(color: chkColor(c.status).opacity(0.5), radius: 3)
                Text(c.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }
            Text(c.value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(chkColor(c.status))
            if !c.threshold.isEmpty {
                Text(c.threshold)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(chkColor(c.status).opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(chkColor(c.status).opacity(0.1), lineWidth: 0.5))
        )
    }

    // MARK: - 3. Strategy 7-Gate Pipeline

    private var strategyGatePipeline: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            secTitle(L10n.zh("策略准入门", en: "STRATEGY GATES"), icon: "shield.checkered", sub: L10n.zh("7 门准入检查", en: "7-Gate Precondition Check"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.strategyGates.enumerated()), id: \.element.id) { i, gate in
                        gateNode(gate, index: i + 1)
                        if i < viewModel.strategyGates.count - 1 {
                            gateConn(passed: gate.passed)
                        }
                    }
                }
                .padding(.horizontal, PulseSpacing.xs)
            }

            if let failed = viewModel.strategyGates.first(where: { !$0.passed }) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(PulseColors.danger)
                    Text(failed.remedy)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger.opacity(0.8))
                }
                .padding(PulseSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(PulseColors.danger.opacity(0.06)))
            }
        }
        .padding(PulseSpacing.md)
        .background(panel)
    }

    private func gateNode(_ gate: StrategyGate, index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(gate.passed ? PulseColors.accent.opacity(0.1) : PulseColors.danger.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(gate.passed ? PulseColors.accent.opacity(0.3) : PulseColors.danger.opacity(0.2), lineWidth: 0.5))
                    .frame(width: 36, height: 36)
                    .shadow(color: (gate.passed ? PulseColors.accent : PulseColors.danger).opacity(0.2), radius: 4)
                Image(systemName: gate.passed ? "checkmark" : "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gate.passed ? PulseColors.accent : PulseColors.danger)
            }
            Text(gate.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(gate.passed ? colors.textPrimary : PulseColors.danger.opacity(0.8))
                .lineLimit(1)
        }
        .frame(width: 72)
    }

    private func gateConn(passed: Bool) -> some View {
        Rectangle()
            .fill(passed ? PulseColors.accent.opacity(0.3) : colors.border.opacity(0.3))
            .frame(width: 16, height: 1.5)
            .offset(y: -10)
    }

    // MARK: - 4. Risk & Breaker Summary (compact — details in Risk Center)

    private var riskAndBreakerSummary: some View {
        HStack(spacing: PulseSpacing.sm) {
            // Risk Firewall summary
            Button { appState.selectedRoute = .riskCenter } label: {
                HStack(spacing: PulseSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(riskSummaryColor.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(riskSummaryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("风控防火墙", en: "Risk Firewall"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(colors.textPrimary)
                        Text(riskSummaryText)
                            .font(.system(size: 9))
                            .foregroundStyle(riskSummaryColor)
                    }

                    Spacer()

                    // Mini gauges
                    HStack(spacing: 8) {
                        miniGauge(L10n.zh("日", en: "D"), ratio: viewModel.riskState.dailyLossLimit > 0 ? viewModel.riskState.dailyLossUsed / viewModel.riskState.dailyLossLimit : 0, color: PulseColors.amber)
                        miniGauge(L10n.zh("周", en: "W"), ratio: viewModel.riskState.weeklyLossLimit > 0 ? viewModel.riskState.weeklyLossUsed / viewModel.riskState.weeklyLossLimit : 0, color: PulseColors.cyan)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.textMuted)
                }
                .padding(PulseSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(riskSummaryColor.opacity(0.15), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)

            // Circuit Breaker summary
            Button { appState.selectedRoute = .circuitBreakers } label: {
                HStack(spacing: PulseSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(breakerSummaryColor.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(breakerSummaryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("熔断器", en: "Breaker"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(colors.textPrimary)
                        Text(breakerSummaryText)
                            .font(.system(size: 9))
                            .foregroundStyle(breakerSummaryColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.textMuted)
                }
                .padding(PulseSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(breakerSummaryColor.opacity(0.15), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func miniGauge(_ label: String, ratio: Double, color: Color) -> some View {
        let r = min(ratio, 1.0)
        let danger = r > 0.8
        return VStack(spacing: 1) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.border.opacity(0.2))
                    .frame(width: 12, height: 20)
                RoundedRectangle(cornerRadius: 2)
                    .fill(danger ? PulseColors.danger : color)
                    .frame(width: 12, height: max(1, 20 * r))
            }
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(colors.textMuted)
        }
    }

    private var riskSummaryColor: Color {
        if viewModel.riskState.killSwitchActive { return PulseColors.danger }
        let maxRatio = max(
            viewModel.riskState.dailyLossLimit > 0 ? viewModel.riskState.dailyLossUsed / viewModel.riskState.dailyLossLimit : 0,
            viewModel.riskState.weeklyLossLimit > 0 ? viewModel.riskState.weeklyLossUsed / viewModel.riskState.weeklyLossLimit : 0
        )
        if maxRatio > 0.8 { return PulseColors.danger }
        if maxRatio > 0.5 { return PulseColors.amber }
        return PulseColors.accent
    }

    private var riskSummaryText: String {
        if viewModel.riskState.killSwitchActive { return L10n.zh("紧急停止已激活", en: "Kill switch active") }
        return L10n.zh("正常 — 点击查看详情", en: "Normal — tap for details")
    }

    private var breakerSummaryColor: Color {
        if viewModel.breakerState.shouldStop { return PulseColors.danger }
        if viewModel.breakerState.shouldCooldown { return PulseColors.amber }
        return PulseColors.accent
    }

    private var breakerSummaryText: String {
        if viewModel.breakerState.shouldStop { return L10n.zh("已触发 — 交易暂停", en: "Tripped — trading paused") }
        if viewModel.breakerState.shouldCooldown { return L10n.zh("冷却中", en: "Cooldown active") }
        return L10n.zh("正常 — 点击查看详情", en: "Normal — tap for details")
    }

    // MARK: - 6. Capital Pool Configuration

    private var capitalConfigPanel: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            secTitle(L10n.zh("资金配置", en: "CAPITAL POOL"), icon: "banknote.fill", sub: L10n.zh("实盘资金与风控参数", en: "Live Capital & Risk Parameters"))

            HStack(spacing: PulseSpacing.md) {
                VStack(spacing: PulseSpacing.sm) {
                    configField(
                        label: L10n.zh("总预算 (USDT)", en: "Total Budget (USDT)"),
                        value: $viewModel.capitalConfig.totalBudget,
                        icon: "dollarsign.circle",
                        hint: L10n.zh("用于实盘的总资金量", en: "Total capital for live trading")
                    )
                    configField(
                        label: L10n.zh("单笔仓位 (USDT)", en: "Stake Per Trade (USDT)"),
                        value: $viewModel.capitalConfig.stakeAmount,
                        icon: "chart.bar",
                        hint: L10n.zh("每笔交易的最大金额", en: "Max amount per trade")
                    )
                }

                VStack(spacing: PulseSpacing.sm) {
                    configField(
                        label: L10n.zh("最大交易数", en: "Max Open Trades"),
                        value: $viewModel.capitalConfig.maxOpenTrades,
                        icon: "square.stack.3d.up",
                        hint: L10n.zh("同时持有的最大仓位数", en: "Max simultaneous positions")
                    )
                    configField(
                        label: L10n.zh("日最大亏损 (%)", en: "Max Daily Loss (%)"),
                        value: $viewModel.capitalConfig.maxDailyLossPct,
                        icon: "arrow.down.circle",
                        hint: L10n.zh("触发熔断的日亏损百分比", en: "Daily loss % to trigger circuit breaker")
                    )
                }
            }

            // Safety constraints (read-only)
            HStack(spacing: PulseSpacing.lg) {
                safetyBadge(L10n.zh("禁止杠杆", en: "No Leverage"), icon: "xmark.shield", active: true)
                safetyBadge(L10n.zh("禁止自动交易", en: "No Auto-trade"), icon: "hand.raised", active: true)
                safetyBadge(L10n.zh("需人工确认", en: "Human Confirm"), icon: "person.badge.key", active: true)
                safetyBadge(L10n.zh("仅限现货", en: "Spot Only"), icon: "banknote", active: true)
            }

            // Exposure calculation
            let exposure = viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt)
            let overBudget = exposure > viewModel.capitalConfig.totalBudgetValue
            HStack(spacing: 6) {
                Image(systemName: overBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)
                Text(L10n.zh("最大敞口", en: "Max Exposure"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colors.textSecondary)
                Text(String(format: "%.0f USDT", exposure))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(overBudget ? PulseColors.danger : PulseColors.accent)
                if overBudget {
                    Text(L10n.zh("超出预算！", en: "Over budget!"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PulseColors.danger)
                }
                Spacer()
                Text(String(format: "%.1f%%", viewModel.capitalConfig.totalBudgetValue > 0 ? (exposure / viewModel.capitalConfig.totalBudgetValue * 100) : 0) + L10n.zh(" 预算占比", en: " of budget"))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(PulseSpacing.xs)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(overBudget ? PulseColors.danger.opacity(0.06) : PulseColors.accent.opacity(0.04)))
        }
        .padding(PulseSpacing.md)
        .background(panel)
    }

    private func configField(label: String, value: Binding<String>, icon: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10)).foregroundStyle(PulseColors.cyan)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(colors.textSecondary)
            }
            TextField("", text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 0.5))
                )
            Text(hint).font(.system(size: 8)).foregroundStyle(colors.textMuted)
        }
    }

    private func safetyBadge(_ label: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(active ? PulseColors.accent : colors.textMuted)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 4).fill(PulseColors.accent.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 4).stroke(PulseColors.accent.opacity(0.15), lineWidth: 0.5)))
    }

    // MARK: - 7. Launch Sequence

    private var launchSequence: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            secTitle(L10n.zh("启动序列", en: "LAUNCH SEQUENCE"), icon: "arrow.up.circle.fill", sub: L10n.zh("实盘启动确认", en: "Go-Live Confirmation"))

            let blocking = viewModel.data?.blockingReasons ?? []
            if !blocking.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blocking.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(PulseColors.danger)
                            Text("\(r["code"] ?? ""): \(r["message"] ?? "")")
                                .font(PulseFonts.caption).foregroundStyle(PulseColors.danger.opacity(0.8))
                        }
                    }
                }
                .padding(PulseSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(PulseColors.danger.opacity(0.06)))
            }

            HStack(spacing: PulseSpacing.md) {
                Spacer()
                Button {
                    // TODO: start paper
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text").font(.system(size: 11))
                        Text(L10n.zh("模拟交易", en: "PAPER TRADE"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(PulseColors.cyan)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.cyan.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(PulseColors.cyan.opacity(0.2), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!(viewModel.data?.canStartPaper ?? false))
                .opacity(viewModel.data?.canStartPaper ?? false ? 1 : 0.4)

                Button {
                    viewModel.showLaunchConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 11))
                        Text(L10n.zh("小仓实盘", en: "LIVE SMALL"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(LinearGradient(colors: [PulseColors.accent, PulseColors.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: PulseColors.accent.opacity(0.4), radius: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!(viewModel.data?.canStartLiveSmall ?? false))
                .opacity(viewModel.data?.canStartLiveSmall ?? false ? 1 : 0.4)
            }
        }
        .padding(PulseSpacing.md)
        .background(panel)
        .sheet(isPresented: $viewModel.showLaunchConfirmation) {
            LaunchConfirmationSheet(viewModel: viewModel)
        }
    }

    // MARK: - Helpers

    private func secTitle(_ t: String, icon: String, sub: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(PulseColors.accent).shadow(color: PulseColors.accent.opacity(0.4), radius: 3)
            Text(t).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(colors.textPrimary)
            Text("—").font(.system(size: 9)).foregroundStyle(colors.textMuted)
            Text(sub).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            Spacer()
        }
    }

    private func permBadge(_ label: String, allowed: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle").font(.system(size: 9))
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(allowed ? PulseColors.accent : colors.textMuted)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill((allowed ? PulseColors.accent : colors.textMuted).opacity(0.08)))
    }

    private var scoreColor: Color {
        let s = viewModel.data?.score ?? 0
        return s >= 80 ? PulseColors.accent : s >= 50 ? PulseColors.amber : PulseColors.danger
    }

    private var stateColor: Color {
        switch viewModel.data?.state ?? "" {
        case "LIVE_READY": PulseColors.accent
        case "LIVE_SMALL_READY": PulseColors.cyan
        case "PAPER_ONLY": PulseColors.amber
        case "RISK_LOCKED", "EMERGENCY_LOCKED": PulseColors.danger
        default: colors.textMuted
        }
    }

    private var stateLabel: String {
        switch viewModel.data?.state ?? "" {
        case "LIVE_READY": L10n.zh("实盘就绪", en: "LIVE READY")
        case "LIVE_SMALL_READY": L10n.zh("小仓就绪", en: "LIVE SMALL READY")
        case "PAPER_ONLY": L10n.zh("仅模拟", en: "PAPER ONLY")
        case "RISK_LOCKED": L10n.zh("风控锁定", en: "RISK LOCKED")
        case "EMERGENCY_LOCKED": L10n.zh("紧急锁定", en: "EMERGENCY")
        default: L10n.zh("未就绪", en: "NOT READY")
        }
    }

    private var stateDescription: String {
        switch viewModel.data?.state ?? "" {
        case "LIVE_READY": L10n.zh("所有系统就绪，可启动全仓实盘", en: "All systems go, full live available")
        case "LIVE_SMALL_READY": L10n.zh("系统健康，可启动小仓实盘", en: "Systems healthy, small-size live available")
        case "PAPER_ONLY": L10n.zh("仅允许模拟交易", en: "Paper trading only")
        case "RISK_LOCKED": L10n.zh("风控锁定，禁止实盘", en: "Risk locked, live disabled")
        case "EMERGENCY_LOCKED": L10n.zh("紧急锁定", en: "Emergency locked")
        default: L10n.zh("系统未就绪", en: "System not ready")
        }
    }

    private func chkColor(_ s: String) -> Color {
        switch s {
        case "healthy": PulseColors.accent
        case "warning": PulseColors.amber
        case "critical", "failed": PulseColors.danger
        default: colors.textMuted
        }
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .fill(colors.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 0.5))
    }
}

// MARK: - Launch Confirmation Sheet

private struct LaunchConfirmationSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LiveReadinessViewModel
    @State private var confirmText = ""
    @State private var isLaunching = false

    private let requiredPhrase = "I confirm live trading"

    var body: some View {
        VStack(spacing: PulseSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(PulseColors.amber)
                .shadow(color: PulseColors.amber.opacity(0.4), radius: 8)

            Text(L10n.zh("实盘交易确认", en: "Live Trading Confirmation"))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)

            // Capital summary
            VStack(alignment: .leading, spacing: 6) {
                summaryRow(L10n.zh("总预算", en: "Budget"), viewModel.capitalConfig.totalBudget + " USDT")
                summaryRow(L10n.zh("单笔仓位", en: "Stake"), viewModel.capitalConfig.stakeAmount + " USDT")
                summaryRow(L10n.zh("最大交易数", en: "Max Trades"), viewModel.capitalConfig.maxOpenTrades)
                summaryRow(L10n.zh("最大敞口", en: "Max Exposure"), String(format: "%.0f USDT", viewModel.capitalConfig.stakeAmountValue * Double(viewModel.capitalConfig.maxOpenTradesInt)))
                summaryRow(L10n.zh("日最大亏损", en: "Max Daily Loss"), viewModel.capitalConfig.maxDailyLossPct + "%")
            }
            .padding(PulseSpacing.sm)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(PulseColors.cyan.opacity(0.04)))

            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                warnLine(L10n.zh("此操作将使用真实资金进行交易", en: "This will trade with REAL money"))
                warnLine(L10n.zh("亏损不可逆转", en: "Losses are irreversible"))
                warnLine(L10n.zh("请确保已完成回测和模拟验证", en: "Ensure backtesting and paper are done"))
            }
            .padding(PulseSpacing.md)
            .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(PulseColors.amber.opacity(0.06)))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.zh("请输入确认短语：", en: "Type confirmation phrase:"))
                    .font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                Text("\"\(requiredPhrase)\"")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseColors.amber)
                TextField("", text: $confirmText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(PulseSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(confirmText == requiredPhrase ? PulseColors.accent.opacity(0.5) : colors.border, lineWidth: 1))
            }

            HStack(spacing: PulseSpacing.md) {
                Button(L10n.zh("取消", en: "Cancel")) { dismiss() }
                    .buttonStyle(.bordered).controlSize(.regular)
                Button {
                    isLaunching = true
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        isLaunching = false
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isLaunching { ProgressView().controlSize(.mini) }
                        else { Image(systemName: "bolt.fill") }
                        Text(L10n.zh("启动实盘", en: "GO LIVE"))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                }
                .buttonStyle(.borderedProminent).tint(PulseColors.accent).controlSize(.regular)
                .disabled(confirmText != requiredPhrase || isLaunching)
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: 440)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(colors.textMuted).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }

    private func warnLine(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(PulseColors.amber)
            Text(text).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
        }
    }
}
