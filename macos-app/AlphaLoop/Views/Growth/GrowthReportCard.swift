// GrowthReportCard.swift — 增长报告卡片
// KryptonCard(.subtle): 报告类型 badge + 时间 + 摘要 + 状态

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

                // Summary preview (2-3 lines)
                Text(summaryText)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(3)

                // Status badge
                HStack {
                    Spacer()
                    BadgeDot(
                        color: statusColor,
                        label: statusLabel,
                        size: .small
                    )
                }
            }
        }
        .id(settingsState.language)
    }

    // MARK: - Computed Properties

    private var reportTypeLabel: String {
        switch report.reportType {
        case "daily_review": return L10n.zh("日报", en: "Daily Review")
        case "weekly_review": return L10n.zh("周报", en: "Weekly Review")
        case "performance": return L10n.zh("绩效", en: "Performance")
        default: return report.reportType
        }
    }

    private var reportTypeColor: Color {
        switch report.reportType {
        case "daily_review": return PulseColors.accent
        case "weekly_review": return PulseColors.info
        case "performance": return PulseColors.purple
        default: return PulseColors.amber
        }
    }

    private var summaryText: String {
        guard let summary = report.summary,
              let dict = summary.value as? [String: Any] else {
            return L10n.zh("暂无摘要信息", en: "No summary available")
        }
        var parts: [String] = []
        if let date = dict["report_date"] as? String { parts.append(L10n.zh("日期: \(date)", en: "Date: \(date)")) }
        if let reviewed = dict["total_strategies_reviewed"] as? Int { parts.append(L10n.zh("已审查策略: \(reviewed)", en: "Reviewed: \(reviewed)")) }
        if let found = dict["candidates_found"] as? Int { parts.append(L10n.zh("发现候选: \(found)", en: "Candidates: \(found)")) }
        if let top = dict["top_performer"] as? String { parts.append(L10n.zh("最佳策略: \(top)", en: "Top Strategy: \(top)")) }
        if let wr = dict["avg_win_rate"] as? Double { parts.append(L10n.zh("平均胜率: \(String(format: "%.0f%%", wr * 100))", en: "Avg Win Rate: \(String(format: "%.0f%%", wr * 100))")) }
        return parts.joined(separator: " · ")
    }

    private var statusLabel: String {
        switch report.status {
        case "completed": return L10n.zh("已完成", en: "Completed")
        case "running": return L10n.zh("运行中", en: "Running")
        case "failed": return L10n.zh("失败", en: "Failed")
        default: return report.status
        }
    }

    private var statusColor: Color {
        switch report.status {
        case "completed": return PulseColors.success
        case "running": return PulseColors.info
        case "failed": return PulseColors.danger
        default: return PulseColors.amber
        }
    }

    private var formattedDate: String {
        String(report.createdAt.prefix(16))
    }
}
