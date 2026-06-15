// CaseDetailView.swift — 操纵案例详情视图
// 展示单个操纵案例的完整信息：头部、交易信号、时间线、证据

import SwiftUI

struct CaseDetailView: View {
    @Environment(PulseColors.self) private var colors

    let caseDetail: ManipulationCaseDetail
    let userProfile: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                headerSection
                tradingSignalCard
                timelineCard
                evidenceCard
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            // Symbol (large)
            Text(caseDetail.symbol)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            // Badges row
            HStack(spacing: PulseSpacing.xs) {
                // Type badge (M1-M8)
                BadgeDot(
                    color: PulseColors.info,
                    label: caseDetail.manipulationType,
                    size: .medium
                )

                // Lifecycle stage badge
                BadgeDot(
                    color: stageColor(caseDetail.lifecycleStage),
                    label: stageLabel(caseDetail.lifecycleStage),
                    size: .medium
                )

                Spacer()

                // Confidence percentage
                HStack(spacing: PulseSpacing.xxs) {
                    Text(L10n.Manipulation.confidence)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textMuted)
                    Text(String(format: "%.0f%%", caseDetail.confidence * 100))
                        .font(PulseFonts.tabular)
                        .foregroundStyle(confidenceColor(caseDetail.confidence))
                }
            }
        }
    }

    // MARK: - Trading Signal Card

    private var tradingSignalCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Manipulation.tradingSignal)

            KryptonCard(emphasis: .bold) {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    // Signal action (large, colored)
                    HStack {
                        Text(caseDetail.tradingSignal.action)
                            .font(PulseFonts.displayHeading)
                            .foregroundStyle(signalActionColor(caseDetail.tradingSignal.action))

                        Spacer()

                        // Risk level badge
                        BadgeDot(
                            color: riskColor(caseDetail.tradingSignal.riskLevel),
                            label: caseDetail.tradingSignal.riskLevel.uppercased(),
                            size: .small
                        )
                    }

                    // Direction + sizing + stop loss
                    HStack(spacing: PulseSpacing.md) {
                        signalDetail(
                            label: L10n.zh("方向", en: "Direction"),
                            value: caseDetail.tradingSignal.direction.uppercased()
                        )
                        signalDetail(
                            label: L10n.zh("仓位", en: "Sizing"),
                            value: caseDetail.tradingSignal.sizing.uppercased()
                        )
                        signalDetail(
                            label: L10n.zh("止损", en: "Stop Loss"),
                            value: caseDetail.tradingSignal.stopLoss.uppercased()
                        )
                    }

                    // Rationale
                    Text(caseDetail.tradingSignal.rationale)
                        .font(PulseFonts.body)
                        .foregroundStyle(colors.textSecondary)

                    // Profile note
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "person.fill")
                            .font(PulseFonts.micro)
                        Text(userProfile == "conservative" ? L10n.Manipulation.conservative : L10n.Manipulation.aggressive)
                            .font(PulseFonts.micro)
                    }
                    .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private func signalDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
        }
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Manipulation.timeline)

            KryptonCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(caseDetail.timeline.enumerated()), id: \.offset) { index, entry in
                        timelineEntry(
                            entry: entry,
                            isCurrent: entry.stage == caseDetail.lifecycleStage,
                            isLast: index == caseDetail.timeline.count - 1
                        )
                    }
                }
            }
        }
    }

    private func timelineEntry(entry: ManipulationStageEntry, isCurrent: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Connector column
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? PulseColors.accent : colors.textMuted.opacity(0.4))
                    .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                    .overlay {
                        if isCurrent {
                            Circle()
                                .stroke(PulseColors.accent.opacity(0.3), lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                    }

                if !isLast {
                    Rectangle()
                        .fill(colors.textMuted.opacity(0.2))
                        .frame(width: 1)
                        .frame(minHeight: 28)
                }
            }
            .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(stageLabel(entry.stage))
                        .font(isCurrent ? PulseFonts.captionMedium : PulseFonts.caption)
                        .foregroundStyle(isCurrent ? PulseColors.accent : colors.textPrimary)

                    Spacer()

                    Text(String(format: "%.0f%%", entry.confidence * 100))
                        .font(PulseFonts.micro)
                        .foregroundStyle(confidenceColor(entry.confidence))
                }

                Text(formatTimestamp(entry.enteredAt))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    // MARK: - Evidence Card

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Manipulation.evidence)

            KryptonCard(emphasis: .subtle) {
                let sortedEvidence = caseDetail.evidence.sorted { $0.value > $1.value }
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: PulseSpacing.md),
                        GridItem(.flexible(), spacing: PulseSpacing.md)
                    ],
                    spacing: PulseSpacing.sm
                ) {
                    ForEach(sortedEvidence, id: \.key) { key, value in
                        evidenceItem(name: key, score: value)
                    }
                }
            }
        }
    }

    private func evidenceItem(name: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            HStack {
                Text(formatEvidenceName(name))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(String(format: "%.0f", score))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(evidenceBarColor(score))
            }

            // Score bar (0-100)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.surface)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(evidenceBarColor(score))
                        .frame(width: geo.size.width * min(score / 100.0, 1.0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Helpers

    private func signalActionColor(_ action: String) -> Color {
        switch action.uppercased() {
        case "AMBUSH", "RIDE": return PulseColors.accent
        case "EXIT", "AVOID", "EXIT/SHORT": return PulseColors.danger
        case "WATCH": return PulseColors.amber
        case "CAUTION": return PulseColors.warning
        default: return colors.textPrimary
        }
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage.lowercased() {
        case "suspected": return PulseColors.info
        case "accumulate": return PulseColors.amber
        case "markup": return PulseColors.accent
        case "distribute": return PulseColors.warning
        case "collapse": return PulseColors.danger
        case "completed": return colors.textMuted
        case "false_alarm": return colors.textMuted
        default: return PulseColors.info
        }
    }

    private func stageLabel(_ stage: String) -> String {
        switch stage.lowercased() {
        case "suspected": return L10n.Manipulation.stageSuspected
        case "accumulate": return L10n.Manipulation.stageAccumulate
        case "markup": return L10n.Manipulation.stageMarkup
        case "distribute": return L10n.Manipulation.stageDistribute
        case "collapse": return L10n.Manipulation.stageCollapse
        case "completed": return L10n.Manipulation.stageCompleted
        case "false_alarm": return L10n.Manipulation.stageFalseAlarm
        default: return stage.uppercased()
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "critical": return PulseColors.danger
        case "high": return PulseColors.amber
        case "medium": return PulseColors.warning
        case "low": return PulseColors.success
        default: return PulseColors.info
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value > 0.75 { return PulseColors.danger }
        if value > 0.50 { return PulseColors.amber }
        return PulseColors.success
    }

    private func evidenceBarColor(_ score: Double) -> Color {
        if score > 70 { return PulseColors.danger }
        if score > 40 { return PulseColors.amber }
        return PulseColors.success
    }

    private func formatEvidenceName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatTimestamp(_ ts: String) -> String {
        // Show "YYYY-MM-DD HH:mm" portion
        String(ts.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }
}
