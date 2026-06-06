// SettingsTabBar.swift — 设置页顶部 Tab 切换栏
// 水平滚动 Tab 条，带 matchedGeometryEffect 滑动指示器

import SwiftUI

struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsTab
    @Environment(PulseColors.self) private var colors
    @Namespace private var tabNamespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.xs) {
                ForEach(SettingsTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.vertical, PulseSpacing.xs)
        }
        .background(colors.surface.opacity(0.3))
    }

    private func tabButton(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(PulseAnimation.easeOutMedium) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                    Text(tab.title)
                        .font(isSelected ? PulseFonts.bodyMedium : PulseFonts.body)
                }
                .foregroundStyle(isSelected ? PulseColors.accent : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.top, PulseSpacing.xs)

                // 底部指示条
                ZStack {
                    // 占位透明条（保持布局稳定）
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.clear)
                        .frame(height: 2)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(PulseColors.accent)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "tab-indicator", in: tabNamespace)
                            .shadow(color: PulseColors.accent.opacity(0.4), radius: 3, y: 1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
