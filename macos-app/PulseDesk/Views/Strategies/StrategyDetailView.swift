// StrategyDetailView.swift — 策略详情页
// 标签栏：概览、画布、回测、交易记录

import SwiftUI

struct StrategyDetailView: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy
    let client: NetworkClientProtocol
    @State private var selectedTab = 0

    private let tabs = ["概览", "画布", "回测", "交易记录"]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部信息
            strategyHeader

            // 标签栏
            tabBar

            Divider()
                .foregroundStyle(colors.border)

            // 标签内容
            TabView(selection: $selectedTab) {
                StrategyOverviewTab(strategy: strategy)
                    .tag(0)

                StrategyCanvasTab(strategy: strategy, client: client)
                    .tag(1)

                StrategyBacktestTab(strategy: strategy, client: client)
                    .tag(2)

                TradesView()
                    .tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .navigationTitle(strategy.name)
    }

    // MARK: - 策略头部
    private var strategyHeader: some View {
        HStack(spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(strategy.name)
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)

                HStack(spacing: PulseSpacing.xs) {
                    BadgeView(text: strategy.type.label, color: strategy.type.color, size: .small)
                    BadgeView(text: strategy.status.label, color: strategy.status.color(colors), size: .small)
                }
            }

            Spacer()

            // 关键指标
            HStack(spacing: PulseSpacing.lg) {
                if let sharpe = strategy.sharpeRatio {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("夏普比率")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(String(format: "%.2f", sharpe))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(PulseColors.accent)
                    }
                }
                if let dd = strategy.maxDrawdown {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("最大回撤")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(String(format: "%.1f%%", dd))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(PulseColors.loss)
                    }
                }
            }
        }
        .padding(PulseSpacing.lg)
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
}
