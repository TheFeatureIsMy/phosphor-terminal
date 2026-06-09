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
    @Environment(SettingsState.self) private var settingsState
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
                        title: L10n.Signals.noSignals,
                        description: L10n.Signals.noSignalsDesc,
                        primaryAction: (title: L10n.Signals.createSignal, action: { showCreateSheet = true })
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
        .id(settingsState.language)
        .animation(PulseAnimation.springDefault, value: viewModel.selectedSignal != nil)
        .task { await viewModel.load() }
    }

    // MARK: - 顶部栏

    private var headerBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text(L10n.Signals.title)
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

            KryptonButton(title: L10n.Signals.createSignal, action: { showCreateSheet = true }, style: .ghost)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 过滤栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Signals.source)
                filterPills(
                    options: [L10n.Signals.sourceAll, L10n.Signals.sourceAIResearch, L10n.Signals.sourceTradingAgents, L10n.Signals.sourceManual, L10n.Signals.sourceCanvas],
                    selected: viewModel.filterSource ?? L10n.Signals.sourceAll
                ) { viewModel.filterSource = $0 == L10n.Signals.sourceAll ? nil : $0 }

                Rectangle()
                    .fill(colors.border)
                    .frame(width: 1, height: 16)

                TerminalLabel(text: L10n.Signals.direction)
                filterPills(
                    options: [L10n.Signals.directionAll, "Long", "Short", "Hold"],
                    selected: viewModel.filterDirection ?? L10n.Signals.directionAll
                ) { viewModel.filterDirection = $0 == L10n.Signals.directionAll ? nil : $0 }

                Rectangle()
                    .fill(colors.border)
                    .frame(width: 1, height: 16)

                TerminalLabel(text: L10n.Signals.risk)
                filterPills(
                    options: [L10n.Signals.riskAll, L10n.Signals.riskLow, L10n.Signals.riskMedium, L10n.Signals.riskHigh, L10n.Signals.riskCritical],
                    selected: viewModel.filterRisk ?? L10n.Signals.riskAll
                ) { viewModel.filterRisk = $0 == L10n.Signals.riskAll ? nil : $0 }
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
