// DSLValidationReportView.swift — 验证报告展示（errors / warnings / safe_hold）

import SwiftUI

struct DSLValidationReportView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let report: DSLValidationReport

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            // Header
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: report.valid ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .foregroundStyle(report.valid ? PulseColors.success : PulseColors.danger)
                Text(report.valid ? L10n.zh("验证通过", en: "Validation Passed") : L10n.zh("验证失败", en: "Validation Failed"))
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(report.valid ? PulseColors.success : PulseColors.danger)

                Spacer()

                if report.errorCount > 0 {
                    badge(L10n.zh("\(report.errorCount) 错误", en: "\(report.errorCount) errors"), color: PulseColors.danger)
                }
                if report.warningCount > 0 {
                    badge(L10n.zh("\(report.warningCount) 警告", en: "\(report.warningCount) warnings"), color: PulseColors.warning)
                }
            }

            // Safe hold warning
            if report.safeHoldRequired {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(PulseColors.danger)
                    Text(L10n.zh("Safe Hold 触发: ", en: "Safe Hold triggered: ") + report.safeHoldReasons.joined(separator: ", "))
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger)
                }
                .padding(PulseSpacing.xs)
                .background(PulseColors.danger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }

            // Error list
            if !report.errors.isEmpty {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    ForEach(report.errors) { err in
                        errorRow(err, isError: true)
                    }
                }
            }

            // Warning list
            if !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    ForEach(report.warnings) { warn in
                        errorRow(warn, isError: false)
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(report.valid ? PulseColors.success.opacity(0.2) : PulseColors.danger.opacity(0.2), lineWidth: 1)
        )
    }

    private func errorRow(_ item: DSLValidationError, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.xs) {
            Image(systemName: isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(isError ? PulseColors.danger : PulseColors.warning)
                .frame(width: 14, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xxs) {
                    Text(item.code)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textPrimary)
                    Text("at \(item.path)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                Text(item.message)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
