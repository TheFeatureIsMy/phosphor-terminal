// AgentPlatformView.swift — Agent 平台主视图
// Agent 配置文件网格 + 性能指标 + 最近信号

import SwiftUI

struct AgentPlatformView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(ErrorHandler.self) private var errorHandler
    @State private var viewModel: AgentPlatformViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                AgentPlatformContent(viewModel: vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = AgentPlatformViewModel(client: networkClient)
                vm.errorHandler = errorHandler
                viewModel = vm
            }
        }
    }
}

// MARK: - 内容视图

private struct AgentPlatformContent: View {
    @Bindable var viewModel: AgentPlatformViewModel
    @Environment(PulseColors.self) private var colors
    @State private var selectedAgent: AgentProfile?

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: PulseSpacing.md)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            headerBar

            Divider().foregroundStyle(colors.border)

            // 内容
            if viewModel.isLoading {
                loadingGrid
            } else if viewModel.agents.isEmpty {
                EmptyStateView(
                    icon: "person.3.sequence",
                    title: "暂无 Agent",
                    description: "配置并启动 AI 代理后，将在此处显示其状态和信号"
                )
            } else {
                agentGrid
            }
        }
        .task { await viewModel.loadAll() }
        .sheet(item: $selectedAgent) { agent in
            AgentDetailView(
                agent: agent,
                signals: viewModel.recentSignals(for: agent)
            )
        }
    }

    // MARK: - 顶部栏

    private var headerBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text("Agent 平台")
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text("\(viewModel.agents.count)")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(PulseColors.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - Agent 网格

    private var agentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PulseSpacing.md) {
                ForEach(Array(viewModel.agents.enumerated()), id: \.element.id) { index, agent in
                    AgentCardView(
                        agent: agent,
                        signalCount: viewModel.signalCount(for: agent),
                        avgScore: viewModel.avgScore(for: agent),
                        recentSignals: viewModel.recentSignals(for: agent)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAgent = agent
                    }
                    .staggeredAppearance(index: index)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }

    // MARK: - 加载骨架屏

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: PulseSpacing.md) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 220)
                    .shimmerWithDelay(phase: Double(i) * 0.12)
            }
        }
        .padding(PulseSpacing.lg)
    }
}
