// CandidateCard.swift - 候选策略卡片
// KryptonCard(.balanced): rationale + DSL 预览 + 证据来源 + 版本变化 + 操作按钮

import SwiftUI

struct CandidateCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let candidate: StrategyCandidate
    var onBacktest: (() -> Void)?
    var onConfirm: (() -> Void)?

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: DSL name + status badge
                HStack {
                    Text(candidateName)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    BadgeDot(
                        color: statusColor,
                        label: statusLabel,
                        size: .small
                    )
                }

                // DSL validity indicator
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: dslValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(dslValid ? PulseColors.success : PulseColors.danger)
                    Text(dslValid
                         ? L10n.zh("DSL 校验通过", en: "DSL Valid")
                         : L10n.zh("DSL 校验失败", en: "DSL Invalid"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(dslValid ? PulseColors.success : PulseColors.danger)
                }

                // DSL preview (first 3 lines in monospace)
                Text(dslPreview)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(3)
                    .padding(PulseSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.badge)
                            .fill(colors.surface)
                    )

                // Rationale (evidence-backed reasoning)
                if let rationale = candidate.rationale, !rationale.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.zh("改进依据", en: "Rationale"))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                        HStack(alignment: .top, spacing: PulseSpacing.xxs) {
                            Image(systemName: "brain.head.profile")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(PulseColors.purple)
                            Text(rationale)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                    .padding(PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.purple.opacity(0.04))
                    )
                }

                // Evidence source: source report + source version
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("证据来源", en: "Evidence Source"))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    if let reportId = candidate.sourceGrowthReportId {
                        evidenceRow(icon: "doc.text", label: L10n.zh("来源报告", en: "Source Report"), value: String(reportId.prefix(8)))
                    }
                    if let versionId = candidate.sourceStrategyVersionId {
                        evidenceRow(icon: "arrow.triangle.branch", label: L10n.zh("源版本", en: "Source Version"), value: String(versionId.prefix(8)))
                    }
                    if let versionNo = candidate.confirmedVersionNo {
                        evidenceRow(icon: "checkmark.circle", label: L10n.zh("确认版本号", en: "Confirmed Version"), value: "v\(versionNo)")
                    }
                }

                // DSL errors (if invalid)
                if !dslValid, let errors = candidate.dslErrors {
                    ForEach(Array(errors.prefix(2).enumerated()), id: \.offset) { _, error in
                        if let msg = (error.value as? [String: Any])?["message"] as? String {
                            Text("⚠ \(msg)")
                                .font(PulseFonts.micro)
                                .foregroundStyle(PulseColors.danger)
                        }
                    }
                }

                // Action buttons row
                if candidate.status != "confirmed" && candidate.status != "rejected" {
                    HStack(spacing: PulseSpacing.sm) {
                        Spacer()
                        KryptonButton(title: L10n.zh("回测", en: "Backtest"), action: { onBacktest?() }, style: .ghost)
                        KryptonButton(title: L10n.zh("确认", en: "Confirm"), action: { onConfirm?() })
                    }
                }
            }
        }
        .id(settingsState.language)
    }

    // MARK: - Helpers

    private var dslValid: Bool {
        candidate.dslValid ?? false
    }

    private var candidateName: String {
        guard let dsl = candidate.dsl, let dict = dsl.value as? [String: Any],
              let name = dict["name"] as? String else {
            return L10n.zh("未命名候选", en: "Unnamed Candidate")
        }
        return name
    }

    private var dslPreview: String {
        guard let dsl = candidate.dsl, let dict = dsl.value as? [String: Any] else {
            return L10n.zh("// 暂无 DSL 数据", en: "// No DSL data")
        }
        var lines: [String] = []
        if let name = dict["name"] as? String { lines.append("name: \(name)") }
        if let symbol = dict["symbol"] as? String { lines.append("symbol: \(symbol)") }
        if let risk = dict["risk"] as? [String: Any] {
            if let sl = risk["stoploss"] as? Double { lines.append("stoploss: \(sl)") }
            if let mot = risk["max_open_trades"] as? Int { lines.append("max_open_trades: \(mot)") }
        }
        return lines.prefix(3).joined(separator: "\n")
    }

    private func evidenceRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text(value)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private var statusLabel: String {
        switch candidate.status {
        case "draft", "pending_review": return L10n.zh("待审核", en: "Pending Review")
        case "confirmed": return L10n.zh("已确认", en: "Confirmed")
        case "rejected": return L10n.zh("已拒绝", en: "Rejected")
        default: return candidate.status
        }
    }

    private var statusColor: Color {
        switch candidate.status {
        case "draft", "pending_review": return PulseColors.amber
        case "confirmed": return PulseColors.success
        case "rejected": return PulseColors.danger
        default: return PulseColors.info
        }
    }
}
