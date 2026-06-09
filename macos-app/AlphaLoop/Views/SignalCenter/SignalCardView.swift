// SignalCardView.swift — 信号卡片
// 显示方向箭头、标的、来源、置信度、评分、风险等级

import SwiftUI

struct SignalCardView: View {
    let signal: SignalV2
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.md) {
                // 左侧：方向箭头
                directionIcon

                // 中间：标的 + 来源 + 理由
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack(spacing: PulseSpacing.xs) {
                        Text(signal.symbol)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)

                        BadgeDot(
                            color: sourceColor,
                            label: sourceLabel,
                            size: .small
                        )
                    }

                    if let reasoning = signal.reasoning {
                        Text(reasoning)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(2)
                    }

                    // 底部：状态 + 到期时间
                    HStack(spacing: PulseSpacing.xs) {
                        BadgeDot(
                            color: statusColor,
                            label: statusLabel,
                            size: .small
                        )

                        Text(relativeExpiry)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()

                // 右侧：置信度 + 评分 + 风险
                VStack(alignment: .trailing, spacing: PulseSpacing.xs) {
                    // 置信度条
                    confidenceBar

                    // 评分徽章
                    if let score = signal.score {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(scoreColor(score))
                            Text(String(format: "%.1f", score))
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(scoreColor(score))
                        }
                    }

                    // 风险等级徽章
                    BadgeDot(
                        color: riskColor,
                        label: riskLabel,
                        size: .small
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .id(settingsState.language)
    }

    // MARK: - 方向图标

    private var directionIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(directionColor.opacity(0.1))
                .frame(width: 36, height: 36)

            Image(systemName: directionIconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(directionColor)
        }
    }

    private var directionIconName: String {
        switch signal.direction.lowercased() {
        case "long": return "arrow.up"
        case "short": return "arrow.down"
        default: return "arrow.right"
        }
    }

    private var directionColor: Color {
        switch signal.direction.lowercased() {
        case "long": return colors.profit
        case "short": return PulseColors.loss
        default: return PulseColors.warning
        }
    }

    // MARK: - 置信度条

    private var confidenceBar: some View {
        HStack(spacing: PulseSpacing.xxs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(colors.surface)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * signal.confidence, height: 4)
                }
            }
            .frame(width: 60, height: 4)

            Text("\(Int(signal.confidence * 100))%")
                .font(PulseFonts.micro)
                .foregroundStyle(confidenceColor)
        }
    }

    private var confidenceColor: Color {
        if signal.confidence >= 0.8 { return colors.profit }
        if signal.confidence >= 0.6 { return PulseColors.warning }
        return PulseColors.loss
    }

    // MARK: - 来源

    private var sourceLabel: String {
        switch signal.sourceType {
        case "ai_research": return L10n.zh("AI研究", en: "AI Research")
        case "tradingagents": return "TA"
        case "manual": return L10n.zh("手动", en: "Manual")
        case "canvas": return "Canvas"
        default: return signal.sourceType
        }
    }

    private var sourceColor: Color {
        switch signal.sourceType {
        case "ai_research": return PulseColors.cyan
        case "tradingagents": return PulseColors.purple
        case "manual": return PulseColors.amber
        case "canvas": return PulseColors.accent
        default: return colors.textMuted
        }
    }

    // MARK: - 状态

    private var statusLabel: String {
        switch signal.status {
        case "pending": return L10n.zh("待处理", en: "Pending")
        case "active": return L10n.zh("已激活", en: "Active")
        case "expired": return L10n.zh("已过期", en: "Expired")
        case "archived": return L10n.zh("已归档", en: "Archived")
        case "rejected": return L10n.zh("已拒绝", en: "Rejected")
        default: return signal.status
        }
    }

    private var statusColor: Color {
        switch signal.status {
        case "pending": return PulseColors.warning
        case "active": return PulseColors.statusActive
        case "expired": return colors.textMuted
        case "archived": return colors.textMuted
        case "rejected": return PulseColors.loss
        default: return colors.textMuted
        }
    }

    // MARK: - 风险

    private var riskLabel: String {
        switch signal.riskLevel {
        case "low": return L10n.zh("低", en: "Low")
        case "medium": return L10n.zh("中", en: "Medium")
        case "high": return L10n.zh("高", en: "High")
        case "critical": return L10n.zh("极高", en: "Critical")
        default: return signal.riskLevel
        }
    }

    private var riskColor: Color {
        switch signal.riskLevel {
        case "low": return PulseColors.statusActive
        case "medium": return PulseColors.warning
        case "high": return PulseColors.loss
        case "critical": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    // MARK: - 辅助

    private func scoreColor(_ score: Double) -> Color {
        if score >= 4.0 { return colors.profit }
        if score >= 3.0 { return PulseColors.warning }
        return PulseColors.loss
    }

    private var relativeExpiry: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: signal.expiresAt) ?? ISO8601DateFormatter().date(from: signal.expiresAt) else {
            return signal.expiresAt
        }
        let delta = date.timeIntervalSinceNow
        if delta <= 0 { return L10n.zh("已到期", en: "Expired") }
        let hours = Int(delta / 3600)
        if hours < 1 { return L10n.zh("\(Int(delta / 60))分钟后到期", en: "\(Int(delta / 60))m left") }
        if hours < 24 { return L10n.zh("\(hours)小时后到期", en: "\(hours)h left") }
        return L10n.zh("\(hours / 24)天后到期", en: "\(hours / 24)d left")
    }
}
