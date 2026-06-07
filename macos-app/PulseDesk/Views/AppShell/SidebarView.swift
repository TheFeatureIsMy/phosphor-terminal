// SidebarView.swift — 自定义可折叠侧边栏
// macOS 26 原生 Liquid Glass 选中效果 + 主题切换

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PulseColors.self) private var colors
    @Namespace private var glassNamespace
    @State private var isLogoHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)
            logoHeader

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                        let routes = AppRoute.allCases.filter { $0.section == section && $0.sidebarVisible }
                        if !routes.isEmpty {
                            if !appState.sidebarCollapsed {
                                HStack(spacing: 4) {
                                    Text("//").font(PulseFonts.micro).foregroundStyle(PulseColors.accent.opacity(0.5))
                                    Text(section.label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                                        .textCase(.uppercase).tracking(1.2)
                                }
                                .padding(.horizontal, PulseSpacing.sm)
                                .padding(.top, PulseSpacing.md).padding(.bottom, PulseSpacing.xxs)
                            } else if index == 0 {
                                Divider().foregroundStyle(colors.border)
                                    .padding(.vertical, PulseSpacing.xxs).padding(.horizontal, PulseSpacing.md)
                            }
                            ForEach(routes) { route in
                                let globalIndex = AppRoute.allCases.firstIndex(of: route)
                                SidebarButtonView(route: route, glassNamespace: glassNamespace, shortcutIndex: globalIndex)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollEdgeEffectStyle(.hard, for: .vertical)

            Spacer(minLength: 0)
            sidebarFooter
        }
        .frame(width: appState.sidebarCollapsed ? 56 : 228)
        .overlay(alignment: .trailing) {
            Rectangle().fill(colors.border).frame(width: 0.5)
        }
        .animation(PulseAnimation.springDefault, value: appState.sidebarCollapsed)
    }

    private var logoHeader: some View {
        HStack(spacing: PulseSpacing.xs) {
            Button { appState.toggleSidebar() } label: {
                HStack(spacing: PulseSpacing.xs) {
                    ZStack {
                        if isLogoHovered {
                            PulseRing(color: PulseColors.accent.opacity(0.6), size: 36)
                        }
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PulseColors.accent)
                            .shadow(color: PulseColors.accent.opacity(0.4), radius: 6)
                    }
                    if !appState.sidebarCollapsed {
                        Text("PulseDesk").font(PulseFonts.displaySubheading).foregroundStyle(colors.textPrimary)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) { isLogoHovered = hovering }
            }
            Spacer()
            if !appState.sidebarCollapsed {
                Button { appState.toggleSidebar() } label: {
                    Image(systemName: "sidebar.left").font(.system(size: 12)).foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain).transition(.opacity)
            }
        }
        .padding(.horizontal, PulseSpacing.sm).frame(height: 40)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider().foregroundStyle(colors.border)
            HStack(spacing: PulseSpacing.xs) {
                StatusDot(status: .online)
                if !appState.sidebarCollapsed {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("系统运行中").font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
                        Text("Freqtrade 已连接").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    }
                    Spacer()

                    // 主题切换按钮 — Liquid Glass
                    Button { themeManager.toggle() } label: {
                        Image(systemName: themeManager.current == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.textMuted)
                            .frame(width: 24, height: 24)
                            .hoverGlassStyle(cornerRadius: PulseRadii.md)
                    }
                    .buttonStyle(.plain)
                    .help(themeManager.current == .dark ? "切换明亮模式" : "切换暗黑模式")
                }
            }
            .padding(.horizontal, PulseSpacing.sm).padding(.vertical, PulseSpacing.xs)
        }
    }
}

// MARK: - 侧边栏按钮 — Liquid Glass 选中效果
struct SidebarButtonView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    let route: AppRoute
    var glassNamespace: Namespace.ID
    var shortcutIndex: Int? = nil

    private var isSelected: Bool { appState.selectedRoute == route }

    var body: some View {
        Button {
            withAnimation(PulseAnimation.springDefault) {
                appState.selectedRoute = route
            }
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                // accent 指示条
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? PulseColors.accent : Color.clear)
                    .frame(width: 3, height: 16)
                    .shadow(color: isSelected ? PulseColors.accent.opacity(0.5) : .clear, radius: 4)

                Image(systemName: route.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)

                if !appState.sidebarCollapsed {
                    Text(route.label)
                        .font(isSelected ? PulseFonts.bodyMedium : PulseFonts.body)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    Spacer()
                    if route == .dashboard && appState.unreadNotifications > 0 {
                        BadgeView(text: "\(appState.unreadNotifications)", color: PulseColors.danger, size: .small)
                    }
                    if let idx = shortcutIndex, idx < 9 {
                        Text("\u{2318}\(idx + 1)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, 7).padding(.horizontal, PulseSpacing.xs)
            .frame(maxWidth: .infinity)
            // 参考主题切换按钮：glassEffect 直接作用于内容，仅选中态
            .modifier(ConditionalGlassModifier(isActive: isSelected, cornerRadius: PulseRadii.md))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            .overlay {
                if isSelected {
                    // accent 描边在玻璃之上
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .stroke(LinearGradient(
                            colors: [PulseColors.accent.opacity(0.2), PulseColors.accent.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 0.5)
                        .glassEffectID("sidebar-selection", in: glassNamespace)
                }
            }
            .background {
                if isHovering && !isSelected {
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(colors.surface.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
        }
        .buttonStyle(.plain)
        .modifier(KeyboardShortcutModifier(index: shortcutIndex))
        .help(appState.sidebarCollapsed ? route.label : "")
    }

    private var iconColor: Color {
        if isSelected { return PulseColors.accent }
        if isHovering { return colors.textPrimary }
        return colors.textSecondary
    }

    private var textColor: Color {
        if isSelected { return colors.textPrimary }
        if isHovering { return colors.textPrimary }
        return colors.textSecondary
    }
}

// MARK: - 键盘快捷键修饰器 — Cmd+1~9 页面切换
private struct KeyboardShortcutModifier: ViewModifier {
    let index: Int?

    func body(content: Content) -> some View {
        if let idx = index, idx >= 0, idx < 9 {
            content.keyboardShortcut(
                KeyEquivalent(Character("\(idx + 1)")),
                modifiers: .command
            )
        } else {
            content
        }
    }
}
