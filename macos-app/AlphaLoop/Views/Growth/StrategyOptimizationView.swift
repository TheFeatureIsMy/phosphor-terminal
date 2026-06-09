// StrategyOptimizationView.swift — 策略优化页面
// AI 驱动的策略改进建议，强制安全工作流

import SwiftUI

struct StrategyOptimizationView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: StrategyOptimizationViewModel?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let vm = viewModel {
                if vm.isLoading {
                    LoadingView(type: .detail).padding(PulseSpacing.lg)
                } else {
                    VStack(spacing: PulseSpacing.md) {
                        pageHeader
                        safetyWorkflowBanner
                        summaryCards(vm: vm)
                        tabSelector(vm: vm)
                        tabContent(vm: vm)
                    }
                    .padding(PulseSpacing.lg)
                    .id(settingsState.language)
                }
            } else {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            if viewModel == nil {
                let vm = StrategyOptimizationViewModel(client: networkClient)
                viewModel = vm
                await vm.load()
            }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("策略优化", en: "Strategy Optimization"))
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: .online)
                    Text(L10n.zh("AI 驱动的策略改进建议", en: "AI-powered strategy improvement recommendations"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Safety Workflow Banner

    private var safetyWorkflowBanner: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "shield.checkered")
                        .font(PulseFonts.headline)
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.zh("安全工作流 — 候选策略不可直接上线", en: "Safety Workflow — Candidates cannot go live directly"))
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                }

                // Pipeline steps
                let steps = workflowSteps
                HStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 0) {
                            // Step circle + label
                            VStack(spacing: PulseSpacing.xxs) {
                                ZStack {
                                    Circle()
                                        .fill(step.color.opacity(0.12))
                                        .frame(width: 24, height: 24)
                                    Circle()
                                        .stroke(step.color.opacity(0.4), lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                    Text("\(index + 1)")
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(step.color)
                                }
                                Text(step.label)
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)

                            // Connector line (not after last)
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [step.color.opacity(0.4), steps[index + 1].color.opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1.5)
                                    .frame(maxWidth: 24)
                                    .offset(y: -8) // align with circles
                            }
                        }
                    }
                }

                // Warning text
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.warning)
                    Text(L10n.zh("候选策略必须经过完整流程审核，不可跳过任何步骤直接部署至实盘", en: "Candidates must pass the full review pipeline; no step may be skipped before live deployment"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.warning.opacity(0.8))
                }
            }
        }
    }

    private var workflowSteps: [(label: String, color: Color)] {
        [
            (L10n.zh("AI 建议", en: "AI Suggestion"), PulseColors.purple),
            (L10n.zh("草稿", en: "Draft"), PulseColors.info),
            (L10n.zh("DSL 校验", en: "DSL Validation"), PulseColors.cyan),
            (L10n.zh("回测", en: "Backtest"), PulseColors.amber),
            (L10n.zh("模拟盘", en: "Paper Trading"), PulseColors.accent),
            (L10n.zh("人工审批", en: "Manual Approval"), PulseColors.warning),
            (L10n.zh("小仓实盘", en: "Small-Size Live"), PulseColors.success),
        ]
    }

    // MARK: - Summary Cards

    private func summaryCards(vm: StrategyOptimizationViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            summaryCard(
                label: L10n.zh("待审核", en: "Pending Review"),
                value: "\(vm.pendingCandidates.count)",
                color: PulseColors.warning
            )
            summaryCard(
                label: L10n.zh("已确认", en: "Confirmed"),
                value: "\(vm.confirmedCandidates.count)",
                color: PulseColors.success
            )
            summaryCard(
                label: L10n.zh("已拒绝", en: "Rejected"),
                value: "\(vm.rejectedCandidates.count)",
                color: PulseColors.danger
            )
        }
    }

    private func summaryCard(label: String, value: String, color: Color) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(PulseFonts.tabularLarge)
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Tab Selector

    private func tabSelector(vm: StrategyOptimizationViewModel) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            tabButton(label: L10n.zh("待审核", en: "Pending Review"), index: 0, count: vm.pendingCandidates.count, vm: vm)
            tabButton(label: L10n.zh("已确认", en: "Confirmed"), index: 1, count: vm.confirmedCandidates.count, vm: vm)
            tabButton(label: L10n.zh("已拒绝", en: "Rejected"), index: 2, count: vm.rejectedCandidates.count, vm: vm)
            Spacer()
        }
    }

    private func tabButton(label: String, index: Int, count: Int, vm: StrategyOptimizationViewModel) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutMedium) {
                vm.selectedTab = index
            }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Text(label)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(vm.selectedTab == index ? PulseColors.accent : colors.textMuted)
                Text("\(count)")
                    .font(PulseFonts.micro)
                    .foregroundStyle(vm.selectedTab == index ? PulseColors.accent : colors.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.badge)
                            .fill(vm.selectedTab == index ? PulseColors.accent.opacity(0.1) : colors.surface)
                    )
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(vm.selectedTab == index ? PulseColors.accent.opacity(0.06) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .stroke(
                        vm.selectedTab == index ? PulseColors.accent.opacity(0.2) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(vm: StrategyOptimizationViewModel) -> some View {
        let candidates: [StrategyCandidate] = {
            switch vm.selectedTab {
            case 0: return vm.pendingCandidates
            case 1: return vm.confirmedCandidates
            case 2: return vm.rejectedCandidates
            default: return []
            }
        }()

        let emptyLabels: (icon: String, title: String, desc: String) = {
            switch vm.selectedTab {
            case 0: return ("sparkles", L10n.zh("暂无待审核策略", en: "No Pending Candidates"), L10n.zh("AI 发现的候选策略将出现在此处", en: "AI-discovered candidates will appear here"))
            case 1: return ("checkmark.circle", L10n.zh("暂无已确认策略", en: "No Confirmed Candidates"), L10n.zh("确认候选后将显示在此处", en: "Confirmed candidates will be listed here"))
            case 2: return ("xmark.circle", L10n.zh("暂无已拒绝策略", en: "No Rejected Candidates"), L10n.zh("拒绝的候选将归档于此", en: "Rejected candidates are archived here"))
            default: return ("doc", L10n.zh("无数据", en: "No Data"), "")
            }
        }()

        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: tabLabel(vm.selectedTab))

            if candidates.isEmpty {
                EmptyStateView(
                    icon: emptyLabels.icon,
                    title: emptyLabels.title,
                    description: emptyLabels.desc
                )
            } else {
                LazyVStack(spacing: PulseSpacing.sm) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                        candidateCard(candidate: candidate, isPending: vm.selectedTab == 0, vm: vm)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    // MARK: - Candidate Card

    private func candidateCard(candidate: StrategyCandidate, isPending: Bool, vm: StrategyOptimizationViewModel) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: name + status badge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extractDslString(candidate.dsl, key: "name") ?? L10n.zh("未命名策略", en: "Unnamed Strategy"))
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text(extractDslString(candidate.dsl, key: "symbol") ?? "—")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    statusBadge(candidate.status)
                }

                // Metrics row
                HStack(spacing: PulseSpacing.lg) {
                    // Confidence
                    if let confidence = candidate.confidence {
                        metricPill(
                            label: L10n.zh("置信度", en: "Confidence"),
                            value: String(format: "%.0f%%", confidence * 100),
                            color: confidenceColor(confidence)
                        )
                    }
                    // Source type
                    if let sourceType = extractDslString(candidate.dsl, key: "source_type") {
                        metricPill(
                            label: L10n.zh("来源", en: "Source"),
                            value: sourceTypeLabel(sourceType),
                            color: sourceType == "ai_generated" ? PulseColors.purple : PulseColors.info
                        )
                    }
                    // Win rate
                    if let winRate = extractDslDouble(candidate.dsl, key: "backtest_win_rate") {
                        metricPill(
                            label: L10n.zh("胜率", en: "Win Rate"),
                            value: String(format: "%.0f%%", winRate * 100),
                            color: PulseColors.accent
                        )
                    }
                    // Sharpe
                    if let sharpe = extractDslDouble(candidate.dsl, key: "backtest_sharpe") {
                        metricPill(
                            label: "Sharpe",
                            value: String(format: "%.2f", sharpe),
                            color: sharpe > 1.5 ? PulseColors.success : PulseColors.warning
                        )
                    }
                }

                // Reasoning
                if let reasoning = extractDslString(candidate.dsl, key: "reasoning"), !reasoning.isEmpty {
                    HStack(alignment: .top, spacing: PulseSpacing.xs) {
                        Image(systemName: "brain.fill")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(PulseColors.purple)
                        Text(reasoning)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .padding(PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.purple.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(PulseColors.purple.opacity(0.10), lineWidth: 1)
                    )
                }

                // Footer: created date + actions
                HStack {
                    Text(formatDate(candidate.createdAt))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)

                    Spacer()

                    if isPending {
                        HStack(spacing: PulseSpacing.xs) {
                            KryptonButton(title: L10n.zh("回测", en: "Backtest"), action: {}, style: .ghost)
                            KryptonButton(title: L10n.zh("拒绝", en: "Reject"), action: {}, style: .ghost)
                            KryptonButton(title: L10n.zh("确认", en: "Confirm"), action: {
                                Task { await vm.confirmCandidate(candidate.id) }
                            })
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func tabLabel(_ index: Int) -> String {
        switch index {
        case 0: return L10n.zh("待审核候选", en: "Pending Candidates")
        case 1: return L10n.zh("已确认候选", en: "Confirmed Candidates")
        case 2: return L10n.zh("已拒绝候选", en: "Rejected Candidates")
        default: return ""
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, label) = statusInfo(status)
        return BadgeDot(color: color, label: label)
    }

    private func statusInfo(_ status: String) -> (Color, String) {
        switch status {
        case "pending_review": return (PulseColors.warning, L10n.zh("待审核", en: "Pending Review"))
        case "confirmed": return (PulseColors.success, L10n.zh("已确认", en: "Confirmed"))
        case "rejected": return (PulseColors.danger, L10n.zh("已拒绝", en: "Rejected"))
        case "backtesting": return (PulseColors.info, L10n.zh("回测中", en: "Backtesting"))
        default: return (PulseColors.StateColors.gray, status)
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value > 0.7 { return PulseColors.success }
        if value > 0.5 { return PulseColors.warning }
        return PulseColors.danger
    }

    private func sourceTypeLabel(_ type: String) -> String {
        switch type {
        case "ai_generated": return "AI"
        case "manual": return L10n.zh("手动", en: "Manual")
        default: return type
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    private func formatDate(_ iso: String) -> String {
        // Simple display: extract date portion
        let parts = iso.split(separator: "T")
        if let datePart = parts.first {
            return String(datePart)
        }
        return iso
    }

    // MARK: - DSL Value Extraction

    private func extractDslString(_ dsl: AnyCodable?, key: String) -> String? {
        guard let dsl = dsl, let dict = dsl.value as? [String: Any] else { return nil }
        return dict[key] as? String
    }

    private func extractDslDouble(_ dsl: AnyCodable?, key: String) -> Double? {
        guard let dsl = dsl, let dict = dsl.value as? [String: Any] else { return nil }
        if let v = dict[key] as? Double { return v }
        if let v = dict[key] as? Int { return Double(v) }
        return nil
    }
}
