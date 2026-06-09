// StrategyUpgradeRequestView.swift — Strategy Version Upgrade Approval §9

import SwiftUI

struct StrategyUpgradeRequestView: View {
    @Environment(PulseColors.self) private var colors
    let request: UpgradeRequestResponse
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(PulseColors.cyan)
                Text(L10n.zh("策略升级请求", en: "Upgrade Request"))
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                approvalBadge
            }

            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                infoRow(L10n.zh("目标策略", en: "Strategy"), request.strategyId)
                infoRow(L10n.zh("当前版本", en: "From Version"), request.fromVersionId)
                if let name = request.proposedVersionName {
                    infoRow(L10n.zh("新版本名", en: "Proposed Version"), name)
                }
                if let diff = request.diffSummary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.zh("变更摘要", en: "Diff Summary"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(diff)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textPrimary)
                            .padding(PulseSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.sm)
                                    .fill(PulseColors.accent.opacity(0.04))
                            )
                    }
                }
            }

            if request.approvalStatus == "pending" {
                HStack(spacing: PulseSpacing.sm) {
                    Spacer()
                    Button(L10n.zh("拒绝", en: "Reject")) { onReject?() }
                        .buttonStyle(.bordered)
                        .tint(PulseColors.danger)
                        .controlSize(.small)
                    Button(L10n.zh("批准升级", en: "Approve")) { onApprove?() }
                        .buttonStyle(.borderedProminent)
                        .tint(PulseColors.accent)
                        .controlSize(.small)
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(approvalBorderColor, lineWidth: 1)
                )
        )
    }

    private var approvalBadge: some View {
        let (label, color): (String, Color) = switch request.approvalStatus {
        case "pending":
            (L10n.zh("待审批", en: "Pending"), PulseColors.amber)
        case "approved":
            (L10n.zh("已批准", en: "Approved"), PulseColors.accent)
        case "rejected":
            (L10n.zh("已拒绝", en: "Rejected"), PulseColors.danger)
        default:
            (request.approvalStatus, colors.textMuted)
        }
        return Text(label)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(color.opacity(0.12))
            )
    }

    private var approvalBorderColor: Color {
        switch request.approvalStatus {
        case "pending": PulseColors.amber.opacity(0.2)
        case "approved": PulseColors.accent.opacity(0.2)
        case "rejected": PulseColors.danger.opacity(0.2)
        default: colors.border
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
        }
    }
}
