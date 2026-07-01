// ManipulationRadarView.swift — 操纵雷达主视图（重构版）
// 概览仪表盘：头部 + 统计行 + 双栏（案例网格 + 告警流）

import SwiftUI

struct ManipulationRadarView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: ManipulationViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                if vm.isLoading && vm.radarOverview == nil {
                    LoadingView(type: .dashboard)
                        .padding(PulseSpacing.lg)
                } else if let overview = vm.radarOverview {
                    radarContent(vm: vm, overview: overview)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.zh("加载失败", en: "Load Failed"),
                        description: error,
                        primaryAction: (title: L10n.zh("重试", en: "Retry"), action: {
                            Task { await vm.loadRadar() }
                        })
                    )
                    .padding(PulseSpacing.lg)
                } else {
                    EmptyStateView(
                        icon: "shield.checkered",
                        title: L10n.Manipulation.noCases,
                        description: L10n.Manipulation.radarSubtitle
                    )
                    .padding(PulseSpacing.lg)
                }
            } else {
                LoadingView(type: .dashboard)
                    .padding(PulseSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(settingsState.language)
        .task {
            if viewModel == nil {
                let vm = ManipulationViewModel(client: networkClient)
                viewModel = vm
                await vm.loadRadar()
                vm.startLiveUpdates()
                vm.connectStream(baseURL: networkClient.baseURL)
            }
        }
        .onDisappear {
            viewModel?.stopLiveUpdates()
        }
        .sheet(item: detailBinding) { detail in
            CaseDetailView(
                caseDetail: detail,
                userProfile: viewModel?.userProfile ?? "conservative"
            )
            .frame(minWidth: 520, minHeight: 600)
        }
    }

    // Binding for sheet(item:) — focusedDetail drives sheet
    private var detailBinding: Binding<ManipulationCaseDetail?> {
        Binding(
            get: { viewModel?.focusedDetail },
            set: { _ in } // dismiss only; focus managed by focusCase
        )
    }

    // MARK: - Main Content

    private func radarContent(vm: ManipulationViewModel, overview: ManipulationRadarOverview) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                headerRow(vm: vm)
                statsRow(overview: overview)
                twoColumnBody(vm: vm, overview: overview)
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    // MARK: - 1. Header Row

    private func headerRow(vm: ManipulationViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(L10n.Manipulation.radarTitle)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Text(L10n.Manipulation.radarSubtitle)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            HStack(spacing: PulseSpacing.xs) {
                // User profile indicator (toggle removed per Task 4; value still used for /signals)
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: vm.userProfile == "conservative" ? "shield.fill" : "bolt.fill")
                        .font(PulseFonts.label)
                    Text(vm.userProfile == "conservative" ? L10n.Manipulation.conservative : L10n.Manipulation.aggressive)
                        .font(PulseFonts.captionMedium)
                }
                .foregroundStyle(vm.userProfile == "conservative" ? PulseColors.info : PulseColors.amber)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill((vm.userProfile == "conservative" ? PulseColors.info : PulseColors.amber).opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .stroke((vm.userProfile == "conservative" ? PulseColors.info : PulseColors.amber).opacity(0.15), lineWidth: 1)
                )

                // Scan / refresh button
                KryptonButton(title: L10n.Manipulation.startScan, action: {
                    Task { await vm.loadRadar() }
                })
            }
        }
    }

    // MARK: - 2. Stats Row

    private func statsRow(overview: ManipulationRadarOverview) -> some View {
        HStack(spacing: PulseSpacing.md) {
            // Total Active Cases
            StatCard(
                icon: "shield.lefthalf.filled.badge.checkmark",
                label: L10n.Manipulation.activeCases,
                value: "\(overview.totalActive)",
                color: PulseColors.info
            )

            // High Risk Symbols
            KryptonCard(emphasis: .subtle) {
                VStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PulseColors.danger)
                    if overview.highRiskSymbols.isEmpty {
                        Text("—")
                            .font(PulseFonts.displayHeading)
                            .foregroundStyle(colors.textPrimary)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(overview.highRiskSymbols, id: \.self) { sym in
                                Text(sym)
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(PulseColors.danger)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Text(L10n.Manipulation.highRisk)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(maxWidth: .infinity)
            }

            // By Stage breakdown
            KryptonCard(emphasis: .subtle) {
                VStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 18))
                        .foregroundStyle(PulseColors.accent)
                    VStack(spacing: 1) {
                        ForEach(overview.byStage.sorted(by: { $0.key < $1.key }), id: \.key) { stage, count in
                            HStack(spacing: PulseSpacing.xxs) {
                                Text("\(count)")
                                    .font(PulseFonts.tabular)
                                    .foregroundStyle(colors.textPrimary)
                                Text(stage)
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Text(L10n.Manipulation.byStage)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 3. Two-Column Body

    private func twoColumnBody(vm: ManipulationViewModel, overview: ManipulationRadarOverview) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            // Left column (60%): Active Cases Grid
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Manipulation.activeCases)

                if overview.activeCases.isEmpty {
                    EmptyStateView(
                        icon: "shield.checkered",
                        title: L10n.Manipulation.noCases,
                        description: L10n.Manipulation.radarSubtitle
                    )
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: PulseSpacing.sm),
                            GridItem(.flexible(), spacing: PulseSpacing.sm)
                        ],
                        spacing: PulseSpacing.sm
                    ) {
                        ForEach(Array(overview.activeCases.enumerated()), id: \.element.id) { index, caseSummary in
                            CaseCardView(caseSummary: caseSummary)
                                .staggeredAppearance(index: index)
                                .onTapGesture {
                                    Task { await vm.focusCase(caseSummary.id) }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1.5) // ~60%

            // Right column (40%): Alert Feed
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Manipulation.alertFeed)

                ManipulationAlertFeed(alerts: vm.alerts)
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1.0) // ~40%
        }
    }
}
