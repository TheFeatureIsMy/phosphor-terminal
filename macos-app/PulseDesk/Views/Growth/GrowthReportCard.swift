// GrowthReportCard.swift — 增长报告卡片
// ProofAlphaCard(.subtle): 报告类型 badge + 时间 + 摘要 + 状态

import SwiftUI

struct GrowthReportCard: View {
    @Environment(PulseColors.self) private var colors
    let report: GrowthReport

    var body: some View {
        ProofAlphaCard(emphasis: .subtle) {
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
    }

    // MARK: - Computed Properties

    private var reportTypeLabel: String {
        switch report.reportType {
        case "daily_review": return "日报"
        case "weekly_review": return "周报"
        case "performance": return "绩效"
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
            return "暂无摘要信息"
        }
        var parts: [String] = []
        if let date = dict["report_date"] as? String { parts.append("日期: \(date)") }
        if let reviewed = dict["total_strategies_reviewed"] as? Int { parts.append("已审查策略: \(reviewed)") }
        if let found = dict["candidates_found"] as? Int { parts.append("发现候选: \(found)") }
        if let top = dict["top_performer"] as? String { parts.append("最佳策略: \(top)") }
        if let wr = dict["avg_win_rate"] as? Double { parts.append("平均胜率: \(String(format: "%.0f%%", wr * 100))") }
        return parts.joined(separator: " · ")
    }

    private var statusLabel: String {
        switch report.status {
        case "completed": return "已完成"
        case "running": return "运行中"
        case "failed": return "失败"
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
