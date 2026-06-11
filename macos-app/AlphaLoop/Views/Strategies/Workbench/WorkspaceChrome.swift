// WorkspaceChrome.swift — 工作台 Header / 切换器 / Inspector / Canvas 动作栏
// 配合 StrategyWorkspaceConsoleView 重构后的两栏布局。
// 所有颜色走 PulseColors（不再硬编码 Phosphor 调色板）。

import SwiftUI

// MARK: - Header

struct WorkspaceHeader: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel
    var onSwitcherTap: () -> Void
    var onNewDraft: () -> Void
    var onModeChange: (WorkspaceMode) -> Void
    var onValidate: () -> Void
    var onBacktest: () -> Void
    var onDryrun: () -> Void
    var onTransition: (LifecycleTransition) -> Void

    var body: some View {
        HStack(spacing: 14) {
            switcherButton
            Spacer(minLength: 12)
            modeToggle
            actionGroup
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(colors.background)
    }

    private var switcherButton: some View {
        Button(action: onSwitcherTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(stageColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: stageColor.opacity(0.6), radius: 4)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(vm.selectedStrategy?.name ?? L10n.Workbench.switcherPlaceholder)
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)
                        if let s = vm.selectedStrategy, let off = LifecycleOffPath.from(status: s.status) {
                            offPathBadge(off)
                        }
                    }
                    HStack(spacing: 6) {
                        if let v = vm.snapshot?.latestVersion {
                            Text("v\(v.versionNo)")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textSecondary)
                            Text("·").foregroundStyle(colors.textMuted)
                            Text(String(v.dslHash.prefix(8)))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textMuted)
                        }
                        if let s = vm.selectedStrategy {
                            Text(LifecycleStage.from(status: s.status).label)
                                .font(PulseFonts.monoLabel)
                                .tracking(0.6)
                                .foregroundStyle(stageColor)
                        }
                    }
                }
                Image(systemName: vm.switcherOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .stroke(colors.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        }
        .buttonStyle(.plain)
    }

    private func offPathBadge(_ off: LifecycleOffPath) -> some View {
        let color = offPathColor(off)
        return HStack(spacing: 3) {
            Image(systemName: off.icon).font(.system(size: 9, weight: .semibold))
            Text(off.label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func offPathColor(_ off: LifecycleOffPath) -> Color {
        switch off {
        case .paused:   return PulseColors.warning
        case .archived: return colors.textMuted
        case .rejected: return PulseColors.danger
        }
    }

    private var stageColor: Color {
        guard let s = vm.selectedStrategy else { return colors.textMuted }
        if let off = LifecycleOffPath.from(status: s.status) {
            return offPathColor(off)
        }
        switch LifecycleStage.from(status: s.status) {
        case .draft: return colors.textMuted
        case .validated, .backtested: return PulseColors.cyan
        case .paperRun, .paperPass: return PulseColors.amber
        case .livePending: return PulseColors.amber
        case .liveSmall: return PulseColors.accent
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(WorkspaceMode.allCases) { m in
                let active = vm.mode == m
                Button { onModeChange(m) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon).font(.system(size: 10, weight: .semibold))
                        Text(m.label).font(PulseFonts.captionMedium)
                    }
                    .foregroundStyle(active ? .black : colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(active ? PulseColors.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm + 2)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm + 2))
    }

    private var actionGroup: some View {
        HStack(spacing: 6) {
            actionButton(L10n.Workbench.actionValidate, "checkmark.circle", PulseColors.cyan, action: onValidate)
            actionButton(L10n.Workbench.actionBacktest, "clock.arrow.circlepath", PulseColors.amber, action: onBacktest)
            actionButton(L10n.Workbench.actionDryrun, "tray.full", PulseColors.purple, action: onDryrun)
            lifecycleMenu
        }
        .opacity(vm.mode == .console ? 1 : 0.35)
        .disabled(vm.mode != .console)
    }

    private var lifecycleMenu: some View {
        let status = vm.selectedStrategy?.status ?? ""
        let transitions = LifecycleTransition.allowed(from: status)
        return Menu {
            if transitions.isEmpty {
                Text(L10n.Workbench.transitionNoneAvailable)
            } else {
                ForEach(transitions) { t in
                    Button(role: t.isDestructive ? .destructive : nil) {
                        onTransition(t)
                    } label: {
                        Label(t.label, systemImage: t.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "ellipsis.circle").font(.system(size: 10))
                Text(L10n.Workbench.lifecycleMenu).font(PulseFonts.micro).tracking(0.4)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(colors.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(colors.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(transitions.isEmpty)
    }

    private func actionButton(_ label: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(PulseFonts.captionMedium)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(color.opacity(0.30), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strategy Switcher Panel (popover content)

struct StrategySwitcherPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel
    var onPick: (String) -> Void
    var onNewDraft: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterChips
            Divider().overlay(colors.border)
            list
            Divider().overlay(colors.border)
            footer
        }
        .frame(width: 340)
        .frame(maxHeight: 480)
        .background(colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(colors.textMuted)
            TextField(L10n.Workbench.railSearch, text: Binding(
                get: { vm.search },
                set: { vm.search = $0 }
            ))
            .textFieldStyle(.plain)
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, 8)
    }

    private var filterChips: some View {
        HStack(spacing: 4) {
            ForEach(TrackFilter.allCases) { f in
                chip(f)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.bottom, 8)
    }

    private func chip(_ f: TrackFilter) -> some View {
        let active = vm.filter == f
        return Button { vm.filter = f } label: {
            Text(f.label)
                .font(PulseFonts.micro)
                .tracking(0.8)
                .foregroundStyle(active ? .black : colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? PulseColors.accent : colors.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(vm.filteredStrategies) { s in
                    row(s)
                }
                if vm.filteredStrategies.isEmpty && !vm.isLoadingList {
                    Text(L10n.Strategies.empty)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(.top, 32)
                }
            }
            .padding(6)
        }
    }

    private func row(_ s: StrategyV2) -> some View {
        let selected = vm.selectedStrategyId == s.id
        let stage = LifecycleStage.from(status: s.status)
        let color: Color = {
            switch stage {
            case .draft: return colors.textMuted
            case .validated, .backtested: return PulseColors.cyan
            case .paperRun, .paperPass, .livePending: return PulseColors.amber
            case .liveSmall: return PulseColors.accent
            }
        }()
        return Button { onPick(s.id) } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(selected ? colors.textPrimary : colors.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(s.strategyType.uppercased())
                            .font(PulseFonts.micro)
                            .tracking(0.6)
                            .foregroundStyle(colors.textMuted)
                        Text("·").foregroundStyle(colors.textMuted).font(PulseFonts.micro)
                        Text(stage.label)
                            .font(PulseFonts.micro)
                            .foregroundStyle(color)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? colors.surfaceElevated : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Button(action: onNewDraft) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").font(.system(size: 11, weight: .semibold))
                Text(L10n.Workbench.newDraft).font(PulseFonts.captionMedium)
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                LinearGradient(colors: [PulseColors.accent, PulseColors.accentLight],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}

// MARK: - Inspector Rail (right-edge 36px collapsed)

struct InspectorRail: View {
    @Environment(PulseColors.self) private var colors
    let activeTab: InspectorTab?
    var onTap: (InspectorTab) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(InspectorTab.allCases) { tab in
                Button { onTap(tab) } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(activeTab == tab ? PulseColors.accent : colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(activeTab == tab ? PulseColors.accent.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
                .buttonStyle(.plain)
                .help(tab.label)
            }
            Spacer()
        }
        .padding(.top, 12)
        .frame(width: 36)
        .frame(maxHeight: .infinity)
        .background(colors.background)
        .overlay(
            Rectangle().fill(colors.border).frame(width: 0.5),
            alignment: .leading
        )
    }
}

// MARK: - Inspector Panel (overlay content)

struct InspectorPanel: View {
    @Environment(PulseColors.self) private var colors
    let tab: InspectorTab
    let snapshot: WorkspaceSnapshot?
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(colors.border)
            ScrollView {
                content
                    .padding(12)
            }
        }
        .frame(width: 340)
        .background(colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .shadow(color: .black.opacity(0.30), radius: 14, y: 4)
    }

    private var header: some View {
        HStack {
            Image(systemName: tab.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PulseColors.accent)
            Text(tab.label.uppercased())
                .font(PulseFonts.monoLabel)
                .tracking(1.4)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .decision: decisionView
        case .reason:   reasonView
        case .logs:     logsView
        }
    }

    private var decisionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Workbench.drawerSnapshot.uppercased())
                .font(PulseFonts.micro).tracking(1.0)
                .foregroundStyle(colors.textMuted)
            if let snap = snapshot {
                Text(snapshotJson(snap))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textPrimary.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(colors.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            } else { emptyText }
        }
    }

    private var reasonView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Workbench.riskReasonCodes.uppercased())
                .font(PulseFonts.micro).tracking(1.0)
                .foregroundStyle(colors.textMuted)
            if let r = snapshot?.risk, !r.reasonCodes.isEmpty {
                ForEach(r.reasonCodes, id: \.self) { code in
                    reasonRow(code: code, severity: r.state == "block" ? .block : (r.state == "warn" ? .warn : .info))
                }
            } else { emptyText }
        }
    }

    private func reasonRow(code: String, severity: ReasonSeverity) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(severity.fg(colors)).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(code).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
                Text(severity.label).font(PulseFonts.micro).foregroundStyle(severity.fg(colors))
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private var logsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT EVENTS")
                .font(PulseFonts.micro).tracking(1.0)
                .foregroundStyle(colors.textMuted)
            if let runs = snapshot?.runs, !runs.isEmpty {
                ForEach(runs.prefix(6)) { r in
                    HStack(spacing: 6) {
                        Text(String((r.createdAt).prefix(10)))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(r.mode.uppercased())
                            .font(PulseFonts.micro).tracking(0.8)
                            .foregroundStyle(PulseColors.cyan)
                        Text(r.status)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textPrimary)
                        Spacer()
                    }
                }
            } else { emptyText }
        }
    }

    private var emptyText: some View {
        Text(L10n.Workbench.drawerEmpty)
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textMuted)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
    }

    private func snapshotJson(_ snap: WorkspaceSnapshot) -> String {
        let v = snap.latestVersion
        return """
        {
          "strategy_id": "\(snap.strategy.id)",
          "status": "\(snap.strategy.status)",
          "version": "v\(v?.versionNo ?? 0)",
          "dsl_hash": "\(v?.dslHash.prefix(12) ?? "")",
          "current_run": "\(snap.currentRun?.status ?? "none")",
          "guards": \(snap.risk.guards.count),
          "signals": \(snap.signals.count)
        }
        """
    }
}

// MARK: - Canvas Action Rail (floating top bar in canvas mode)

struct CanvasActionRail: View {
    @Environment(PulseColors.self) private var colors
    let vm: CanvasWebViewModel
    let versionLabel: String
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .stroke(PulseColors.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().fill(PulseColors.accent).frame(width: 6, height: 6))
                Text(L10n.Workbench.canvasEditBay.uppercased())
                    .font(PulseFonts.monoLabel).tracking(1.4)
                    .foregroundStyle(PulseColors.accent)
                Text(versionLabel)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            validationPip
            actionButton("checkmark.circle", L10n.Workbench.canvasValidate, PulseColors.cyan) {
                if let dsl = vm.lastDSL {
                    Task { await vm.validateAndSendResult(dsl: dsl) }
                }
            }
            actionButton("tray.and.arrow.down", L10n.Workbench.canvasSaveDraft, colors.textPrimary) {
                if let dsl = vm.lastDSL {
                    Task { await vm.saveVersion(dsl: dsl) }
                }
            }
            actionButton("paperplane.fill", L10n.Workbench.canvasPublish, PulseColors.accent, primary: true) {
                if let dsl = vm.lastDSL {
                    Task { await vm.saveVersion(dsl: dsl) }
                }
            }
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L10n.Workbench.canvasReturnConsole)
                        .font(PulseFonts.captionMedium)
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
    }

    private var validationPip: some View {
        let (label, color): (String, Color) = {
            if vm.validationValid == true { return ("VALID", PulseColors.accent) }
            if vm.validationValid == false { return ("INVALID (\(vm.validationErrors))", PulseColors.danger) }
            return ("UNVALIDATED", colors.textMuted)
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(PulseFonts.micro).tracking(1.0).foregroundStyle(color)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.10))
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
        .clipShape(Capsule())
    }

    private func actionButton(_ icon: String, _ label: String, _ color: Color, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(PulseFonts.captionMedium)
            }
            .foregroundStyle(primary ? .black : color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Group {
                    if primary {
                        LinearGradient(colors: [PulseColors.accent, PulseColors.accentLight], startPoint: .leading, endPoint: .trailing)
                    } else {
                        colors.surface
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(primary ? .clear : color.opacity(0.30), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
    }
}
