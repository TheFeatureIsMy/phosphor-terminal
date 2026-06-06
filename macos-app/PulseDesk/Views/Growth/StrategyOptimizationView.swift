// StrategyOptimizationView.swift — 策略优化页面
// AI 驱动的策略改进建议，强制安全工作流

import SwiftUI

struct StrategyOptimizationView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
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
                Text("策略优化")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: .online)
                    Text("AI 驱动的策略改进建议")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Safety Workflow Banner

    private var safetyWorkflowBanner: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                    Text("安全工作流 — 候选策略不可直接上线")
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
                        .font(.system(size: 9))
                        .foregroundStyle(PulseColors.warning)
                    Text("候选策略必须经过完整流程审核，不可跳过任何步骤直接部署至实盘")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.warning.opacity(0.8))
                }
            }
        }
    }

    private var workflowSteps: [(label: String, color: Color)] {
        [
            ("AI 建议", PulseColors.purple),
            ("草稿", PulseColors.info),
            ("DSL 校验", PulseColors.cyan),
            ("回测", PulseColors.amber),
            ("模拟盘", PulseColors.accent),
            ("人工审批", PulseColors.warning),
            ("小仓实盘", PulseColors.success),
        ]
    }

    // MARK: - Summary Cards

    private func summaryCards(vm: StrategyOptimizationViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            summaryCard(
                label: "待审核",
                value: "\(vm.pendingCandidates.count)",
                color: PulseColors.warning
            )
            summaryCard(
                label: "已确认",
                value: "\(vm.confirmedCandidates.count)",
                color: PulseColors.success
            )
            summaryCard(
                label: "已拒绝",
                value: "\(vm.rejectedCandidates.count)",
                color: PulseColors.danger
            )
        }
    }

    private func summaryCard(label: String, value: String, color: Color) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
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
            tabButton(label: "待审核", index: 0, count: vm.pendingCandidates.count, vm: vm)
            tabButton(label: "已确认", index: 1, count: vm.confirmedCandidates.count, vm: vm)
            tabButton(label: "已拒绝", index: 2, count: vm.rejectedCandidates.count, vm: vm)
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
            case 0: return ("sparkles", "暂无待审核策略", "AI 发现的候选策略将出现在此处")
            case 1: return ("checkmark.circle", "暂无已确认策略", "确认候选后将显示在此处")
            case 2: return ("xmark.circle", "暂无已拒绝策略", "拒绝的候选将归档于此")
            default: return ("doc", "无数据", "")
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
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: name + status badge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extractDslString(candidate.dsl, key: "name") ?? "未命名策略")
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
                            label: "置信度",
                            value: String(format: "%.0f%%", confidence * 100),
                            color: confidenceColor(confidence)
                        )
                    }
                    // Source type
                    if let sourceType = extractDslString(candidate.dsl, key: "source_type") {
                        metricPill(
                            label: "来源",
                            value: sourceTypeLabel(sourceType),
                            color: sourceType == "ai_generated" ? PulseColors.purple : PulseColors.info
                        )
                    }
                    // Win rate
                    if let winRate = extractDslDouble(candidate.dsl, key: "backtest_win_rate") {
                        metricPill(
                            label: "胜率",
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
                            .font(.system(size: 10))
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
                            ProofAlphaButton(title: "回测", action: {}, style: .ghost)
                            ProofAlphaButton(title: "拒绝", action: {}, style: .ghost)
                            ProofAlphaButton(title: "确认", action: {
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
        case 0: return "待审核候选"
        case 1: return "已确认候选"
        case 2: return "已拒绝候选"
        default: return ""
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, label) = statusInfo(status)
        return BadgeDot(color: color, label: label)
    }

    private func statusInfo(_ status: String) -> (Color, String) {
        switch status {
        case "pending_review": return (PulseColors.warning, "待审核")
        case "confirmed": return (PulseColors.success, "已确认")
        case "rejected": return (PulseColors.danger, "已拒绝")
        case "backtesting": return (PulseColors.info, "回测中")
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
        case "manual": return "手动"
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
