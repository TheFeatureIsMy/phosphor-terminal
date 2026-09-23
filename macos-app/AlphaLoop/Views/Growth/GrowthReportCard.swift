// GrowthReportCard.swift - 增长报告卡片
// KryptonCard(.subtle): 报告类型 badge + 时间 + 真实 metrics + findings + suggestions

import SwiftUI

struct GrowthReportCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let report: GrowthReport

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: report_type badge + created_at
                HStack {
                    BadgeDot(
                        color: reportTypeColor,
                        label: reportTypeLabel,
                        size: .small
                    )
                    Spacer()
                    Text(formattedDate)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                // Metrics summary (real data from backend)
                if let metricsDict = metricsDict {
                    metricsGrid(metricsDict)
                } else {
                    Text(L10n.zh("暂无指标数据", en: "No metrics data"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                // Findings (evidence-backed)
                if let findingsArray = findingsArray, !findingsArray.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("发现", en: "Findings"))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                        ForEach(Array(findingsArray.prefix(3).enumerated()), id: \.offset) { _, finding in
                            findingRow(finding)
                        }
                    }
                }

                // Suggestions (actionable improvement recommendations)
                if let suggestions = report.suggestions, !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("优化建议", en: "Suggestions"))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                        ForEach(Array(suggestions.prefix(3).enumerated()), id: \.offset) { _, suggestion in
                            HStack(alignment: .top, spacing: PulseSpacing.xxs) {
                                Image(systemName: "arrowtriangle.right.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(PulseColors.accentText)
                                    .padding(.top, 3)
                                Text(suggestion)
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textSecondary)
                            }
                        }
                    }
                }

                // Strategy version evidence
                if let versionId = report.strategyVersionId {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "link.badge.plus")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(L10n.zh("策略版本: \(String(versionId.prefix(8)))", en: "Strategy Version: \(String(versionId.prefix(8)))"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
        }
        .id(settingsState.language)
    }

    // MARK: - Metrics

    private var metricsDict: [String: Any]? {
        guard let metrics = report.metrics, let dict = metrics.value as? [String: Any] else { return nil }
        return dict
    }

    private var findingsArray: [[String: Any]]? {
        guard let findings = report.findings else { return nil }
        if let arr = findings.value as? [[String: Any]] { return arr }
        return nil
    }

    private func metricsGrid(_ metrics: [String: Any]) -> some View {
       let totalTrades = (metrics["total_trades"] as? Int) ?? 0
        let winRate = (metrics["win_rate"] as? Double) ?? Double(metrics["win_rate"] as? Int ?? 0)
        let totalPnl = (metrics["total_pnl"] as? Double) ?? Double(metrics["total_pnl"] as? Int ?? 0)
        let profitFactor = (metrics["profit_factor"] as? Double) ?? Double(metrics["profit_factor"] as? Int ?? 0)

        return HStack(spacing: PulseSpacing.md) {
            metricCell(label: L10n.zh("交易数", en: "Trades"), value: "\(totalTrades)", color: PulseColors.info)
            metricCell(label: L10n.zh("胜率", en: "Win Rate"), value: String(format: "%.0f%%", winRate * 100), color: winRate >= 0.5 ? PulseColors.success : PulseColors.danger)
            metricCell(label: L10n.zh("总盈亏", en: "Total PnL"), value: String(format: "%.2f", totalPnl), color: totalPnl >= 0 ? PulseColors.success : PulseColors.danger)
            metricCell(label: L10n.zh("盈亏比", en: "PF"), value: String(format: "%.2f", profitFactor), color: profitFactor >= 1.0 ? PulseColors.success : PulseColors.danger)
        }
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func findingRow(_ finding: [String: Any]) -> some View {
        let category = (finding["category"] as? String) ?? ""
        let description = (finding["description"] as? String) ?? ""
        return HStack(alignment: .top, spacing: PulseSpacing.xxs) {
            Text(categoryBadge(category))
                .font(PulseFonts.micro)
                .foregroundStyle(categoryColor(category))
                .frame(width: 40, alignment: .leading)
            Text(description)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    // MARK: - Computed Properties

    private var reportTypeLabel: String {
        switch report.reportType {
        case "daily_review": return L10n.zh("日报", en: "Daily Review")
        case "run_review": return L10n.zh("运行报告", en: "Run Review")
        case "strategy_performance": return L10n.zh("策略绩效", en: "Performance")
        default: return report.reportType
        }
    }

    private var reportTypeColor: Color {
        switch report.reportType {
        case "daily_review": return PulseColors.accent
        case "run_review": return PulseColors.info
        case "strategy_performance": return PulseColors.purple
        default: return PulseColors.amber
        }
    }

    private func categoryBadge(_ category: String) -> String {
        switch category {
        case "strength": return L10n.zh("优势", en: "Strength")
        case "weakness": return L10n.zh("弱点", en: "Weakness")
        case "pattern": return L10n.zh("模式", en: "Pattern")
        case "risk": return L10n.zh("风险", en: "Risk")
        default: return category
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "strength": return PulseColors.success
        case "weakness": return PulseColors.warning
        case "pattern": return PulseColors.info
        case "risk": return PulseColors.danger
        default: return PulseColors.amber
        }
    }

    private var formattedDate: String {
        String(report.createdAt.prefix(16))
    }
}
