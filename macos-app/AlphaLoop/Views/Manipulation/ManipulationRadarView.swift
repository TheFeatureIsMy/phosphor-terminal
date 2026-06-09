// ManipulationRadarView.swift — 操纵雷达主视图
// 扫描输入 + 统计卡片 + 评分列表

import SwiftUI

struct ManipulationRadarView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: ManipulationViewModel?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let vm = viewModel {
                if vm.isLoading {
                    LoadingView(type: .detail).padding(PulseSpacing.lg)
                } else {
                    VStack(spacing: PulseSpacing.md) {
                        pageHeader(vm: vm)
                        scanBar(vm: vm)
                        summaryCards(vm: vm)
                        scoresSection(vm: vm)
                    }
                    .padding(PulseSpacing.lg)
                }
            } else {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            }
        }
        .id(settingsState.language)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            if viewModel == nil {
                let vm = ManipulationViewModel(client: networkClient)
                viewModel = vm
                await vm.load()
            }
        }
    }

    // MARK: - Header

    private func pageHeader(vm: ManipulationViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.zh("操纵雷达", en: "Manipulation Radar"))
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: highRiskCount(vm: vm) > 0 ? .loading : .online)
                    Text(highRiskCount(vm: vm) > 0 ? L10n.zh("检测到异常信号", en: "Anomalous signals detected") : L10n.zh("市场状态正常", en: "Market conditions normal"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Scan Bar

    private func scanBar(vm: ManipulationViewModel) -> some View {
        KryptonCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textMuted)

                TextField(L10n.zh("输入交易对（如 BTC/USDT）", en: "Enter trading pair (e.g. BTC/USDT)"), text: Binding(
                    get: { vm.scanSymbol },
                    set: { vm.scanSymbol = $0 }
                ))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await vm.scan() }
                }

                KryptonButton(title: L10n.zh("扫描", en: "Scan"), action: {
                    Task { await vm.scan() }
                })
            }
        }
    }

    // MARK: - Summary Stat Cards

    private func summaryCards(vm: ManipulationViewModel) -> some View {
        HStack(spacing: PulseSpacing.md) {
            StatCard(
                icon: "chart.bar.doc.horizontal",
                label: L10n.zh("已扫描", en: "Scanned"),
                value: "\(vm.scores.count)",
                color: PulseColors.info
            )
            StatCard(
                icon: "exclamationmark.shield.fill",
                label: L10n.zh("高风险", en: "High Risk"),
                value: "\(highRiskCount(vm: vm))",
                color: PulseColors.danger
            )
            StatCard(
                icon: "xmark.shield.fill",
                label: L10n.zh("已拦截", en: "Blocked"),
                value: "\(blockedCount(vm: vm))",
                color: PulseColors.amber
            )
        }
    }

    // MARK: - Scores Section

    private func scoresSection(vm: ManipulationViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("操纵评分", en: "Manipulation Scores"))

            if vm.scores.isEmpty {
                EmptyStateView(
                    icon: "shield.checkered",
                    title: L10n.zh("暂无评分数据", en: "No Score Data"),
                    description: L10n.zh("输入交易对并点击「扫描」开始操纵风险检测", en: "Enter a trading pair and click Scan to start manipulation risk detection"),
                    primaryAction: (title: L10n.zh("扫描 BTC/USDT", en: "Scan BTC/USDT"), action: {
                        vm.scanSymbol = "BTC/USDT"
                        Task { await vm.scan() }
                    })
                )
            } else {
                LazyVStack(spacing: PulseSpacing.sm) {
                    ForEach(Array(vm.sortedScores.enumerated()), id: \.element.id) { index, item in
                        ManipulationScoreRow(score: item)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func highRiskCount(vm: ManipulationViewModel) -> Int {
        vm.scores.filter { $0.riskLevel == "high" || $0.riskLevel == "critical" }.count
    }

    private func blockedCount(vm: ManipulationViewModel) -> Int {
        vm.scores.filter { $0.riskLevel == "critical" }.count
    }
}
