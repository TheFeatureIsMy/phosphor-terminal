// StrategyRiskTab.swift — 策略风控配置与决策历史
// RiskPolicy 绑定、CapitalPool 配置、风控决策记录

import SwiftUI

struct StrategyRiskTab: View {
    @Environment(PulseColors.self) private var colors
    let strategyId: String
    let client: NetworkClientProtocol

    @State private var riskEvents: [RiskEvent] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    riskPolicySection
                    capitalPoolSection
                    riskDecisionsSection
                }
                .padding(PulseSpacing.lg)
            }
        }
        .task { await loadRiskData() }
    }

    // MARK: - Risk Policy Binding

    private var riskPolicySection: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "风控策略绑定")

                HStack(spacing: PulseSpacing.md) {
                    policyItem(label: "最大回撤", value: "15%", icon: "arrow.down.right")
                    policyItem(label: "单笔止损", value: "2%", icon: "shield.slash")
                    policyItem(label: "日亏损上限", value: "5%", icon: "calendar.badge.exclamationmark")
                    policyItem(label: "相关性阈值", value: "0.7", icon: "link")
                }
            }
        }
    }

    private func policyItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(PulseColors.warning)
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(colors.textPrimary)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Capital Pool Config

    private var capitalPoolSection: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "资金池配置")

                HStack(spacing: PulseSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分配比例")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text("20%")
                            .font(PulseFonts.tabular)
                            .foregroundStyle(PulseColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最大仓位")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text("$5,000")
                            .font(PulseFonts.tabular)
                            .foregroundStyle(colors.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已使用")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text("$2,100")
                            .font(PulseFonts.tabular)
                            .foregroundStyle(PulseColors.info)
                    }
                }
            }
        }
    }

    // MARK: - Risk Decisions History

    private var riskDecisionsSection: some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: "风控决策记录")
                    Spacer()
                    BadgeDot(color: PulseColors.warning, label: "\(riskEvents.count) 条", size: .small)
                }

                if riskEvents.isEmpty {
                    Text("暂无风控决策记录")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                } else {
                    ForEach(Array(riskEvents.prefix(10).enumerated()), id: \.element.id) { index, event in
                        HStack(spacing: PulseSpacing.sm) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(event.severity.color)
                                .frame(width: 3, height: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.description ?? "—")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textPrimary)
                                    .lineLimit(1)
                                Text(event.actionTaken ?? "无操作")
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                            }
                            Spacer()
                            Text(String(event.createdAt.prefix(10)))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func loadRiskData() async {
        isLoading = true
        defer { isLoading = false }
        let api = APIDashboard(client: client)
        let allEvents = (try? await api.getRiskEvents()) ?? []
        riskEvents = allEvents.filter { $0.strategyId != nil }
    }
}
