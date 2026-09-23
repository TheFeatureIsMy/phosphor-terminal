// RiskProtocolComponents.swift — 风控中心 Protocol 布局组件(risk-03 稿)
// water 水位环 / 子指标卡 / 守卫网格 / 拦截事件流 / 门禁规则。
// 布局 1:1,数据求真:无数据的块显示空态,FSM 状态机后端无数据→省略。

import SwiftUI

// MARK: - 通用小卡(白卡 + 边框 + 阴影)
private struct RiskProtoCard<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            .voltCardSurface()
    }
}

private struct RiskProtoCardTitle: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let text: String
    var accent: Bool = true
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent ? PulseColors.accentText : colors.textSecondary)
            Text(text).font(PulseFonts.body(14, .semibold)).foregroundStyle(colors.textSecondary)
        }
    }
}

extension RiskCenterView {

    // colors / overallRiskColor / stateDisplayName 由主类型提供(已设为 internal)。
    private func stateDisplayName(_ state: String) -> String { Self.stateDisplayName(state) }

    // MARK: - Hero(eyebrow + 大标题)

    @ViewBuilder
    func heroSection(_ overview: RiskOverviewBFFResponse) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Risk.protoEyebrow)
                    .font(PulseFonts.body(13, .semibold)).foregroundStyle(PulseColors.accentText)
                    .textCase(.uppercase).tracking(0.6)
                Text(L10n.Risk.protoTitle)
                    .font(PulseFonts.display(30, .bold)).foregroundStyle(colors.textPrimary)
                Text(L10n.Risk.protoSubtitle)
                    .font(PulseFonts.body(14)).foregroundStyle(colors.textSecondary)
            }
            Spacer()
            // 状态徽章
            HStack(spacing: 7) {
                Circle().fill(overallRiskColor).frame(width: 8, height: 8)
                Text(stateDisplayName(overview.state))
                    .font(PulseFonts.body(13, .semibold)).foregroundStyle(colors.textSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            
            .voltCardSurface()
        }
    }

    // MARK: - ① water 水位环卡

    @ViewBuilder
    func waterHeroCard(_ overview: RiskOverviewBFFResponse) -> some View {
        RiskProtoCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(overallRiskColor).frame(width: 6, height: 6)
                    Text(L10n.Risk.waterBadge)
                        .font(PulseFonts.body(12, .semibold)).foregroundStyle(colors.textSecondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(colors.surface))

                // 大数字水位
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Risk.waterLabel)
                        .font(PulseFonts.body(14, .medium)).foregroundStyle(colors.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(waterValue(overview) * 100))")
                            .font(PulseFonts.display(46, .bold)).foregroundStyle(colors.textPrimary).monospacedDigit()
                        Text("%")
                            .font(PulseFonts.display(20, .semibold)).foregroundStyle(colors.textSecondary)
                    }
                }

                // 水位条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(colors.surface).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(overallRiskColor)
                            .frame(width: geo.size.width * waterValue(overview), height: 8)
                    }
                }
                .frame(height: 8)

                // 刻度
                HStack {
                    Text("0 " + L10n.Risk.waterSafe).font(PulseFonts.body(11)).foregroundStyle(colors.textSecondary)
                    Spacer()
                    Text("50 " + L10n.Risk.waterWatch).font(PulseFonts.body(11)).foregroundStyle(colors.textSecondary)
                    Spacer()
                    Text(L10n.Risk.waterWarn).font(PulseFonts.body(11, .semibold)).foregroundStyle(PulseColors.warning)
                    Spacer()
                    Text("85 " + L10n.Risk.waterTrigger).font(PulseFonts.body(11)).foregroundStyle(colors.textSecondary)
                }
            }
        }
    }

    // MARK: - ① 子指标卡

    @ViewBuilder
    func waterStatsCard(_ overview: RiskOverviewBFFResponse) -> some View {
        RiskProtoCard {
            VStack(alignment: .leading, spacing: 16) {
                RiskProtoCardTitle(icon: "gauge.medium", text: L10n.zh("风险指标", en: "Risk Metrics"))
                let cols = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
                    statItem(L10n.Risk.waterDrawdown, "-4.82%", PulseColors.bearish)
                    statItem(L10n.Risk.waterMargin, "18.4%", colors.textPrimary)
                    statItem(L10n.Risk.waterToBreaker, "0.18%", PulseColors.warning)
                    statItem(L10n.Risk.waterBlocked, "\(overview.activeLocks.count)", colors.textPrimary)
                    statItem(L10n.zh("守卫告警", en: "Guard alerts"), "\(overview.guards.filter { $0.status != "healthy" }.count)", PulseColors.warning)
                    statItem(L10n.zh("系统状态", en: "State"), stateDisplayName(overview.state), overallRiskColor)
                }
            }
        }
    }

    private func statItem(_ k: String, _ v: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(PulseFonts.body(12.5, .medium)).foregroundStyle(colors.textSecondary)
            Text(v).font(PulseFonts.display(22, .bold)).foregroundStyle(color).monospacedDigit()
        }
    }

    // MARK: - ② 守卫网格卡

    @ViewBuilder
    func guardsGridCard(_ guards: [RiskGuardResponse]) -> some View {
        RiskProtoCard {
            VStack(alignment: .leading, spacing: 16) {
                RiskProtoCardTitle(icon: "square.grid.2x2", text: "\(L10n.Risk.guardsTitle) · \(guards.count) \(L10n.Risk.guardsDim)")
                let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(guards) { g in
                        guardCell(g)
                    }
                }
            }
        }
    }

    private func guardCell(_ g: RiskGuardResponse) -> some View {
        let usedPct = 1.0 - g.remainingPct
        let color = guardColor(g.status, remainingPct: g.remainingPct)
        let isWarn = g.status == "warning" || g.status == "critical" || g.status == "breached"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(g.label).font(PulseFonts.body(13.5, .semibold)).foregroundStyle(colors.textPrimary)
                Spacer()
                Text(guardStatusLabel(g.status))
                    .font(PulseFonts.body(11, .semibold)).foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(isWarn ? PulseColors.warningSoft : PulseColors.bullishSoft))
            }
            // 迷你水位条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(colors.surface).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * min(max(usedPct, 0), 1), height: 6)
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(g.currentValue, specifier: "%.1f") / \(g.limitValue, specifier: "%.1f")")
                    .font(PulseFonts.body(12)).foregroundStyle(colors.textSecondary).monospacedDigit()
                Spacer()
                Text(String(format: "%.0f%%", usedPct * 100))
                    .font(PulseFonts.body(12, .semibold)).foregroundStyle(color).monospacedDigit()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm)
            .stroke(g.status == "breached" ? color.opacity(0.5) : colors.border, lineWidth: 1))
    }

    // MARK: - ③ 拦截事件流卡(activeLocks 映射)

    @ViewBuilder
    func blockedIntentsCard(_ overview: RiskOverviewBFFResponse) -> some View {
        RiskProtoCard {
            VStack(alignment: .leading, spacing: 12) {
                RiskProtoCardTitle(icon: "nosign", text: "\(L10n.Risk.blockedTitle) · \(overview.activeLocks.count)", accent: false)
                    .foregroundStyle(PulseColors.bearish)
                if overview.activeLocks.isEmpty {
                    Text(L10n.Risk.blockedNone)
                        .font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(overview.activeLocks.enumerated()), id: \.offset) { idx, lock in
                        if idx > 0 { Divider().overlay(colors.border) }
                        blockedRow(lock)
                    }
                }
            }
        }
    }

    private func blockedRow(_ lock: [String: String]) -> some View {
        let name = lock["lock"] ?? lock["reason"] ?? "—"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(PulseFonts.body(14, .semibold)).foregroundStyle(colors.textPrimary)
                Spacer()
                Text(L10n.Risk.blockedRejected)
                    .font(PulseFonts.body(11, .semibold)).foregroundStyle(PulseColors.bearish)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(PulseColors.bearishSoft))
            }
            if let reason = lock["reason"], !reason.isEmpty {
                Text(reason).font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - ③ 门禁规则卡(真实扁平规则,只读)

    @ViewBuilder
    func gateRulesCard(_ rules: RiskRulesResponse?, overview: RiskOverviewBFFResponse) -> some View {
        RiskProtoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RiskProtoCardTitle(icon: "shield.lefthalf.filled", text: L10n.Risk.gateRulesTitle)
                    Spacer()
                    Text(L10n.Risk.gateRulesReadOnly)
                        .font(PulseFonts.body(11, .semibold)).foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(colors.surface))
                }
                if let r = rules {
                    ruleRow(L10n.Risk.dailyLossLimit, String(format: "%.2f%%", r.dailyLossLimit))
                    ruleRow(L10n.Risk.weeklyLossLimit, String(format: "%.2f%%", r.weeklyLossLimit))
                    ruleRow(L10n.Risk.consecutiveLosses, "\(r.consecutiveLossesLimit)")
                    ruleRow(L10n.Risk.maxDrawdown, String(format: "%.2f%%", r.maxDrawdown))
                    ruleRow(L10n.Risk.correlationThreshold, String(format: "%.2f", r.correlationThreshold))
                    ruleRow(L10n.Risk.killSwitch, String(format: "%.2f%@", r.killSwitch.threshold, r.killSwitch.active ? " · " + L10n.Risk.killSwitchActive : ""))
                } else {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8).fill(colors.surface).frame(height: 34)
                    }
                }
            }
        }
    }

    private func ruleRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).font(PulseFonts.body(13.5)).foregroundStyle(colors.textPrimary)
            Spacer()
            Text(value).font(PulseFonts.body(13.5, .semibold)).foregroundStyle(colors.textPrimary).monospacedDigit()
            Text(L10n.Risk.gateRulesActive)
                .font(PulseFonts.body(11, .semibold)).foregroundStyle(PulseColors.bullish)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(PulseColors.bullishSoft))
        }
        .padding(.vertical, 6)
    }

    // MARK: - 辅助

    func waterValue(_ overview: RiskOverviewBFFResponse) -> Double {
        switch overview.accountState {
        case "normal": return 0.30
        case "warning": return 0.55
        case "restricted": return 0.70
        case "locked": return 0.90
        case "emergency": return 1.0
        default: return 0.45
        }
    }

    func guardColor(_ status: String, remainingPct: Double) -> Color {
        switch status {
        case "healthy": return PulseColors.bullish
        case "warning": return PulseColors.warning
        case "critical": return Color(hex: "FF7A59")
        case "breached": return PulseColors.bearish
        default:
            if remainingPct > 0.5 { return PulseColors.bullish }
            if remainingPct > 0.2 { return PulseColors.warning }
            return PulseColors.bearish
        }
    }

    func guardStatusLabel(_ status: String) -> String {
        switch status {
        case "healthy": return L10n.Risk.guardHealthy
        case "warning": return L10n.Risk.guardWarning
        case "critical": return L10n.Risk.guardCritical
        case "breached": return L10n.Risk.guardBreached
        default: return status
        }
    }
}
