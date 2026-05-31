// StrategiesListView.swift — 策略列表页面
// 统计摘要 + 策略卡片网格 + 新建按钮

import SwiftUI

struct StrategiesListView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: StrategiesViewModel
    @Environment(\.networkClient) private var networkClient
    @State private var selectedStrategy: Strategy?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // 头部：统计 + 新建按钮
                header

                if viewModel.isLoading {
                    loadingGrid
                } else if viewModel.strategies.isEmpty {
                    EmptyStateView(
                        icon: "cpu",
                        title: "暂无策略",
                        description: "创建你的第一个量化交易策略",
                        primaryAction: (title: "新建策略", action: { viewModel.showCreateSheet = true })
                    )
                    .frame(height: 300)
                } else {
                    // 策略卡片网格
                    LazyVGrid(columns: gridColumns, spacing: PulseSpacing.md) {
                        ForEach(Array(viewModel.strategies.enumerated()), id: \.element.id) { index, strategy in
                            StrategyCardView(strategy: strategy) {
                                selectedStrategy = strategy
                            } onDeploy: {
                                Task { await viewModel.deploy(id: strategy.id) }
                            } onStop: {
                                Task { await viewModel.stop(id: strategy.id) }
                            } onDelete: {
                                Task { await viewModel.delete(id: strategy.id) }
                            }
                            .staggeredAppearance(index: index)
                        }
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            StrategyCreateSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedStrategy) { strategy in
            StrategyDetailView(strategyId: strategy.id, client: networkClient)
                .frame(minWidth: 800, minHeight: 600)
        }
    }

    // MARK: - 头部
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text("策略管理")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)

                HStack(spacing: PulseSpacing.md) {
                    statBadge("总计", value: "\(viewModel.strategies.count)")
                    statBadge("运行中", value: "\(viewModel.activeCount)", color: PulseColors.statusActive)
                    statBadge("平均夏普", value: String(format: "%.2f", viewModel.averageSharpe), color: PulseColors.accent)
                }
            }

            Spacer()

            ProofAlphaButton(title: "新建策略") {
                viewModel.showCreateSheet = true
            }
        }
    }

    private func statBadge(_ label: String, value: String, color: Color? = nil) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text(label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(color ?? colors.textSecondary)
        }
    }

    // MARK: - 网格列配置
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 280, maximum: 360), spacing: PulseSpacing.md)
        ]
    }

    // MARK: - 加载骨架
    private var loadingGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: PulseSpacing.md) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 180)
                    .shimmer()
            }
        }
    }
}
