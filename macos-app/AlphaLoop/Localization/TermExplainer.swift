// TermExplainer.swift — 专业术语解释图标组件

import SwiftUI

struct TermExplainer: View {
    let term: String
    let explanation: String
    var fontSize: CGFloat = 13

    @State private var showPopover = false
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 2) {
            Text(term)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))

            Button(action: { showPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: fontSize * 0.8))
                    .foregroundStyle(PulseColors.accent.opacity(0.6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    Text(term)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(PulseColors.accent)

                    Text(explanation)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(PulseSpacing.sm)
                .frame(maxWidth: 260)
            }
        }
    }
}

struct TermText: View {
    let term: String
    var fontSize: CGFloat = 13

    var body: some View {
        if let explanation = TradingTerms.explanation(for: term) {
            TermExplainer(term: term, explanation: explanation, fontSize: fontSize)
        } else {
            Text(term)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
        }
    }
}
