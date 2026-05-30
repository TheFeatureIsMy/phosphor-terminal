// CodePreviewSheet.swift — 代码预览弹窗

import SwiftUI

struct CodePreviewSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    let code: String
    let onDeploy: () -> Void
    let onCancel: () -> Void

    @State private var editedCode: String
    @State private var isDeploying = false

    init(code: String, onDeploy: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.code = code
        self.onDeploy = onDeploy
        self.onCancel = onCancel
        self._editedCode = State(initialValue: code)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("策略代码预览")
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                BadgeDot(color: PulseColors.accent, label: "可编辑", size: .small)
            }
            .padding(PulseSpacing.md)

            Divider().foregroundStyle(colors.border)

            // Code editor
            ScrollView {
                TextEditor(text: $editedCode)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .scrollContentBackground(.hidden)
                    .padding(PulseSpacing.sm)
            }
            .background(colors.surface)
            .frame(minHeight: 300)

            Divider().foregroundStyle(colors.border)

            // Actions
            HStack(spacing: PulseSpacing.md) {
                Button("取消") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.textSecondary)

                Spacer()

                if isDeploying {
                    HStack(spacing: PulseSpacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("部署中...")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                } else {
                    ProofAlphaButton(title: "部署策略") {
                        isDeploying = true
                        onDeploy()
                    }
                }
            }
            .padding(PulseSpacing.md)
        }
        .frame(width: 600, height: 500)
        .background(colors.background)
    }
}
