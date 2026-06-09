// ManipulationScoreRow.swift — 操纵评分行
// KryptonCard(.subtle): symbol + 风险等级 + 各子评分条 + 建议 badge

import SwiftUI

struct ManipulationScoreRow: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
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
                        Text(L10n.zh("操纵评分", en: "Manipulation Score"))
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
                        subScoreRow(label: L10n.zh("止损猎杀", en: "Stop Hunt"), value: score.stopHuntScore ?? 0)
                        subScoreRow(label: L10n.zh("持仓集中", en: "Holder Concentration"), value: score.holderConcentrationScore ?? 0)
                    }
                    VStack(spacing: PulseSpacing.xs) {
                        subScoreRow(label: L10n.zh("拉盘砸盘", en: "Pump & Dump"), value: score.pumpDumpScore ?? 0)
                        subScoreRow(label: L10n.zh("流动性陷阱", en: "Liquidity Trap"), value: score.liquidityTrapScore ?? 0)
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
                            Text(isExpanded ? L10n.zh("收起证据", en: "Collapse Evidence") : L10n.zh("展开证据", en: "Expand Evidence"))
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
                        TerminalLabel(text: L10n.zh("证据详情", en: "Evidence Details"))

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
                            actionButton(label: L10n.zh("允许交易", en: "Allow Trading"), color: PulseColors.success)
                            actionButton(label: L10n.zh("减仓", en: "Reduce Position"), color: PulseColors.amber)
                            actionButton(label: L10n.zh("仅模拟", en: "Paper Only"), color: PulseColors.warning)
                            actionButton(label: L10n.zh("拒绝", en: "Reject"), color: PulseColors.danger)
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
            return (L10n.zh("禁止交易", en: "Blocked"), PulseColors.danger)
        }
        if text.contains("critical") || text.contains("extreme") {
            return (L10n.zh("禁止交易", en: "Blocked"), PulseColors.danger)
        }
        if text.contains("avoid") {
            return (L10n.zh("仅模拟", en: "Paper Only"), .orange)
        }
        if text.contains("high") {
            return (L10n.zh("减仓", en: "Reduce"), PulseColors.amber)
        }
        if text.contains("caution") || text.contains("moderate") {
            return (L10n.zh("谨慎", en: "Caution"), PulseColors.amber)
        }
        if text.contains("clean") || text.contains("normal") {
            return (L10n.zh("允许", en: "Allowed"), PulseColors.success)
        }
        return (L10n.zh("待评估", en: "Pending"), PulseColors.info)
    }

    // MARK: - Risk Level

    private var riskLevelLabel: String {
        switch score.riskLevel {
        case "critical": return L10n.zh("严重", en: "Critical")
        case "high": return L10n.zh("高危", en: "High")
        case "medium": return L10n.zh("中等", en: "Medium")
        case "low": return L10n.zh("低风险", en: "Low")
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
                name: L10n.zh("K线异常", en: "Candlestick Anomaly"),
                icon: "chart.bar.xaxis",
                description: L10n.zh("异常影线/吞没形态频率偏高", en: "Abnormal wick/engulfing pattern frequency"),
                severity: severityLevel(score.pumpDumpScore ?? 0)
            ),
            EvidenceItem(
                name: L10n.zh("成交量异常", en: "Volume Anomaly"),
                icon: "waveform.path.ecg",
                description: L10n.zh("成交量突增/清洗交易特征", en: "Volume spikes / wash trading patterns"),
                severity: severityLevel(score.stopHuntScore ?? 0)
            ),
            EvidenceItem(
                name: "Funding/OI",
                icon: "chart.line.uptrend.xyaxis",
                description: L10n.zh("资金费率与持仓量异常偏离", en: "Funding rate & OI abnormal divergence"),
                severity: severityLevel(score.fundingSqueezeScore ?? 0)
            ),
            EvidenceItem(
                name: L10n.zh("链上/钱包", en: "On-Chain/Wallet"),
                icon: "link.circle",
                description: L10n.zh("大额转账/巨鲸钱包异动", en: "Large transfers / whale wallet activity"),
                severity: severityLevel(score.holderConcentrationScore ?? 0)
            ),
            EvidenceItem(
                name: L10n.zh("新闻/KOL", en: "News/KOL"),
                icon: "megaphone",
                description: L10n.zh("KOL 协调喊单/FUD 传播", en: "Coordinated KOL shilling / FUD campaigns"),
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
