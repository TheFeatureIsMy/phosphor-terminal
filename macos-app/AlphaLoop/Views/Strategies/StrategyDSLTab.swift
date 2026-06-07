// StrategyDSLTab.swift — DSL JSON 编辑 + 验证 + 保存版本

import SwiftUI

struct StrategyDSLTab: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: StrategyDetailViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                editorSection
                actionBar
                if let report = viewModel.validationReport {
                    DSLValidationReportView(report: report)
                }
                if viewModel.versionSaveSuccess {
                    savedBanner
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                TerminalLabel(text: "StrategyRuleDSL v2.5")
                Spacer()
                if let v = viewModel.latestVersion {
                    Text("当前版本: v\(v.versionNo)")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }

            TextEditor(text: $viewModel.dslText)
                .font(PulseFonts.label)
                .foregroundStyle(colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(PulseSpacing.sm)
                .frame(minHeight: 400, maxHeight: 600)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(editorBorderColor, lineWidth: 1)
                )
        }
    }

    private var editorBorderColor: Color {
        if let report = viewModel.validationReport {
            return report.valid ? PulseColors.success.opacity(0.4) : PulseColors.danger.opacity(0.4)
        }
        return colors.border
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            KryptonButton(title: viewModel.isValidating ? "验证中..." : "验证 DSL") {
                Task { await viewModel.validateDSL() }
            }
            .disabled(viewModel.isValidating || viewModel.dslText.isEmpty)

            if viewModel.canSaveVersion {
                KryptonButton(title: viewModel.isSavingVersion ? "保存中..." : "保存为新版本") {
                    Task { await viewModel.saveVersion() }
                }
                .disabled(viewModel.isSavingVersion)
            }

            Spacer()

            Text("仅支持白名单指标 / 操作符 / 规则类型")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - Saved banner

    private var savedBanner: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PulseColors.success)
            Text("版本已保存 — v\(viewModel.versions.first?.versionNo ?? 0)")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(PulseColors.success)
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(PulseColors.success.opacity(0.08))
        )
    }
}
