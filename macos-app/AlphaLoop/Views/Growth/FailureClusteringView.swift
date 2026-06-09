// FailureClusteringView.swift — 失败聚类分析页面
// 展示交易失败模式：聚类分布、Regime 矩阵、拒单原因

import SwiftUI

struct FailureClusteringView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: FailureClusteringViewModel?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let vm = viewModel {
                if vm.isLoading {
                    LoadingView(type: .detail).padding(PulseSpacing.lg)
                } else {
                    VStack(spacing: PulseSpacing.md) {
                        pageHeader
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
                let vm = FailureClusteringViewModel(client: networkClient)
                viewModel = vm
                await vm.load()
            }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("失败聚类", en: "Loss Patterns"))
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: .online)
                    Text(L10n.zh("发现策略失败模式，精准优化", en: "Identify failure patterns for targeted optimization"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(vm: FailureClusteringViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            summaryCard(
                label: L10n.zh("总亏损交易", en: "Total Losing Trades"),
                value: "\(vm.totalLossTrades)",
                color: PulseColors.warning
            )
            summaryCard(
                label: L10n.zh("总亏损金额", en: "Total Loss"),
                value: String(format: "$%.2f", vm.totalLossAmount),
                color: PulseColors.danger
            )
            summaryCard(
                label: L10n.zh("Top 聚类", en: "Top Cluster"),
                value: vm.clusters.first?.label ?? "—",
                color: PulseColors.amber
            )
            summaryCard(
                label: L10n.zh("聚类数量", en: "Cluster Count"),
                value: "\(vm.clusters.count)",
                color: PulseColors.info
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
                    .font(PulseFonts.tabular)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Tab Selector

    private func tabSelector(vm: FailureClusteringViewModel) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            tabButton(label: L10n.zh("失败聚类", en: "Loss Patterns"), index: 0, count: vm.clusters.count, vm: vm)
            tabButton(label: L10n.zh("Regime 矩阵", en: "Regime Matrix"), index: 1, count: vm.regimeMatrix.count, vm: vm)
            tabButton(label: L10n.zh("拒单原因", en: "Rejection Reasons"), index: 2, count: vm.commonRejectReasons.count, vm: vm)
            Spacer()
        }
    }

    private func tabButton(label: String, index: Int, count: Int, vm: FailureClusteringViewModel) -> some View {
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
    private func tabContent(vm: FailureClusteringViewModel) -> some View {
        switch vm.selectedTab {
        case 0:
            clustersTab(vm: vm)
        case 1:
            regimeMatrixTab(vm: vm)
        case 2:
            rejectReasonsTab(vm: vm)
        default:
            EmptyView()
        }
    }

    // MARK: - Clusters Tab

    private func clustersTab(vm: FailureClusteringViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("失败模式聚类", en: "Failure Pattern Clusters"))

            if vm.clusters.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield",
                    title: L10n.zh("暂无失败聚类", en: "No Loss Patterns"),
                    description: L10n.zh("当前无显著失败模式，策略运行良好", en: "No significant failure patterns detected; strategies are performing well")
                )
            } else {
                LazyVStack(spacing: PulseSpacing.sm) {
                    ForEach(Array(vm.clusters.enumerated()), id: \.element.id) { index, cluster in
                        clusterCard(cluster: cluster, maxLoss: vm.maxClusterLoss)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    private func clusterCard(cluster: FailureClusterBFFResponse, maxLoss: Double) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: name + severity badge
                HStack {
                    Text(cluster.label)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    BadgeDot(
                        color: severityColor(cluster.severity),
                        label: severityLabel(cluster.severity)
                    )
                }

                // Stats row
                HStack(spacing: PulseSpacing.lg) {
                    statPill(label: L10n.zh("交易数", en: "Trades"), value: "\(cluster.tradeCount)", color: PulseColors.info)
                    statPill(label: L10n.zh("总亏损", en: "Total Loss"), value: String(format: "$%.2f", cluster.totalLoss), color: PulseColors.danger)
                    statPill(label: L10n.zh("平均亏损", en: "Avg Loss"), value: String(format: "%.2f%%", cluster.avgLossPct * 100), color: PulseColors.warning)
                }

                // Loss magnitude bar
                GeometryReader { geo in
                    let ratio = maxLoss > 0 ? abs(cluster.totalLoss) / maxLoss : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colors.surface)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [severityColor(cluster.severity).opacity(0.7), severityColor(cluster.severity)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * ratio, height: 8)
                    }
                }
                .frame(height: 8)

                // Suggested fix
                HStack(alignment: .top, spacing: PulseSpacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.amber)
                    Text(cluster.suggestedFix)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                .padding(PulseSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(PulseColors.amber.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(PulseColors.amber.opacity(0.12), lineWidth: 1)
                )

                // Example trade IDs
                if !cluster.exampleTradeIds.isEmpty {
                    HStack(spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("示例:", en: "Examples:"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        ForEach(cluster.exampleTradeIds, id: \.self) { tradeId in
                            Text(tradeId)
                                .font(PulseFonts.micro)
                                .foregroundStyle(PulseColors.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                                        .fill(PulseColors.cyan.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                                        .stroke(PulseColors.cyan.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Regime Matrix Tab

    private func regimeMatrixTab(vm: FailureClusteringViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("REGIME × 失败类型 矩阵", en: "REGIME x Failure Type Matrix"))

            if vm.regimeMatrix.isEmpty {
                EmptyStateView(
                    icon: "square.grid.3x3",
                    title: L10n.zh("暂无数据", en: "No Data"),
                    description: L10n.zh("等待足够的交易数据生成 Regime 矩阵", en: "Awaiting sufficient trade data to generate the Regime matrix")
                )
            } else {
                KryptonCard(emphasis: .subtle) {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text(L10n.zh("颜色越深 = 亏损越大", en: "Darker = Larger Loss"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)

                        let regimes = vm.uniqueRegimes
                        let failureTypes = vm.uniqueFailureTypes
                        let maxLoss = vm.regimeMatrix.map { abs($0.totalLoss) }.max() ?? 1.0

                        // Header row
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 100)
                            ForEach(failureTypes, id: \.self) { ft in
                                Text(shortFailureLabel(ft))
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                            }
                        }

                        // Matrix rows
                        ForEach(regimes, id: \.self) { regime in
                            HStack(spacing: 0) {
                                Text(regime)
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(width: 100, alignment: .leading)

                                ForEach(failureTypes, id: \.self) { ft in
                                    let cell = vm.regimeCell(regime: regime, failureType: ft)
                                    regimeCellView(cell: cell, maxLoss: maxLoss)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func regimeCellView(cell: RegimeFailureCellResponse?, maxLoss: Double) -> some View {
        Group {
            if let cell = cell {
                let intensity = maxLoss > 0 ? abs(cell.totalLoss) / maxLoss : 0
                VStack(spacing: 2) {
                    Text("\(cell.count)")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(String(format: "$%.0f", cell.totalLoss))
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.danger)
                }
                .padding(PulseSpacing.xxs)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .fill(PulseColors.danger.opacity(0.05 + intensity * 0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(PulseColors.danger.opacity(0.1 + intensity * 0.15), lineWidth: 1)
                )
            } else {
                Text("—")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(PulseSpacing.xxs)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface)
                    )
            }
        }
    }

    // MARK: - Reject Reasons Tab

    private func rejectReasonsTab(vm: FailureClusteringViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("拒单原因统计", en: "Rejection Reason Statistics"))

            if vm.commonRejectReasons.isEmpty {
                EmptyStateView(
                    icon: "xmark.octagon",
                    title: L10n.zh("暂无拒单", en: "No Rejections"),
                    description: L10n.zh("当前无交易被拒绝", en: "No trades have been rejected")
                )
            } else {
                let reasons = vm.commonRejectReasons
                let maxCount = reasons.compactMap { Int($0["count"] ?? "0") }.max() ?? 1

                KryptonCard(emphasis: .subtle) {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text(L10n.zh("各拒单原因发生频次", en: "Rejection reason frequency"))
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)

                        ForEach(Array(reasons.enumerated()), id: \.offset) { index, reason in
                            let code = reason["code"] ?? "unknown"
                            let count = Int(reason["count"] ?? "0") ?? 0
                            let ratio = Double(count) / Double(maxCount)

                            HStack(spacing: PulseSpacing.sm) {
                                Text(rejectReasonLabel(code))
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textPrimary)
                                    .frame(width: 160, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(colors.surface)
                                            .frame(height: 12)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [PulseColors.danger.opacity(0.5), PulseColors.danger],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * ratio, height: 12)
                                    }
                                }
                                .frame(height: 12)

                                Text(L10n.zh("\(count) 次", en: "\(count)x"))
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .staggeredAppearance(index: index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "critical": return PulseColors.danger
        case "high": return PulseColors.StateColors.orange
        case "medium": return PulseColors.warning
        case "low": return PulseColors.success
        default: return PulseColors.StateColors.gray
        }
    }

    private func severityLabel(_ severity: String) -> String {
        switch severity {
        case "critical": return L10n.zh("严重", en: "Critical")
        case "high": return L10n.zh("高", en: "High")
        case "medium": return L10n.zh("中", en: "Medium")
        case "low": return L10n.zh("低", en: "Low")
        default: return severity
        }
    }

    private func shortFailureLabel(_ type: String) -> String {
        // Shorten long snake_case labels for matrix header
        type.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .prefix(2)
            .joined(separator: " ")
    }

    private func rejectReasonLabel(_ code: String) -> String {
        switch code {
        case "daily_loss_limit_reached": return L10n.zh("日亏损上限", en: "Daily Loss Limit")
        case "snapshot_stale": return L10n.zh("快照过期", en: "Stale Snapshot")
        case "ai_cache_expired": return L10n.zh("AI 缓存过期", en: "AI Cache Expired")
        case "max_position_reached": return L10n.zh("持仓上限", en: "Max Position Reached")
        case "volatility_too_high": return L10n.zh("波动率过高", en: "Volatility Too High")
        default: return code.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }
}
