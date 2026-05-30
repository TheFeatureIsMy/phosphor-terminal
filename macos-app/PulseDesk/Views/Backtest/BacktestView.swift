// BacktestView.swift — 回测中心页面
// 配置面板 + 运行按钮 + 结果展示

import SwiftUI

struct BacktestView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @Bindable var viewModel: BacktestViewModel
    @State private var strategies: [Strategy] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // 页面标题
                HStack {
                    Text("回测中心")
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                }

                // 配置面板
                BacktestConfigView(viewModel: viewModel, strategies: strategies)

                // 结果
                if viewModel.isRunning {
                    HStack(spacing: PulseSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在运行回测...")
                            .font(PulseFonts.body)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .cardStyle()
                } else if let result = viewModel.result {
                    BacktestResultsView(backtest: result)
                } else {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "配置并运行回测",
                        description: "选择策略和参数，点击运行按钮开始回测"
                    )
                    .frame(height: 300)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            // 加载策略列表
            do {
                strategies = try await APIStrategies(client: networkClient).list()
            } catch {}
        }
    }
}
