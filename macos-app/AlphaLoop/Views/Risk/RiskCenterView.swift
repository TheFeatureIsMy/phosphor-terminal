// RiskCenterView.swift — 风控中心（重新设计：作战指挥室风格）

import SwiftUI

struct RiskCenterView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: RiskCenterViewModel?
    @State private var pulsePhase: CGFloat = 0
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false

    private var resolvedMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel?.overview?.state,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveWireStrip(mode: resolvedMode)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    if let vm = viewModel {
                        if vm.isLoading && vm.overview == nil {
                            LoadingView(type: .detail)
                        } else if let overview = vm.overview {
                            heroSection(overview)
                                .staggeredAppearance(index: 0)

                            // Row 1: water hero(5) + 子指标(7)
                            HStack(alignment: .top, spacing: 18) {
                                waterHeroCard(overview)
                                    .frame(width: 380)
                                waterStatsCard(overview)
                            }
                            .staggeredAppearance(index: 1)

                            // 守卫网格
                            guardsGridCard(overview.guards)
                                .staggeredAppearance(index: 2)

                            // Row: 拦截事件流(7) + 门禁规则(5)
                            HStack(alignment: .top, spacing: 18) {
                                blockedIntentsCard(overview)
                                gateRulesCard(vm.riskRules, overview: overview)
                                    .frame(width: 400)
                            }
                            .staggeredAppearance(index: 3)

                            // 新开仓控制
                            blockUnblockRow(overview)
                                .staggeredAppearance(index: 4)

                        } else if let error = vm.error {
                            EmptyStateView(
                                icon: "exclamationmark.triangle",
                                title: L10n.Common.error,
                                description: error,
                                primaryAction: (title: L10n.Common.retry, action: { Task { await vm.loadOverview() } })
                            )
                        } else {
                            EmptyStateView(
                                icon: "shield.checkered",
                                title: L10n.Common.noData,
                                description: L10n.zh("风控系统尚未返回数据", en: "Risk system has not returned data")
                            )
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: PulseSpacing.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .id(settingsState.language)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .task { await viewModel?.loadRiskRules() }
        }
        .riskAtmosphericBackground(tint: overallRiskColor)
        .task {
            let vm = RiskCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadOverview()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
        // Block confirm dialog
        .confirmDialog(
            isPresented: $showBlockConfirm,
            title: L10n.Risk.confirmBlock,
            message: String(format: L10n.Risk.confirmBlockMessage, viewModel?.overview?.activeLocks.count ?? 0),
            confirmLabel: L10n.Risk.blockNewEntries,
            confirmStyle: .warning,
            onConfirm: { Task { await viewModel?.blockNewEntries() } }
        )
        // Unblock confirm dialog
        .confirmDialog(
            isPresented: $showUnblockConfirm,
            title: L10n.Risk.confirmUnblock,
            message: L10n.Risk.confirmUnblockMessage,
            confirmLabel: L10n.Risk.unblock,
            confirmStyle: .warning,
            onConfirm: { Task { await viewModel?.unblock() } }
        )
    }

    var overallRiskColor: Color {
        guard let overview = viewModel?.overview else { return PulseColors.accent }
        return Self.riskColor(for: overview.state)
    }

    static func riskColor(for state: String) -> Color {
        switch state {
        case "normal": return PulseColors.bullish
        case "warning", "degraded": return PulseColors.warning
        case "emergency", "locked": return PulseColors.bearish
        default: return PulseColors.coral
        }
    }

    static func stateDisplayName(_ state: String) -> String {
        switch state {
        case "normal": return L10n.zh("正常", en: "Normal")
        case "warning": return L10n.zh("警告", en: "Warning")
        case "degraded": return L10n.zh("降级", en: "Degraded")
        case "locked": return L10n.zh("锁定", en: "Locked")
        case "emergency": return L10n.zh("紧急", en: "Emergency")
        default: return state
        }
    }

    static func accountStateLabel(_ state: String) -> String {
        switch state {
        case "normal": return "SAFE"
        case "warning": return "WARN"
        case "restricted": return "RISK"
        case "locked": return "LOCK"
        case "emergency": return "HALT"
        default: return "—"
        }
    }

    // MARK: - Block / Unblock Row

    private func blockUnblockRow(_ overview: RiskOverviewBFFResponse) -> some View {
        VStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: L10n.Risk.newEntriesControl)

            HStack(spacing: PulseSpacing.md) {
                Button {
                    showBlockConfirm = true
                } label: {
                    Label(L10n.Risk.blockNewEntries, systemImage: "hand.raised")
                }
                .buttonStyle(.bordered)
                .tint(PulseColors.warning)
                .disabled(overview.activeLocks.contains { $0["lock"] == "manual_block" })

                Button {
                    showUnblockConfirm = true
                } label: {
                    Label(L10n.Risk.unblock, systemImage: "hand.thumbsup")
                }
                .buttonStyle(.bordered)
                .tint(PulseColors.accentText)
                .disabled(!overview.activeLocks.contains { $0["lock"] == "manual_block" })

                Spacer()
            }
        }
    }
}

// MARK: - Arc Gauge Component

private struct ArcGauge: View {
    let value: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            ArcShape(startAngle: -135, endAngle: 135)
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            ArcShape(startAngle: -135, endAngle: -135 + 270 * value)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color],
                        center: .center,
                        startAngle: .degrees(-135),
                        endAngle: .degrees(-135 + 270 * value)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)

            // End dot
            Circle()
                .fill(color)
                .frame(width: lineWidth + 2, height: lineWidth + 2)
                .shadow(color: color.opacity(0.5), radius: 4)
                .offset(arcEndOffset(angle: -135 + 270 * value, radius: size / 2))
        }
    }

    private func arcEndOffset(angle: Double, radius: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        return CGSize(
            width: radius * cos(radians),
            height: radius * sin(radians)
        )
    }
}

// MARK: - Arc Shape

private struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}
