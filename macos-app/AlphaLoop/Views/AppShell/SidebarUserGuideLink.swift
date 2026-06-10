// SidebarUserGuideLink.swift — 侧边栏底部"用户指南"入口
//
// 点击在默认浏览器中打开本地用户指南站点。
// 与导航 AppRoute 无关 —— 不修改 selectedRoute。

import SwiftUI

struct SidebarUserGuideLink: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false
    @State private var showOpenFailedAlert = false

    var body: some View {
        Button {
            let opened = UserGuide.open()
            if !opened { showOpenFailedAlert = true }
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.clear)
                    .frame(width: 3, height: 16)

                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)

                if !appState.sidebarCollapsed {
                    Text(L10n.Guide.sidebarLabel)
                        .font(PulseFonts.body)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(colors.textMuted.opacity(0.6))
                }
            }
            .padding(.vertical, 7).padding(.horizontal, PulseSpacing.xs)
            .frame(maxWidth: .infinity)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(colors.surface.opacity(0.3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
            }
        }
        .buttonStyle(.plain)
        .help(appState.sidebarCollapsed ? L10n.Guide.title : "")
        .alert(L10n.Guide.openFailed, isPresented: $showOpenFailedAlert) {
            Button(L10n.Common.close, role: .cancel) {}
        }
    }

    private var iconColor: Color {
        isHovering ? colors.textPrimary : colors.textSecondary
    }

    private var textColor: Color {
        isHovering ? colors.textPrimary : colors.textSecondary
    }
}
