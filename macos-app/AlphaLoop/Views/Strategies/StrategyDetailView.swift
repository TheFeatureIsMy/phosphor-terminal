// StrategyDetailView.swift — 策略详情页 v2.5
// Tabs: 概览 / DSL 规则 / 回测 / 版本

import SwiftUI

struct StrategyDetailView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let strategyId: String
    let client: NetworkClientProtocol

    @State private var viewModel: StrategyDetailViewModel?
    @State private var selectedTab = 0
    private let tabs = ["概览", "DSL 规则", "画布", "回测", "版本", "运行记录", "信号", "模拟", "风控", "增长"]

    var body: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    navBar(vm)
                    Divider().foregroundStyle(colors.border)
                    configBar(vm)
                    Divider().foregroundStyle(colors.border)
                    tabBar
                    Divider().foregroundStyle(colors.border)
                    tabContent(vm)
                }
            } else {
                LoadingView(type: .detail)
            }
        }
        .task {
            let vm = StrategyDetailViewModel(strategyId: "\(strategyId)", client: client)
            viewModel = vm
            await vm.load()
        }
    }

    // MARK: - Navigation bar

    private func navBar(_ vm: StrategyDetailViewModel) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Button {
                appState.selectedRoute = .strategyWorkspace
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                    Text("策略列表").font(PulseFonts.caption)
                }
                .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)

            Text("/").foregroundStyle(colors.textMuted).font(PulseFonts.caption)

            Text(vm.strategy?.name ?? "加载中...")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if let s = vm.strategy {
                Text(s.statusLabel)
                    .font(PulseFonts.caption)
                    .foregroundStyle(statusColor(s.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(s.status).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - Config bar

    private func configBar(_ vm: StrategyDetailViewModel) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            if let s = vm.strategy {
                configItem(label: "类型", value: s.strategyType)
                Text("|").foregroundStyle(colors.border).font(PulseFonts.micro)
                configItem(label: "来源", value: s.sourceType)
                Text("|").foregroundStyle(colors.border).font(PulseFonts.micro)
                configItem(label: "版本数", value: "\(vm.versions.count)")
            }
            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xs)
    }

    private func configItem(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    selectedTab = index
                } label: {
                    VStack(spacing: PulseSpacing.xxs) {
                        Text(tab)
                            .font(selectedTab == index ? PulseFonts.bodyMedium : PulseFonts.body)
                            .foregroundStyle(selectedTab == index ? colors.textPrimary : colors.textSecondary)
                        Rectangle()
                            .fill(selectedTab == index ? PulseColors.accent : .clear)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, PulseSpacing.md)
                    .padding(.vertical, PulseSpacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent(_ vm: StrategyDetailViewModel) -> some View {
        switch selectedTab {
        case 0: StrategyOverviewTab(viewModel: vm)
        case 1: StrategyDSLTab(viewModel: vm)
        case 2: StrategyCanvasWebTab(viewModel: vm, client: client)
        case 3: StrategyBacktestTab(viewModel: vm)
        case 4: StrategyVersionsTab(viewModel: vm)
        case 5: StrategyRunsTab(viewModel: vm, client: client)
        case 6: StrategySignalsTab(strategyId: strategyId, client: client)
        case 7: StrategyDryrunTab(strategyId: strategyId, client: client)
        case 8: StrategyRiskTab(strategyId: strategyId, client: client)
        case 9: StrategyGrowthTab(strategyId: strategyId, client: client)
        default: EmptyView()
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "draft": return colors.textMuted
        case "active": return PulseColors.statusActive
        case "paused": return PulseColors.statusPaused
        case "archived": return PulseColors.statusError
        default: return colors.textMuted
        }
    }
}

