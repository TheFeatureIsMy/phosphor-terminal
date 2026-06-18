// LiveReadinessView.swift — 实盘准入控制台（一屏可判断）
//
// 单一 ScrollView 容纳 4 个功能区，无分页 / 无章节：
//   HEADER  — 标题 + 5 级总状态徽章 + 重新检查按钮
//   SELECT  — 模式 / 策略 / 资金 / 交易所 选择器（4 列）
//   GATES   — 11 项门禁（按 group 分两列：mode/strategy/capital/risk | system/execution）
//   CONTEXT — 上下文摘要：通知 / AI 模型 / 数据源 / 交易所 / freqtrade / redis / 风险
//   LAUNCH  — 启动授权：3 个按钮（模拟 / 小仓 / 全仓）+ 阻断项列表
//
// 启动流程（防误触）：
//   1) 按钮点击 → sheet 弹出
//   2) Step 1: 阅读启动摘要
//   3) Step 2: 勾选 "我已理解" 确认
//   4) Step 3: 输入确认短语 "I confirm live trading"
//   5) 真实调用 APIEmergency.emergencyStop（占位）+ 重新拉取 BFF

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Bindable var viewModel: LiveReadinessViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                pageHeader
                    .staggeredAppearance(index: 0)
                selectionPanel
                    .staggeredAppearance(index: 1)
                gatesPanel
                    .staggeredAppearance(index: 2)
                contextPanel
                    .staggeredAppearance(index: 3)
                launchPanel
                    .staggeredAppearance(index: 4)
                Spacer().frame(height: PulseSpacing.lg)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaPadding(.top, PulseSpacing.xxs)
        .task {
            await viewModel.loadData()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .id(settingsState.language)
        .sheet(isPresented: $viewModel.showLaunchConfirmation) {
            LaunchTripleConfirmSheet(viewModel: viewModel)
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xs) {
                    Text("//")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.LiveReadiness.pageHeader)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)
                        .tracking(0.5)
                    grandStatusBadge
                }
                Text(L10n.LiveReadiness.pageSubtitle)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            recheckButton
        }
    }

    private var grandStatusBadge: some View {
        let key = viewModel.data?.grandStatus ?? "not_live"
        let label = L10n.LiveReadiness.grandStatusLabel(key)
        let color = grandStatusColor(key)
        return Text(label)
            .font(PulseFonts.micro)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.10))
            )
            .overlay(
                Capsule().stroke(color.opacity(0.30), lineWidth: 0.7)
            )
    }

    private func grandStatusColor(_ key: String) -> Color {
        switch key {
        case "ready_for_live": return PulseColors.accent
        case "paper_passed": return PulseColors.cyan
        case "needs_validation": return PulseColors.amber
        case "needs_config": return PulseColors.warning
        case "not_live": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private var recheckButton: some View {
        Button {
            Task { await viewModel.runCheck() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(viewModel.isChecking ? 360 : 0))
                    .animation(
                        viewModel.isChecking
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.isChecking
                    )
                Text(L10n.LiveReadiness.recheck)
                    .font(PulseFonts.micro)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(PulseColors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(PulseColors.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(PulseColors.accent.opacity(0.30), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isChecking)
    }

    // MARK: - Selection Panel (4 columns)

    private var selectionPanel: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.LiveReadiness.selectTitle)

                HStack(spacing: 10) {
                    selector(
                        label: L10n.LiveReadiness.modeLabel,
                        current: currentModeLabel,
                        options: modeOptions,
                        onSelect: { viewModel.setMode($0) }
                    )
                    selector(
                        label: L10n.LiveReadiness.strategyLabel,
                        current: currentStrategyLabel,
                        options: viewModel.data?.availableStrategies ?? [],
                        onSelect: { viewModel.setStrategy($0) }
                    )
                    selector(
                        label: L10n.LiveReadiness.capitalLabel,
                        current: currentPoolLabel,
                        options: viewModel.data?.availableCapitalPools ?? [],
                        onSelect: { viewModel.setCapitalPool($0) }
                    )
                    selector(
                        label: L10n.LiveReadiness.exchangeLabel,
                        current: currentExchangeLabel,
                        options: viewModel.data?.availableExchanges ?? [],
                        onSelect: { viewModel.setExchange($0) }
                    )
                }
            }
        }
    }

    private var modeOptions: [ReadinessOption] {
        [
            ReadinessOption(key: "paper", name: L10n.LiveReadiness.modePaper, kind: nil, detail: nil),
            ReadinessOption(key: "live_small", name: L10n.LiveReadiness.modeLiveSmall, kind: nil, detail: nil),
            ReadinessOption(key: "live_full", name: L10n.LiveReadiness.modeLiveFull, kind: nil, detail: nil),
        ]
    }

    private var currentModeLabel: String {
        switch viewModel.data?.selectedMode ?? "" {
        case "paper": return L10n.LiveReadiness.modePaper
        case "live_small": return L10n.LiveReadiness.modeLiveSmall
        case "live_full": return L10n.LiveReadiness.modeLiveFull
        default: return L10n.LiveReadiness.notSelected
        }
    }

    private var currentStrategyLabel: String {
        let list = viewModel.data?.availableStrategies ?? []
        let id = viewModel.data?.selectedStrategyId ?? ""
        return list.first(where: { $0.key == id })?.name ?? L10n.LiveReadiness.notSelected
    }

    private var currentPoolLabel: String {
        let list = viewModel.data?.availableCapitalPools ?? []
        let id = viewModel.data?.selectedCapitalPoolId ?? ""
        return list.first(where: { $0.key == id })?.name ?? L10n.LiveReadiness.notSelected
    }

    private var currentExchangeLabel: String {
        let list = viewModel.data?.availableExchanges ?? []
        let id = viewModel.data?.selectedExchange ?? ""
        return list.first(where: { $0.key == id })?.name ?? L10n.LiveReadiness.notSelected
    }

    private func selector(
        label: String,
        current: String,
        options: [ReadinessOption],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.name) { onSelect(option.key) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                HStack(spacing: 4) {
                    Text(current)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(.vertical, PulseSpacing.xs)
            .padding(.horizontal, PulseSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(colors.surface.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(colors.border, lineWidth: 0.5)
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - Gates Panel (11 checks)

    private var gatesPanel: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.LiveReadiness.gatesTitle)

                if let data = viewModel.data {
                    HStack(alignment: .top, spacing: 10) {
                        gatesColumn(data: data, groups: ["mode", "strategy", "capital", "risk"])
                        gatesColumn(data: data, groups: ["system", "execution"])
                    }
                } else {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .frame(minHeight: 80)
                }
            }
        }
    }

    private func gatesColumn(data: LiveReadinessResponse, groups: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(groups, id: \.self) { group in
                let checks = data.checks.filter { $0.group == group }
                if !checks.isEmpty {
                    Text(groupHeaderLabel(group))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.top, 4)
                    ForEach(checks) { check in
                        gateRow(check)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupHeaderLabel(_ group: String) -> String {
        switch group {
        case "mode": return L10n.LiveReadiness.groupMode
        case "strategy": return L10n.LiveReadiness.groupStrategy
        case "capital": return L10n.LiveReadiness.groupCapital
        case "risk": return L10n.LiveReadiness.groupRisk
        case "system": return L10n.LiveReadiness.groupSystem
        case "execution": return L10n.LiveReadiness.groupExecution
        default: return group
        }
    }

    private func gateRow(_ check: ReadinessCheckResponse) -> some View {
        let tone = gateTone(check.status)
        return HStack(alignment: .center, spacing: 6) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
                .shadow(color: tone.color.opacity(0.4), radius: 2)
            Text(check.label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text(check.value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(tone.color)
        }
    }

    private func gateTone(_ status: String) -> (color: Color, label: String) {
        switch status.lowercased() {
        case "healthy": return (PulseColors.StateColors.green, "OK")
        case "warning": return (PulseColors.StateColors.amber, "WARN")
        case "failed": return (PulseColors.StateColors.red, "FAIL")
        default: return (colors.textMuted, "—")
        }
    }

    // MARK: - Context Panel

    private var contextPanel: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.LiveReadiness.contextTitle)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    contextChip(
                        label: L10n.LiveReadiness.notifications,
                        value: viewModel.notificationsAvailable ? "\(viewModel.notificationCount)" : "—",
                        tone: viewModel.notificationsAvailable
                            ? (viewModel.notificationCount > 0 ? .warn : .live)
                            : .neutral
                    )
                    contextChip(
                        label: L10n.LiveReadiness.aiModels,
                        value: viewModel.aiModelsAvailable
                            ? "\(viewModel.aiModelsLoaded)/\(viewModel.aiModelsTotal)"
                            : "—",
                        tone: viewModel.aiModelsAvailable
                            ? (viewModel.aiModelsLoaded > 0 ? .live : .warn)
                            : .neutral
                    )
                    contextChip(
                        label: L10n.LiveReadiness.dataSource,
                        value: viewModel.dataSource,
                        tone: dataSourceTone(viewModel.dataSource)
                    )
                    contextChip(
                        label: L10n.LiveReadiness.exchangeLabelShort,
                        value: viewModel.exchangeState.uppercased(),
                        tone: exchangeTone(viewModel.exchangeState)
                    )
                    contextChip(
                        label: L10n.LiveReadiness.freqtrade,
                        value: viewModel.freqtradeState.uppercased(),
                        tone: freqtradeTone(viewModel.freqtradeState)
                    )
                    contextChip(
                        label: L10n.LiveReadiness.redis,
                        value: viewModel.redisRttMs > 0 ? "\(viewModel.redisRttMs)ms" : "—",
                        tone: viewModel.redisRttMs > 0
                            ? (viewModel.redisRttMs < 50 ? .live : (viewModel.redisRttMs < 200 ? .warn : .error))
                            : .neutral
                    )
                }

                // Risk firewall gauges
                HStack(spacing: 10) {
                    riskGauge(L10n.LiveReadiness.daily, ratio: viewModel.dailyLossUsedPct)
                    riskGauge(L10n.LiveReadiness.weekly, ratio: viewModel.weeklyLossUsedPct)
                    emergencyStopChip
                }
            }
        }
    }

    private enum ContextTone { case live, warn, error, neutral }

    private func contextChip(label: String, value: String, tone: ContextTone) -> some View {
        let color: Color
        switch tone {
        case .live: color = PulseColors.StateColors.green
        case .warn: color = PulseColors.StateColors.amber
        case .error: color = PulseColors.StateColors.red
        case .neutral: color = colors.textMuted
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.4), radius: 2)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.4)
            Spacer()
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface.opacity(0.3))
        )
    }

    private func riskGauge(_ label: String, ratio: Double) -> some View {
        let clamped = max(0, min(1, ratio))
        let color: Color = clamped < 0.5 ? PulseColors.StateColors.green
            : (clamped < 0.8 ? PulseColors.StateColors.amber : PulseColors.StateColors.red)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                Spacer()
                Text(String(format: "%.0f%%", clamped * 100))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(colors.surface)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: max(0, geo.size.width * clamped), height: 4)
                        .shadow(color: color.opacity(0.3), radius: 2)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var emergencyStopChip: some View {
        let color: Color = viewModel.emergencyStopAvailable ? PulseColors.accent : PulseColors.danger
        return HStack(spacing: 5) {
            Image(systemName: viewModel.emergencyStopAvailable ? "checkmark.shield" : "exclamationmark.triangle")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(L10n.LiveReadiness.checkEmergencyStop)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
            Spacer()
            Text(viewModel.emergencyStopAvailable ? "AVAILABLE" : "UNAVAILABLE")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(color.opacity(0.08))
        )
    }

    private func dataSourceTone(_ state: String) -> ContextTone {
        switch state.lowercased() {
        case "online", "ok", "healthy": return .live
        case "degraded", "warning": return .warn
        case "down", "error", "unavailable": return .error
        default: return .neutral
        }
    }

    private func exchangeTone(_ state: String) -> ContextTone {
        switch state.lowercased() {
        case "ok", "healthy", "running": return .live
        case "degraded", "warning": return .warn
        case "down", "error", "unavailable": return .error
        default: return .neutral
        }
    }

    private func freqtradeTone(_ state: String) -> ContextTone {
        switch state.lowercased() {
        case "healthy", "running", "ok": return .live
        case "degraded", "warning": return .warn
        case "down", "error", "unavailable", "stopped": return .error
        default: return .neutral
        }
    }

    // MARK: - Launch Panel

    private var launchPanel: some View {
        KryptonCard(emphasis: .bold) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.LiveReadiness.launchTitle)

                // Status narrative
                if let key = viewModel.data?.grandStatus {
                    Text(L10n.LiveReadiness.grandStatusDescription(key))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }

                // Blockers
                blockersList

                // Three launch buttons
                HStack(spacing: 10) {
                    launchButton(
                        label: L10n.LiveReadiness.startPaper,
                        enabled: viewModel.data?.canStartPaper ?? false,
                        tone: .cyan,
                        action: { viewModel.requestLaunch(mode: "paper") }
                    )
                    launchButton(
                        label: L10n.LiveReadiness.startLiveSmall,
                        enabled: viewModel.data?.canStartLiveSmall ?? false,
                        tone: .accent,
                        action: { viewModel.requestLaunch(mode: "live_small") }
                    )
                    launchButton(
                        label: L10n.LiveReadiness.startFullLive,
                        enabled: viewModel.data?.canStartFullLive ?? false,
                        tone: .warning,
                        action: { viewModel.requestLaunch(mode: "live_full") }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var blockersList: some View {
        let blockers = viewModel.data?.blockingReasons ?? []
        if blockers.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PulseColors.accent)
                Text(L10n.LiveReadiness.noBlockers)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.LiveReadiness.blockersTitle)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                ForEach(blockers) { reason in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PulseColors.danger)
                        Text(reason.code)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(PulseColors.danger)
                        if let msg = reason.message, !msg.isEmpty {
                            Text("— \(msg)")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(PulseColors.danger.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(PulseColors.danger.opacity(0.20), lineWidth: 0.5)
            )
        }
    }

    private enum LaunchTone { case accent, cyan, warning }

    private func launchButton(
        label: String,
        enabled: Bool,
        tone: LaunchTone,
        action: @escaping () -> Void
    ) -> some View {
        let color: Color
        switch tone {
        case .accent: color = PulseColors.accent
        case .cyan: color = PulseColors.cyan
        case .warning: color = PulseColors.warning
        }
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(PulseFonts.monoLabel)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(enabled ? color : colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(enabled ? color.opacity(0.10) : colors.surface.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(enabled ? color.opacity(0.40) : colors.border, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Triple Confirmation Sheet

private struct LaunchTripleConfirmSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LiveReadinessViewModel

    @State private var step: Int = 1
    @State private var acknowledged: Bool = false
    @State private var phrase: String = ""
    @State private var launching: Bool = false

    private var requiredPhrase: String { L10n.LiveReadiness.confirmPhrase }

    private var canProceed: Bool {
        switch step {
        case 1: return true
        case 2: return acknowledged
        case 3: return phrase == requiredPhrase
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stepper
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { i in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(i <= step ? PulseColors.accent : colors.border)
                            .frame(width: 14, height: 14)
                        Text("\(i)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(i <= step ? PulseColors.accent : colors.textMuted)
                    }
                    if i < 3 {
                        Rectangle()
                            .fill(colors.border)
                            .frame(height: 1)
                            .frame(maxWidth: 30)
                    }
                }
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.top, PulseSpacing.lg)

            Divider().padding(.top, PulseSpacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    stepContent
                }
                .padding(PulseSpacing.lg)
            }

            Divider()

            // Footer
            HStack {
                Button(L10n.LiveReadiness.cancel) {
                    viewModel.cancelLaunch()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.textMuted)
                .font(PulseFonts.micro)
                .textCase(.uppercase)
                .tracking(0.5)

                Spacer()

                if step < 3 {
                    Button {
                        step += 1
                    } label: {
                        HStack(spacing: 4) {
                            Text(L10n.zh("下一步", en: "NEXT"))
                            Image(systemName: "chevron.right")
                        }
                        .font(PulseFonts.monoLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(canProceed ? PulseColors.accent : colors.textMuted)
                        .padding(.horizontal, PulseSpacing.md)
                        .padding(.vertical, PulseSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .fill(canProceed ? PulseColors.accent.opacity(0.10) : colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .stroke(canProceed ? PulseColors.accent.opacity(0.30) : colors.border, lineWidth: 0.7)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed)
                } else {
                    Button {
                        Task {
                            launching = true
                            let ok = await viewModel.confirmLaunch(phrase: phrase)
                            launching = false
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if launching {
                                ProgressView().controlSize(.small).scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(launching ? L10n.LiveReadiness.launching : L10n.LiveReadiness.launch)
                                .font(PulseFonts.monoLabel)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        .foregroundStyle(canProceed && !launching ? PulseColors.danger : colors.textMuted)
                        .padding(.horizontal, PulseSpacing.md)
                        .padding(.vertical, PulseSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .fill(canProceed && !launching ? PulseColors.danger.opacity(0.10) : colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .stroke(canProceed && !launching ? PulseColors.danger.opacity(0.40) : colors.border, lineWidth: 0.7)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed || launching)
                }
            }
            .padding(PulseSpacing.md)
        }
        .frame(width: 540, height: 480)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: step1Summary
        case 2: step2Acknowledge
        case 3: step3Phrase
        default: EmptyView()
        }
    }

    private var step1Summary: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.LiveReadiness.confirmStep1)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(L10n.LiveReadiness.confirmSummary)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                if let data = viewModel.data {
                    summaryRow(L10n.LiveReadiness.modeLabel, modeLabel(data.selectedMode))
                    summaryRow(L10n.LiveReadiness.strategyLabel, currentStrategyName)
                    summaryRow(L10n.LiveReadiness.exchangeLabel, data.selectedExchange.uppercased())
                }
                summaryRow(L10n.LiveReadiness.totalBudget, viewModel.capitalBudget > 0 ? String(format: "%.0f USDT", viewModel.capitalBudget) : "—")
                summaryRow(L10n.LiveReadiness.grandStatus, L10n.LiveReadiness.grandStatusLabel(viewModel.data?.grandStatus ?? "not_live"))
            }
            .padding(PulseSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(colors.surface.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(colors.border, lineWidth: 0.5)
            )
        }
    }

    private var step2Acknowledge: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.LiveReadiness.confirmStep2)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .top, spacing: PulseSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(PulseColors.amber)

                Text(L10n.LiveReadiness.confirmMessage)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(PulseSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(PulseColors.amber.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(PulseColors.amber.opacity(0.20), lineWidth: 0.5)
            )

            Button {
                acknowledged.toggle()
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(acknowledged ? PulseColors.accent : colors.textMuted)
                    Text(L10n.LiveReadiness.confirmCheckText)
                        .font(PulseFonts.body)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, PulseSpacing.sm)
        }
    }

    private var step3Phrase: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.LiveReadiness.confirmStep3)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 6) {
                Text(L10n.LiveReadiness.confirmPhraseHint)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                Text("\u{201C}\(requiredPhrase)\u{201D}")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseColors.amber)
            }

            TextField("", text: $phrase)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(PulseSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(colors.surface.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(
                            phrase == requiredPhrase
                                ? PulseColors.accent.opacity(0.4)
                                : colors.border,
                            lineWidth: 1
                        )
                )
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "paper": return L10n.LiveReadiness.modePaper
        case "live_small": return L10n.LiveReadiness.modeLiveSmall
        case "live_full": return L10n.LiveReadiness.modeLiveFull
        default: return L10n.LiveReadiness.notSelected
        }
    }

    private var currentStrategyName: String {
        let list = viewModel.data?.availableStrategies ?? []
        let id = viewModel.data?.selectedStrategyId ?? ""
        return list.first(where: { $0.key == id })?.name ?? L10n.LiveReadiness.notSelected
    }
}
