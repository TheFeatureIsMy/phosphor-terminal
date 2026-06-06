// StrategiesListView.swift — v2.5 策略列表
// 创建面板使用覆层方式防止布局跳动

import SwiftUI

struct StrategiesListView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: StrategiesViewModel
    @State private var showCreatePanel = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseSpacing.lg) {
                    header

                    if viewModel.isLoading {
                        loadingGrid
                    } else if viewModel.strategies.isEmpty {
                        EmptyStateView(
                            icon: "cpu",
                            title: "暂无策略",
                            description: "创建你的第一个量化交易策略",
                            primaryAction: (title: "新建策略", action: { withAnimation(PulseAnimation.springDefault) { showCreatePanel = true } })
                        )
                        .frame(height: 300)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: PulseSpacing.md) {
                            ForEach(Array(viewModel.strategies.enumerated()), id: \.element.id) { index, strategy in
                                StrategyCardView(
                                    strategy: strategy,
                                    onTap: {
                                        appState.selectedStrategyV2Id = strategy.id
                                        appState.selectedRoute = .strategyDetail
                                    },
                                    onRename: {
                                        viewModel.targetStrategy = strategy
                                        viewModel.newName = strategy.name
                                        viewModel.showRenameSheet = true
                                    },
                                    onDelete: {
                                        viewModel.targetStrategy = strategy
                                        viewModel.showDeleteConfirm = true
                                    }
                                )
                                .staggeredAppearance(index: index)
                            }
                        }
                    }
                }
                .padding(PulseSpacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)

            // 创建面板 — 覆层方式，不影响下方列表布局
            if showCreatePanel {
                VStack {
                    StrategyCreatePanel(onCancel: {
                        withAnimation(PulseAnimation.springDefault) { showCreatePanel = false }
                    })
                    .padding(.horizontal, PulseSpacing.lg)
                    .padding(.top, PulseSpacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(PulseAnimation.springDefault) { showCreatePanel = false }
                        }
                )
                .transition(.opacity)
            }
        }
        .animation(PulseAnimation.springDefault, value: showCreatePanel)
        .task { await viewModel.load() }
        .alert(L10n.Strategies.deleteTitle, isPresented: $viewModel.showDeleteConfirm) {
            Button(L10n.Common.cancel, role: .cancel) {
                viewModel.targetStrategy = nil
            }
            Button(L10n.Common.delete, role: .destructive) {
                if let target = viewModel.targetStrategy {
                    Task { await viewModel.delete(strategyId: target.id) }
                }
                viewModel.targetStrategy = nil
            }
        } message: {
            Text(L10n.Strategies.deleteMessage)
        }
        .sheet(isPresented: $viewModel.showRenameSheet) {
            renameSheet
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: PulseSpacing.lg) {
            Text(L10n.Strategies.renameTitle)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            TextField(L10n.Strategies.enterName, text: $viewModel.newName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)

            HStack(spacing: PulseSpacing.md) {
                Button(L10n.Common.cancel) {
                    viewModel.showRenameSheet = false
                    viewModel.targetStrategy = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.Common.save) {
                    if let target = viewModel.targetStrategy {
                        let name = viewModel.newName
                        Task { await viewModel.rename(strategyId: target.id, newName: name) }
                    }
                    viewModel.showRenameSheet = false
                    viewModel.targetStrategy = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(PulseSpacing.xl)
        .frame(minWidth: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text("策略管理")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)

                HStack(spacing: PulseSpacing.md) {
                    statBadge("总计", value: "\(viewModel.strategies.count)")
                    statBadge("草稿", value: "\(viewModel.draftCount)", color: PulseColors.info)
                    statBadge("运行中", value: "\(viewModel.activeCount)", color: PulseColors.statusActive)
                }
            }
            Spacer()
            ProofAlphaButton(title: "新建策略") {
                withAnimation(PulseAnimation.springDefault) { showCreatePanel.toggle() }
            }
        }
    }

    private func statBadge(_ label: String, value: String, color: Color? = nil) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text(label).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.monoLabel).foregroundStyle(color ?? colors.textSecondary)
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: PulseSpacing.md)]
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: PulseSpacing.md) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 160).shimmer()
            }
        }
    }
}
