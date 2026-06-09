// StrategyRiskTab.swift — 策略风控配置与决策历史
// RiskPolicy 绑定、CapitalPool 配置、风控决策记录

import SwiftUI

struct StrategyRiskTab: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
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
        .id(settingsState.language)
        .task { await loadRiskData() }
    }

    // MARK: - Risk Policy Binding

    private var riskPolicySection: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.zh("风控策略绑定", en: "Risk Policy Binding"))

                HStack(spacing: PulseSpacing.md) {
                    policyItem(label: L10n.zh("最大回撤", en: "Max Drawdown"), value: "15%", icon: "arrow.down.right")
                    policyItem(label: L10n.zh("单笔止损", en: "Per-Trade Stop Loss"), value: "2%", icon: "shield.slash")
                    policyItem(label: L10n.zh("日亏损上限", en: "Daily Loss Limit"), value: "5%", icon: "calendar.badge.exclamationmark")
                    policyItem(label: L10n.zh("相关性阈值", en: "Correlation Threshold"), value: "0.7", icon: "link")
                }
            }
        }
    }

    private func policyItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(PulseFonts.displaySubheading)
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
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.zh("资金池配置", en: "Capital Pool Config"))

                HStack(spacing: PulseSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("分配比例", en: "Allocation"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text("20%")
                            .font(PulseFonts.tabular)
                            .foregroundStyle(PulseColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("最大仓位", en: "Max Position"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text("$5,000")
                            .font(PulseFonts.tabular)
                            .foregroundStyle(colors.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("已使用", en: "Utilized"))
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
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: L10n.zh("风控决策记录", en: "Risk Decision Log"))
                    Spacer()
                    BadgeDot(color: PulseColors.warning, label: "\(riskEvents.count) \(L10n.zh("条", en: "entries"))", size: .small)
                }

                if riskEvents.isEmpty {
                    Text(L10n.zh("暂无风控决策记录", en: "No risk decisions recorded"))
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
                                Text(event.actionTaken ?? L10n.zh("无操作", en: "No action"))
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
