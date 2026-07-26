// PanelChrome.swift — 320px floating panel shell shared by ⌘1–⌘6 panels.
// Protocol 风格: 白卡 + 极轻边框 + 品牌色柔和阴影(非玻璃拟态)。
import SwiftUI

struct PanelChrome<Content: View>: View {
    let title: String
    let icon: String
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(PulseColors.self) private var colors
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(colors.border)

            ScrollView {
                content()
                    .padding(12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card, style: .continuous)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card, style: .continuous))
        .applyShadow(PulseShadow.elevated(colors))
        .focusable()
        .focused($focused)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(colors.surface)
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.Workbench.panelClose)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }
}
