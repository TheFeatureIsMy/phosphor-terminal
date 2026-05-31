// StrategyDetailView.swift — 策略详情页
// 标签栏：画布、回测、交易记录、版本

import SwiftUI

struct StrategyDetailView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let strategyId: Int
    let client: NetworkClientProtocol

    @State private var strategy: Strategy?
    @State private var selectedTab = 0
    private let tabs = ["画布", "回测", "交易记录", "版本"]

    var body: some View {
        Group {
            if let strategy {
                VStack(spacing: 0) {
                    navBar
                    Divider().foregroundStyle(colors.border)
                    configBar
                    Divider().foregroundStyle(colors.border)
                    tabBar
                    Divider().foregroundStyle(colors.border)
                    tabContent(strategy)
                }
            } else {
                LoadingView(type: .detail)
            }
        }
        .task { await loadStrategy() }
    }

    private func loadStrategy() async {
        let api = APIStrategies(client: client)
        strategy = try? await api.get(id: strategyId)
    }

    // MARK: - 面包屑导航栏
    private var navBar: some View {
        HStack(spacing: PulseSpacing.xs) {
            Button {
                appState.selectedRoute = .strategies
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                    Text("策略列表").font(PulseFonts.caption)
                }
                .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)

            Text("/").foregroundStyle(colors.textMuted).font(PulseFonts.caption)

            Text(strategy?.name ?? "")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if let s = strategy {
                ProofAlphaButton(title: s.status == .active ? "停止" : "部署") {
                    Task {
                        let vm = StrategiesViewModel(client: client)
                        if s.status == .active { await vm.stop(id: s.id) }
                        else { await vm.deploy(id: s.id) }
                    }
                }
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 配置栏
    private var configBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            configItem(label: "名称", value: strategy?.name ?? "")
            Text("|").foregroundStyle(colors.border).font(PulseFonts.micro)
            configPill(label: "市场", value: strategy?.market ?? "", color: PulseColors.accent)
            configPill(label: "交易所", value: strategy?.exchange ?? "", color: PulseColors.purple)
            Spacer()
            Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
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

    private func configPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.caption).foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(PulseAnimation.easeOutFast) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: PulseSpacing.xxs) {
                        Text(tab)
                            .font(selectedTab == index ? PulseFonts.bodyMedium : PulseFonts.body)
                            .foregroundStyle(selectedTab == index ? colors.textPrimary : colors.textSecondary)

                        // 选中下划线
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

    // MARK: - 标签内容
    @ViewBuilder
    private func tabContent(_ strategy: Strategy) -> some View {
        switch selectedTab {
        case 0: StrategyCanvasTab(strategy: strategy, client: client)
        case 1: StrategyBacktestTab(strategy: strategy, client: client)
        case 2: TradesView()
        case 3: StrategyVersionPlaceholder()
        default: EmptyView()
        }
    }
}

// MARK: - 版本占位
struct StrategyVersionPlaceholder: View {
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 32)).foregroundStyle(colors.textMuted)
            Text("版本历史").font(PulseFonts.body).foregroundStyle(colors.textSecondary)
            Text("即将推出").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
