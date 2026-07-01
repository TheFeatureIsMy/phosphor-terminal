// StrategyContextStrip.swift — 折叠区：策略 + 风险 + 晋升门摘要

import SwiftUI

struct StrategyContextStrip: View {
    let run: BacktestRunV2
    @Binding var isExpanded: Bool
    @Environment(PulseColors.self) private var colors
    @Environment(BacktestLabViewModel.self) private var vm

    private var metrics: BacktestMetrics {
        BacktestMetrics(
            totalReturn: run.totalReturn,
            sharpeRatio: run.sharpeRatio,
            maxDrawdown: run.maxDrawdown,
            winRate: run.winRate,
            profitFactor: run.profitFactor,
            totalTrades: run.totalTrades,
            avgTradeDuration: "",
            bestTrade: 0,
            worstTrade: 0
        )
    }

    private var warnings: [RiskWarning] {
        riskWarnings(for: metrics)
    }

    private var strategyLabel: String {
        if let s = vm.selectedStrategy, !s.name.isEmpty {
            return s.name
        }
        return "Strategy #\(run.strategyId)"
    }

    private var gateStatusLine: String {
        guard let r = vm.readiness else {
            return L10n.BacktestLab.Context.noReadiness
        }
        return "\(r.passedCount)/\(r.total) — \(r.grandStatus)"
    }

    private var gateIcon: String {
        guard let r = vm.readiness else { return "questionmark.circle" }
        switch r.grandStatus {
        case "ready_for_live", "paper_passed": return "checkmark.shield"
        case "needs_config", "needs_validation": return "exclamationmark.shield"
        default: return "shield"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                    Text(L10n.BacktestLab.strategyContextCollapsed(strategyLabel, warnings.count, gateStatusLine))
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    Spacer()
                }
                .padding(PulseSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(colors.border)
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    // 1) Strategy metadata
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        HStack(spacing: PulseSpacing.sm) {
                            Image(systemName: "cube")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseColors.accent)
                            Text(strategyLabel)
                                .font(PulseFonts.tabular)
                                .foregroundStyle(colors.textPrimary)
                        }
                        if let desc = vm.selectedStrategy?.description, !desc.isEmpty {
                            Text(desc)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    // 2) Risk warnings list
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        HStack(spacing: PulseSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundStyle(colors.textSecondary)
                            Text(L10n.BacktestLab.Context.risk)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textSecondary)
                        }
                        if warnings.isEmpty {
                            Text(L10n.BacktestLab.Context.noRisk)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                                .padding(.leading, PulseSpacing.lg)
                        } else {
                            ForEach(warnings) { w in
                                HStack(spacing: PulseSpacing.sm) {
                                    Image(systemName: w.level == .red ? "circle.fill" : "circle.dotted")
                                        .font(.system(size: 8))
                                        .foregroundStyle(w.level == .red ? .red : .yellow)
                                    Text(riskWarningMessage(id: w.id))
                                        .font(PulseFonts.caption)
                                        .foregroundStyle(colors.textPrimary)
                                }
                                .padding(.leading, PulseSpacing.lg)
                            }
                        }
                    }

                    // 3) Promotion gate status
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        HStack(spacing: PulseSpacing.sm) {
                            Image(systemName: gateIcon)
                                .font(.system(size: 12))
                                .foregroundStyle(vm.readiness?.grandStatus == "ready_for_live" ? colors.profit : colors.textSecondary)
                            Text(L10n.BacktestLab.Context.promotion)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textSecondary)
                            Spacer()
                        }

                        if let r = vm.readiness {
                            HStack(spacing: PulseSpacing.sm) {
                                Circle()
                                    .fill(r.grandStatus == "ready_for_live" || r.grandStatus == "paper_passed"
                                          ? colors.profit : colors.loss)
                                    .frame(width: 6, height: 6)
                                Text("\(r.passedCount)/\(r.total) \(L10n.zh("通过", en: "passed"))")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            .padding(.leading, PulseSpacing.lg)

                            Text(r.nextAction.label)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                                .padding(.leading, PulseSpacing.lg)
                        } else {
                            Text(L10n.BacktestLab.Context.noReadiness)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                                .padding(.leading, PulseSpacing.lg)
                        }

                        NavigationLink(value: AppRoute.liveReadiness) {
                            HStack(spacing: PulseSpacing.xs) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 10))
                                Text(L10n.BacktestLab.Context.goLive)
                                    .font(PulseFonts.captionMedium)
                            }
                            .foregroundStyle(PulseColors.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, PulseSpacing.lg)
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }
}
