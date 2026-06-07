// ManipulationScoreRow.swift — 操纵评分行
// KryptonCard(.subtle): symbol + 风险等级 + 各子评分条 + 建议 badge

import SwiftUI

struct ManipulationScoreRow: View {
    @Environment(PulseColors.self) private var colors
    let score: ManipulationScoreV2
    @State private var isExpanded = false

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Top row: symbol + risk badge + suggestion badge
                HStack(spacing: PulseSpacing.sm) {
                    // Symbol name (large)
                    Text(score.symbol)
                        .font(PulseFonts.displaySubheading)
                        .foregroundStyle(colors.textPrimary)

                    BadgeDot(
                        color: riskLevelColor,
                        label: riskLevelLabel,
                        size: .medium
                    )

                    Spacer()

                    // Suggestion badge
                    suggestionBadge
                }

                // Overall manipulation score (prominent)
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack {
                        Text("操纵评分")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textMuted)
                        Spacer()
                        Text(String(format: "%.0f", score.manipulationScore * 100))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(scoreBarColor(score.manipulationScore))
                    }
                    scoreBar(value: score.manipulationScore, height: 8)
                }

                // Sub-scores grid
                HStack(spacing: PulseSpacing.md) {
                    VStack(spacing: PulseSpacing.xs) {
                        subScoreRow(label: "止损猎杀", value: score.stopHuntScore ?? 0)
                        subScoreRow(label: "持仓集中", value: score.holderConcentrationScore ?? 0)
                    }
                    VStack(spacing: PulseSpacing.xs) {
                        subScoreRow(label: "拉盘砸盘", value: score.pumpDumpScore ?? 0)
                        subScoreRow(label: "流动性陷阱", value: score.liquidityTrapScore ?? 0)
                    }
                }

                // Updated at + expand toggle
                HStack {
                    Button {
                        withAnimation(PulseAnimation.easeOutMedium) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(PulseFonts.micro)
                            Text(isExpanded ? "收起证据" : "展开证据")
                                .font(PulseFonts.micro)
                        }
                        .foregroundStyle(colors.textMuted)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text(formattedDate)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                // Expandable evidence section
                if isExpanded {
                    Divider().foregroundStyle(colors.border)

                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        TerminalLabel(text: "证据详情")

                        // Evidence categories
                        ForEach(evidenceCategories, id: \.name) { evidence in
                            HStack(spacing: PulseSpacing.sm) {
                                Image(systemName: evidence.icon)
                                    .font(PulseFonts.label)
                                    .foregroundStyle(evidence.severityColor)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(evidence.name)
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(colors.textPrimary)
                                    Text(evidence.description)
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(colors.textMuted)
                                        .lineLimit(1)
                                }

                                Spacer()

                                // Severity indicator
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i < evidence.severity ? evidence.severityColor : colors.surface)
                                            .frame(width: 8, height: 4)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        Divider().foregroundStyle(colors.border)

                        // Action buttons
                        HStack(spacing: PulseSpacing.xs) {
                            actionButton(label: "允许交易", color: PulseColors.success)
                            actionButton(label: "减仓", color: PulseColors.amber)
                            actionButton(label: "仅模拟", color: PulseColors.warning)
                            actionButton(label: "拒绝", color: PulseColors.danger)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sub-score Row

    private func subScoreRow(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text(String(format: "%.0f", value * 100))
                    .font(PulseFonts.micro)
                    .foregroundStyle(scoreBarColor(value))
            }
            scoreBar(value: value, height: 4)
        }
    }

    // MARK: - Score Bar

    private func scoreBar(value: Double, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.surface)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: 2)
                    .fill(scoreBarColor(value))
                    .frame(width: geo.size.width * min(value, 1.0), height: height)
            }
        }
        .frame(height: height)
    }

    private func scoreBarColor(_ value: Double) -> Color {
        let pct = value * 100
        if pct > 70 { return PulseColors.danger }
        if pct > 40 { return PulseColors.amber }
        return PulseColors.success
    }

    // MARK: - Suggestion Badge

    private var suggestionBadge: some View {
        let (label, color) = suggestionInfo
        return BadgeDot(color: color, label: label, size: .small)
    }

    private var suggestionInfo: (String, Color) {
        let text = score.suggestion.lowercased()
        if text.contains("do not trade") || text.contains("block") {
            return ("禁止交易", PulseColors.danger)
        }
        if text.contains("critical") || text.contains("extreme") {
            return ("禁止交易", PulseColors.danger)
        }
        if text.contains("avoid") {
            return ("仅模拟", .orange)
        }
        if text.contains("high") {
            return ("减仓", PulseColors.amber)
        }
        if text.contains("caution") || text.contains("moderate") {
            return ("谨慎", PulseColors.amber)
        }
        if text.contains("clean") || text.contains("normal") {
            return ("允许", PulseColors.success)
        }
        return ("待评估", PulseColors.info)
    }

    // MARK: - Risk Level

    private var riskLevelLabel: String {
        switch score.riskLevel {
        case "critical": return "严重"
        case "high": return "高危"
        case "medium": return "中等"
        case "low": return "低风险"
        default: return score.riskLevel
        }
    }

    private var riskLevelColor: Color {
        switch score.riskLevel {
        case "critical": return PulseColors.danger
        case "high": return PulseColors.amber
        case "medium": return PulseColors.warning
        case "low": return PulseColors.success
        default: return PulseColors.info
        }
    }

    private var formattedDate: String {
        String(score.updatedAt.prefix(16))
    }

    // MARK: - Evidence Categories

    private var evidenceCategories: [EvidenceItem] {
        [
            EvidenceItem(
                name: "K线异常",
                icon: "chart.bar.xaxis",
                description: "异常影线/吞没形态频率偏高",
                severity: severityLevel(score.pumpDumpScore ?? 0)
            ),
            EvidenceItem(
                name: "成交量异常",
                icon: "waveform.path.ecg",
                description: "成交量突增/清洗交易特征",
                severity: severityLevel(score.stopHuntScore ?? 0)
            ),
            EvidenceItem(
                name: "Funding/OI",
                icon: "chart.line.uptrend.xyaxis",
                description: "资金费率与持仓量异常偏离",
                severity: severityLevel(score.fundingSqueezeScore ?? 0)
            ),
            EvidenceItem(
                name: "链上/钱包",
                icon: "link.circle",
                description: "大额转账/巨鲸钱包异动",
                severity: severityLevel(score.holderConcentrationScore ?? 0)
            ),
            EvidenceItem(
                name: "新闻/KOL",
                icon: "megaphone",
                description: "KOL 协调喊单/FUD 传播",
                severity: severityLevel(score.liquidityTrapScore ?? 0)
            ),
        ]
    }

    private func severityLevel(_ value: Double) -> Int {
        let pct = value * 100
        if pct > 70 { return 3 }
        if pct > 40 { return 2 }
        if pct > 10 { return 1 }
        return 0
    }

    private func actionButton(label: String, color: Color) -> some View {
        Button {
            // Action handler placeholder
        } label: {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(color)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill(color.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Evidence Item Model

private struct EvidenceItem: Hashable {
    let name: String
    let icon: String
    let description: String
    let severity: Int  // 0-3

    var severityColor: Color {
        switch severity {
        case 3: return PulseColors.danger
        case 2: return PulseColors.amber
        case 1: return PulseColors.warning
        default: return PulseColors.success
        }
    }
}
