// PanelChrome.swift — 320px floating glass shell shared by ⌘1–⌘6 panels.
// Per CLAUDE.md: .glassEffect() must be applied directly to the content,
// never inside .background(). Spec §5.3 / Plan 2026-06-18 Task 17.
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
        .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.md))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md, style: .continuous)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
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
