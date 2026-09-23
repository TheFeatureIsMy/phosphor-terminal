// SignalCenterView.swift — 信号中枢主视图(Protocol 风格)
// 严格对照 design-previews-v2/signal-03-protocol.html 布局:
//   hero 统计带 → 过滤条(来源/标的/方向/状态/排序)→ 冲突裁决区 → 信号表(可展开行)
// 布局 1:1,数据求真:无冲突/无数据时显示空态,不造假。

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
    @State private var expandedId: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroSection
                    .staggeredAppearance(index: 0)

                filterCard
                    .staggeredAppearance(index: 1)

                conflictSection
                    .staggeredAppearance(index: 2)

                if viewModel.isLoading {
                    loadingShimmer
                } else if viewModel.filteredSignals.isEmpty {
                    emptyCard
                } else {
                    signalTable
                        .staggeredAppearance(index: 3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: PulseSpacing.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .id(settingsState.language)
        .task { await viewModel.load() }
    }

    // MARK: - Hero(eyebrow + 大标题 + 统计带)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.zh("Signal Center · 信号中枢", en: "Signal Center"))
                .font(PulseFonts.body(13, .semibold))
                .foregroundStyle(PulseColors.accentText)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(L10n.zh("所有交易观点，汇聚一处裁决", en: "Every trading thesis, adjudicated in one place"))
                .font(PulseFonts.display(30, .bold))
                .foregroundStyle(colors.textPrimary)
            Text(L10n.zh("AI、模型、研究、情绪、因子与操控雷达的结果统一生成 Signal，在此判断可信度、生命周期与冲突，再决定发布到策略。",
                         en: "Signals from AI, models, research, sentiment, factors and manipulation radar are unified here — assess confidence, lifecycle and conflicts before publishing to strategies."))
                .font(PulseFonts.body(14))
                .foregroundStyle(colors.textSecondary)
                .frame(maxWidth: 620, alignment: .leading)

            // 统计带
            HStack(spacing: 12) {
                statPill(L10n.Signals.statInField, viewModel.signals.count, .accent)
                statPill(L10n.Signals.statActive, viewModel.count(status: "active"), .up)
                statPill(L10n.Signals.statPending, viewModel.count(status: "pending"), .warn)
                statPill(L10n.Signals.statExpired, viewModel.count(status: "expired"), .neutral)
                statPill(L10n.Signals.statRejected, viewModel.count(status: "rejected"), .down)
                statPill(L10n.Signals.statConflicts, viewModel.conflictGroups.count, .accent)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum StatTone { case accent, up, warn, neutral, down }
    private func statPill(_ k: String, _ v: Int, _ tone: StatTone) -> some View {
        let color: Color = tone == .accent ? PulseColors.accent
            : tone == .up ? PulseColors.bullish
            : tone == .warn ? PulseColors.warning
            : tone == .down ? PulseColors.bearish : colors.textSecondary
        return VStack(alignment: .leading, spacing: 4) {
            Text(k).font(PulseFonts.body(12, .medium)).foregroundStyle(colors.textSecondary)
            Text("\(v)").font(PulseFonts.display(26, .bold)).foregroundStyle(color).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        
        .voltCardSurface()
    }

    // MARK: - 过滤卡

    private var filterCard: some View {
        SignalFilterCard(viewModel: viewModel)
    }

    // MARK: - 冲突裁决区

    private var conflictSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(PulseColors.warning)
                Text(L10n.Signals.conflictTitle)
                    .font(PulseFonts.body(16, .semibold))
                    .foregroundStyle(colors.textPrimary)
                Text("\(viewModel.conflictGroups.count) " + L10n.zh("组待裁决", en: "groups"))
                    .font(PulseFonts.body(12, .medium))
                    .foregroundStyle(colors.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(colors.surface))
            }

            let groups = viewModel.conflictGroups
            if groups.isEmpty {
                Text(L10n.Signals.conflictNone)
                    .font(PulseFonts.body(13))
                    .foregroundStyle(colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(groups) { g in
                        SignalConflictCard(group: g, onAdjudicate: {
                            if let first = (g.longs + g.shorts).first {
                                expandedId = first.id
                            }
                        })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 信号表

    private var signalTable: some View {
        VStack(spacing: 0) {
            // 表头
            HStack {
                ProtocolCardTitle(icon: "waveform", text: L10n.Signals.title + " · \(viewModel.filteredSignals.count) " + L10n.zh("条在列", en: "signals"))
                Spacer()
                Text(L10n.Signals.expandHint)
                    .font(PulseFonts.body(11.5, .semibold))
                    .foregroundStyle(colors.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(colors.surface))
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 12)

            SignalTableHeader()

            // 行
            ForEach(Array(viewModel.filteredSignals.enumerated()), id: \.element.id) { idx, signal in
                Divider().overlay(colors.border)
                SignalTableRow(
                    signal: signal,
                    expanded: expandedId == signal.id,
                    onToggle: {
                        withAnimation(PulseAnimation.easeOutFast) {
                            expandedId = expandedId == signal.id ? nil : signal.id
                        }
                    },
                    onPublish: { Task { await viewModel.publishToStrategy(signal.id) } },
                    onArchive: { Task { await viewModel.archive(signal.id) } }
                )
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        
        .voltCardSurface()
    }

    // MARK: - 空态

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundStyle(colors.textMuted)
            Text(L10n.Signals.noSignals)
                .font(PulseFonts.body(16, .semibold))
                .foregroundStyle(colors.textPrimary)
            Text(L10n.Signals.noSignalsDesc)
                .font(PulseFonts.body(13))
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        
        .voltCardSurface()
    }

    // MARK: - 加载骨架

    private var loadingShimmer: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 72)
                    .shimmerWithDelay(phase: Double(i) * 0.12)
            }
        }
    }
}
