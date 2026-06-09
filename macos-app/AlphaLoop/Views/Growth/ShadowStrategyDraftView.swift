// ShadowStrategyDraftView.swift — Shadow Strategy Draft Detail §7

import SwiftUI

struct ShadowStrategyDraftView: View {
    @Environment(PulseColors.self) private var colors
    let draft: ShadowStrategyDraftResponse
    var onValidate: (() -> Void)?
    var onRequestUpgrade: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            header
            if let pattern = draft.failurePattern {
                failurePatternSection(pattern)
            }
            dslPatchSection
            validationSection
            actionBar
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(colors.border, lineWidth: 1)
                )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(PulseColors.cyan)
                Text(draft.title)
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                statusBadge(draft.status, label: draft.statusLabel)
            }
            if let summary = draft.summary {
                Text(summary)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }

    private func failurePatternSection(_ pattern: FailurePatternInfo) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.zh("失败模式", en: "Failure Pattern"))
                .font(PulseFonts.label)
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: PulseSpacing.md) {
                statItem(L10n.zh("样本数", en: "Samples"), "\(pattern.sampleSize ?? 0)")
                statItem(L10n.zh("总亏损", en: "Total Loss"), String(format: "%.2f", pattern.lossSum ?? 0))
                statItem(L10n.zh("标签", en: "Label"), pattern.label ?? "-")
            }

            if let features = pattern.commonFeatures, !features.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(features, id: \.self) { feature in
                        Text(feature)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.xs)
                                    .fill(PulseColors.amber.opacity(0.1))
                            )
                    }
                }
            }
        }
    }

    private var dslPatchSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.zh("DSL 补丁", en: "DSL Patch"))
                .font(PulseFonts.label)
                .foregroundStyle(colors.textSecondary)

            ForEach(Array(draft.dslPatch.enumerated()), id: \.offset) { _, op in
                HStack(spacing: PulseSpacing.xs) {
                    let opType = (op["op"]?.value as? String) ?? "?"
                    let path = (op["path"]?.value as? String) ?? "?"
                    Text(opType.uppercased())
                        .font(PulseFonts.micro)
                        .foregroundStyle(opType == "add" ? PulseColors.accent : PulseColors.amber)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill((opType == "add" ? PulseColors.accent : PulseColors.amber).opacity(0.1))
                        )
                    Text(path)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.zh("验证状态", en: "Validation"))
                .font(PulseFonts.label)
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: PulseSpacing.md) {
                validationItem(L10n.zh("DSL 校验", en: "DSL Check"), stateFor("dsl_static_validation"))
                validationItem(L10n.zh("增量回测", en: "Backtest"), stateFor("incremental_backtest"))
                validationItem(L10n.zh("Dry-run", en: "Dry-run"), stateFor("dryrun"))
                validationItem(L10n.zh("人工审批", en: "Approval"), stateFor("human_approval"))
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            Spacer()
            if draft.status == "generated" {
                Button(L10n.zh("校验 DSL", en: "Validate DSL")) { onValidate?() }
                    .buttonStyle(.borderedProminent)
                    .tint(PulseColors.cyan)
                    .controlSize(.small)
            }
            if draft.status == "validated" || draft.status == "backtested" || draft.status == "dryrun_passed" {
                Button(L10n.zh("请求升级", en: "Request Upgrade")) { onRequestUpgrade?() }
                    .buttonStyle(.borderedProminent)
                    .tint(PulseColors.accent)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: String, label: String) -> some View {
        Text(label)
            .font(PulseFonts.micro)
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(statusColor(status).opacity(0.12))
            )
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved", "merged_to_strategy_version": PulseColors.accent
        case "validated", "backtested", "dryrun_passed": PulseColors.cyan
        case "human_review": PulseColors.amber
        case "rejected": PulseColors.danger
        default: colors.textMuted
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    private func validationItem(_ label: String, _ state: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: validationIcon(state))
                .font(.system(size: 9))
                .foregroundStyle(validationColor(state))
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func stateFor(_ key: String) -> String {
        (draft.validationState[key]?.value as? String) ?? "pending"
    }

    private func validationIcon(_ state: String) -> String {
        switch state {
        case "passed", "valid": "checkmark.circle.fill"
        case "failed": "xmark.circle.fill"
        case "running": "arrow.triangle.2.circlepath"
        case "required": "person.badge.clock"
        default: "circle.dotted"
        }
    }

    private func validationColor(_ state: String) -> Color {
        switch state {
        case "passed", "valid": PulseColors.accent
        case "failed": PulseColors.danger
        case "running": PulseColors.amber
        default: colors.textMuted
        }
    }
}

// MARK: - FlowLayout helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
