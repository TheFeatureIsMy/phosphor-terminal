// SignalCenterView.swift — 信号中心主视图
// V2 信号列表：过滤栏 + 信号卡片 + 自定义玻璃态详情面板（替代原生 sheet）

import SwiftUI

struct SignalCenterView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(ErrorHandler.self) private var errorHandler
    @State private var viewModel: SignalCenterViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SignalCenterContent(viewModel: vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = SignalCenterViewModel(client: networkClient)
                vm.errorHandler = errorHandler
                viewModel = vm
            }
        }
    }
}

// MARK: - 内容视图

private struct SignalCenterContent: View {
    @Bindable var viewModel: SignalCenterViewModel
    @Environment(PulseColors.self) private var colors
    @State private var showCreateSheet = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                Divider().foregroundStyle(colors.border)
                filterBar
                Divider().foregroundStyle(colors.border)

                if viewModel.isLoading {
                    loadingShimmer
                } else if viewModel.filteredSignals.isEmpty {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "暂无信号",
                        description: "运行 AI 研究或手动创建信号后，将在此处显示",
                        primaryAction: (title: "新建信号", action: { showCreateSheet = true })
                    )
                } else {
                    signalList
                }
            }

            // 自定义玻璃态模态面板 — 替代原生 .sheet()
            if let signal = viewModel.selectedSignal {
                PulseModalOverlay {
                    SignalDetailSheet(signal: signal, viewModel: viewModel, onDismiss: { withAnimation(PulseAnimation.springDefault) { viewModel.selectedSignal = nil } })
                } onDismiss: {
                    withAnimation(PulseAnimation.springDefault) {
                        viewModel.selectedSignal = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(PulseAnimation.springDefault, value: viewModel.selectedSignal != nil)
        .task { await viewModel.load() }
    }

    // MARK: - 顶部栏

    private var headerBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text("信号中心")
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text("\(viewModel.signals.count)")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(PulseColors.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

            Spacer()

            ProofAlphaButton(title: "新建信号", action: { showCreateSheet = true }, style: .ghost)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 过滤栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.md) {
                TerminalLabel(text: "来源")
                filterPills(
                    options: ["全部", "AI研究", "TradingAgents", "手动", "Canvas"],
                    selected: viewModel.filterSource ?? "全部"
                ) { viewModel.filterSource = $0 == "全部" ? nil : $0 }

                Rectangle()
                    .fill(colors.border)
                    .frame(width: 1, height: 16)

                TerminalLabel(text: "方向")
                filterPills(
                    options: ["全部", "Long", "Short", "Hold"],
                    selected: viewModel.filterDirection ?? "全部"
                ) { viewModel.filterDirection = $0 == "全部" ? nil : $0 }

                Rectangle()
                    .fill(colors.border)
                    .frame(width: 1, height: 16)

                TerminalLabel(text: "风险")
                filterPills(
                    options: ["全部", "低", "中", "高", "极高"],
                    selected: viewModel.filterRisk ?? "全部"
                ) { viewModel.filterRisk = $0 == "全部" ? nil : $0 }
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.vertical, PulseSpacing.xs)
        }
    }

    private func filterPills(
        options: [String],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(PulseAnimation.easeOutFast) { onSelect(option) }
                } label: {
                    Text(option)
                        .font(PulseFonts.caption)
                        .foregroundStyle(selected == option ? PulseColors.accent : colors.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .fill(selected == option ? PulseColors.accentDim : colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .stroke(
                                    selected == option ? PulseColors.accent.opacity(0.3) : colors.border,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 信号列表

    private var signalList: some View {
        ScrollView {
            LazyVStack(spacing: PulseSpacing.xs) {
                ForEach(Array(viewModel.filteredSignals.enumerated()), id: \.element.id) { index, signal in
                    SignalCardView(signal: signal)
                        .staggeredAppearance(index: index)
                        .onTapGesture {
                            withAnimation(PulseAnimation.springDefault) {
                                viewModel.selectedSignal = signal
                            }
                        }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }

    // MARK: - 加载骨架屏

    private var loadingShimmer: some View {
        VStack(spacing: PulseSpacing.xs) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 88)
                    .shimmerWithDelay(phase: Double(i) * 0.12)
            }
        }
        .padding(PulseSpacing.lg)
    }
}

// MARK: - 可复用玻璃态模态覆层

struct PulseModalOverlay<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    let content: () -> Content
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // 背景遮罩 — 点击关闭
            Rectangle()
                .fill(PulseGlass.modalBackdrop)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // 玻璃面板
            content()
                .background(
                    RoundedRectangle(cornerRadius: PulseGlass.sheetRadius)
                        .fill(PulseGlass.modalSurface)
                        .background(
                            RoundedRectangle(cornerRadius: PulseGlass.sheetRadius)
                                .fill(.ultraThinMaterial)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseGlass.sheetRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseGlass.sheetRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        }
    }
}
