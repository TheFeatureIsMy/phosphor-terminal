// StrategyDryrunTab.swift — 策略模拟运行状态
// 过滤当前策略的 dryrun 运行，复用 DryrunBotCard 样式

import SwiftUI

struct StrategyDryrunTab: View {
    @Environment(PulseColors.self) private var colors
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
                        TerminalLabel(text: "模拟运行")
                        Spacer()
                        BadgeDot(
                            color: activeCount > 0 ? PulseColors.statusActive : colors.textMuted,
                            label: "\(activeCount) 运行中",
                            size: .small
                        )
                    }
                    .padding(.horizontal, PulseSpacing.lg)

                    if dryrunRuns.isEmpty {
                        EmptyStateView(
                            icon: "testtube.2",
                            title: "暂无模拟运行",
                            description: "当前策略没有活跃的 Dryrun 运行"
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
                    metricItem(label: "模式", value: run.mode)
                    metricItem(label: "状态", value: statusLabel(run.status))
                    metricItem(label: "开始", value: run.startedAt.map { String($0.prefix(10)) } ?? "—")
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
        case "running": return "运行中"
        case "completed": return "已完成"
        case "stopped": return "已停止"
        case "error": return "失败"
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
