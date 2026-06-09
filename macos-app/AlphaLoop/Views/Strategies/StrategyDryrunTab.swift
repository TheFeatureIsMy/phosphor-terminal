// StrategyDryrunTab.swift — 策略模拟运行状态
// 过滤当前策略的 dryrun 运行，复用 DryrunBotCard 样式

import SwiftUI

struct StrategyDryrunTab: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let strategyId: String
    let client: NetworkClientProtocol

    @State private var dryrunRuns: [StrategyRunV2] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    // Header
                    HStack {
                        TerminalLabel(text: L10n.zh("模拟运行", en: "Paper Trading"))
                        Spacer()
                        BadgeDot(
                            color: activeCount > 0 ? PulseColors.statusActive : colors.textMuted,
                            label: "\(activeCount) \(L10n.zh("运行中", en: "active"))",
                            size: .small
                        )
                    }
                    .padding(.horizontal, PulseSpacing.lg)

                    if dryrunRuns.isEmpty {
                        EmptyStateView(
                            icon: "testtube.2",
                            title: L10n.zh("暂无模拟运行", en: "No Paper Trading Runs"),
                            description: L10n.zh("当前策略没有活跃的 Dryrun 运行", en: "No active dryrun sessions for this strategy")
                        )
                        .padding(PulseSpacing.lg)
                    } else {
                        LazyVStack(spacing: PulseSpacing.sm) {
                            ForEach(Array(dryrunRuns.enumerated()), id: \.element.id) { index, run in
                                dryrunCard(run)
                                    .staggeredAppearance(index: index)
                            }
                        }
                        .padding(.horizontal, PulseSpacing.lg)
                    }
                }
                .padding(.vertical, PulseSpacing.md)
            }
        }
        .id(settingsState.language)
        .task { await loadDryrunRuns() }
    }

    private var activeCount: Int {
        dryrunRuns.filter { $0.status == "running" }.count
    }

    private func dryrunCard(_ run: StrategyRunV2) -> some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.sm) {
                    StatusDot(status: run.status == "running" ? .online : .offline)
                    Text("Dryrun #\(String(run.id.suffix(6)))")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    BadgeDot(
                        color: statusColor(run.status),
                        label: statusLabel(run.status),
                        size: .small
                    )
                }

                HStack(spacing: PulseSpacing.lg) {
                    metricItem(label: L10n.zh("模式", en: "Mode"), value: run.mode)
                    metricItem(label: L10n.zh("状态", en: "Status"), value: statusLabel(run.status))
                    metricItem(label: L10n.zh("开始", en: "Started"), value: run.startedAt.map { String($0.prefix(10)) } ?? "—")
                }
            }
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.statusActive
        case "completed": return PulseColors.info
        case "stopped": return colors.textMuted
        case "error": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "running": return L10n.zh("运行中", en: "Running")
        case "completed": return L10n.zh("已完成", en: "Completed")
        case "stopped": return L10n.zh("已停止", en: "Stopped")
        case "error": return L10n.zh("失败", en: "Failed")
        default: return status
        }
    }

    private func loadDryrunRuns() async {
        isLoading = true
        defer { isLoading = false }
        let api = APIStrategyRuns(client: client)
        let allRuns = (try? await api.listRuns(mode: "dryrun")) ?? []
        dryrunRuns = allRuns
    }
}
