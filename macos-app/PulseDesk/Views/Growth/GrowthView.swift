// GrowthView.swift — 增长引擎主视图
// Tab 布局：分析报告 + 候选策略

import SwiftUI

struct GrowthView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var viewModel: GrowthViewModel?
    @State private var selectedPeriod: GrowthPeriod = .week

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let vm = viewModel {
                if vm.isLoading {
                    LoadingView(type: .detail).padding(PulseSpacing.lg)
                } else {
                    VStack(spacing: PulseSpacing.md) {
                        pageHeader(vm: vm)
                        periodSelector
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
                let vm = GrowthViewModel(client: networkClient)
                viewModel = vm
                await vm.load()
            }
        }
    }

    // MARK: - Header

    private func pageHeader(vm: GrowthViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text("增长引擎")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: .online)
                    Text("自动发现 · 回测验证 · 策略进化")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Tab Selector

    private func tabSelector(vm: GrowthViewModel) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            tabButton(label: "分析报告", index: 0, count: vm.reports.count, vm: vm)
            tabButton(label: "候选策略", index: 1, count: vm.candidates.count, vm: vm)
            tabButton(label: "SHAP 分析", index: 2, count: vm.shapFeatures.count, vm: vm)
            tabButton(label: "Signal 有效性", index: 3, count: vm.signalSources.count, vm: vm)
            Spacer()
        }
    }

    private func tabButton(label: String, index: Int, count: Int, vm: GrowthViewModel) -> some View {
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
    private func tabContent(vm: GrowthViewModel) -> some View {
        switch vm.selectedTab {
        case 0:
            reportsTab(vm: vm)
        case 1:
            candidatesTab(vm: vm)
        case 2:
            shapAnalysisTab.task { await viewModel?.loadShapFeatures() }
        case 3:
            signalValidityTab.task { await viewModel?.loadSignalValidity() }
        default:
            EmptyView()
        }
    }

    // MARK: - Reports Tab

    private func reportsTab(vm: GrowthViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            // 运行日报 button
            HStack {
                TerminalLabel(text: "分析报告")
                Spacer()
                KryptonButton(title: "运行日报", action: {
                    Task { await vm.runDailyReview() }
                })
            }

            if vm.reports.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "暂无报告",
                    description: "点击「运行日报」生成第一份增长分析报告",
                    primaryAction: (title: "运行日报", action: {
                        Task { await vm.runDailyReview() }
                    })
                )
            } else {
                LazyVStack(spacing: PulseSpacing.sm) {
                    ForEach(Array(vm.reports.enumerated()), id: \.element.id) { index, report in
                        GrowthReportCard(report: report)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    // MARK: - Candidates Tab

    private func candidatesTab(vm: GrowthViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "候选策略")

            if vm.candidates.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "暂无候选策略",
                    description: "增长引擎将自动发现并推荐有潜力的交易策略"
                )
            } else {
                LazyVStack(spacing: PulseSpacing.sm) {
                    ForEach(Array(vm.candidates.enumerated()), id: \.element.id) { index, candidate in
                        CandidateCard(
                            candidate: candidate,
                            onBacktest: {
                                Task {
                                    let api = APIStrategiesV2(client: networkClient)
                                    _ = try? await api.startBacktest(
                                        dsl: [:],
                                        timerange: "2025-01-01-2026-01-01",
                                        symbols: ["BTC/USDT"],
                                        initialCapital: 100000
                                    )
                                }
                            },
                            onConfirm: {
                                Task { await vm.confirmCandidate(candidate.id) }
                            }
                        )
                        .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: PulseSpacing.xs) {
            ForEach(GrowthPeriod.allCases) { period in
                Button {
                    withAnimation(PulseAnimation.easeOutFast) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(selectedPeriod == period ? colors.background : colors.textSecondary)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, PulseSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .fill(selectedPeriod == period ? PulseColors.accent : colors.surface)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - SHAP Analysis Tab

    private var shapAnalysisTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "SHAP 特征重要性")

            KryptonCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    Text("全局特征对交易决策的影响程度")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)

                    let features = viewModel?.shapFeatures ?? []
                    let maxVal = features.map(\.value).max() ?? 1.0

                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: PulseSpacing.sm) {
                            Text(feature.name)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(shapBarColor(index))
                                        .frame(width: geo.size.width * (feature.value / maxVal), height: 14)
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 14)

                            Text(String(format: "%.3f", feature.value))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textSecondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }



    private func shapBarColor(_ index: Int) -> Color {
        let palette: [Color] = [
            PulseColors.accent, PulseColors.cyan, PulseColors.purple,
            PulseColors.amber, PulseColors.info, PulseColors.warning
        ]
        return palette[index % palette.count]
    }

    // MARK: - Signal Validity Tab

    private var signalValidityTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "Signal 有效性追踪")

            KryptonCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    Text("各来源信号预测准确率（\(selectedPeriod.rawValue)）")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)

                    let sources = viewModel?.signalSources ?? []
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        HStack(spacing: PulseSpacing.sm) {
                            Text(source.name)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                                .frame(width: 100, alignment: .leading)

                            // Accuracy bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colors.surface)
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(accuracyColor(source.accuracy))
                                        .frame(width: geo.size.width * source.accuracy, height: 10)
                                }
                            }
                            .frame(height: 10)

                            Text(String(format: "%.0f%%", source.accuracy * 100))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(accuracyColor(source.accuracy))
                                .frame(width: 40, alignment: .trailing)

                            Text("\(source.total)次")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .frame(width: 35, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Summary stats
            KryptonCard(emphasis: .subtle) {
                HStack(spacing: PulseSpacing.lg) {
                    validityStat(label: "总信号数", value: "156", color: PulseColors.info)
                    validityStat(label: "平均准确率", value: "63.2%", color: PulseColors.accent)
                    validityStat(label: "最佳来源", value: "AI Research", color: PulseColors.success)
                    validityStat(label: "最差来源", value: "KOL", color: PulseColors.danger)
                }
            }
        }
    }



    private func accuracyColor(_ value: Double) -> Color {
        if value > 0.65 { return PulseColors.success }
        if value > 0.50 { return PulseColors.warning }
        return PulseColors.danger
    }

    private func validityStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Growth Period Enum

enum GrowthPeriod: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"

    var id: String { rawValue }
}
