// CanvasDSLPreviewPanel.swift — DSL 代码预览侧面板
// Phase 6: 提取为独立组件

import SwiftUI

struct CanvasDSLPreviewPanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let dslText: String
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseColors.accent)
                    Text("DSL PREVIEW")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                        .tracking(1.0)
                }

                Spacer()

                KryptonMiniIconButton(icon: "doc.on.doc", action: onCopy, help: L10n.zh("复制 DSL", en: "Copy DSL"))
                KryptonMiniIconButton(icon: "xmark", action: onClose)
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)

            Divider().overlay(colors.border)

            // Content
            ScrollView(.vertical, showsIndicators: true) {
                Text(dslText.isEmpty ? L10n.zh("// 画布变更后，DSL 代码将在此处实时预览", en: "// Edit the canvas to see live DSL preview here") : dslText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dslText.isEmpty ? colors.textMuted : colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PulseSpacing.sm)
                    .textSelection(.enabled)
            }
            .background(colors.background.opacity(0.5))
        }
        .background(colors.surface.opacity(0.3))
        .id(settingsState.language)
    }
}

// MARK: - Mini Icon Button

struct KryptonMiniIconButton: View {
    @Environment(PulseColors.self) private var colors
    @State private var isHovered = false

    let icon: String
    let action: () -> Void
    var help: String = ""

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovered ? colors.textPrimary : colors.textSecondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .fill(isHovered ? colors.surfaceHover : colors.surface)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}
