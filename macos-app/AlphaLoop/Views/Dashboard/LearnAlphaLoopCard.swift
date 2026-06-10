// LearnAlphaLoopCard.swift — Dashboard 顶部"学习 AlphaLoop"卡片
//
// 引导新用户打开用户指南。点击 chip 跳到对应锚点。
// 可用 UserDefaults["hideLearnAlphaLoopCard"] 关闭，在 Settings 中可恢复。

import SwiftUI

struct LearnAlphaLoopCard: View {
    @Environment(PulseColors.self) private var colors
    @AppStorage("hideLearnAlphaLoopCard") private var isHidden: Bool = false
    @State private var showOpenFailedAlert = false

    var body: some View {
        if !isHidden {
            cardContent
                .transition(.opacity.combined(with: .move(edge: .top)))
                .alert(L10n.Guide.openFailed, isPresented: $showOpenFailedAlert) {
                    Button(L10n.Common.close, role: .cancel) {}
                }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack(spacing: PulseSpacing.xs) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PulseColors.accent)
                        Text(L10n.Guide.dashboardTitle)
                            .font(PulseFonts.headline)
                            .foregroundStyle(colors.textPrimary)
                    }
                    Text(L10n.Guide.dashboardSubtitle)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(PulseAnimation.easeOutFast) { isHidden = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 22, height: 22)
                        .hoverGlassStyle(cornerRadius: PulseRadii.sm)
                }
                .buttonStyle(.plain)
                .help(L10n.Guide.dismissCard)
            }

            HStack(spacing: PulseSpacing.xs) {
                chip(label: L10n.Guide.chipWelcome,         icon: "sparkles",         anchor: .welcome)
                chip(label: L10n.Guide.chipConcepts,        icon: "lightbulb",        anchor: .concepts)
                chip(label: L10n.Guide.chipFirstStrategy,   icon: "flag.checkered",   anchor: .firstStrategy)
                Spacer()
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardModifier())
    }

    private func chip(label: String, icon: String, anchor: UserGuide.Anchor) -> some View {
        Button {
            if !UserGuide.open(anchor: anchor) { showOpenFailedAlert = true }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(PulseFonts.caption)
            }
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(colors.surface.opacity(0.6))
            )
            .overlay(
                Capsule().stroke(colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .hoverGlassStyle(cornerRadius: 999)
    }
}
