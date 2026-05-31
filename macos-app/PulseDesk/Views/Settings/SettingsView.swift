// SettingsView.swift — 系统设置页面
// 左侧导航 + 右侧内容面板 — 风格与控制台侧边栏一致

import SwiftUI

struct SettingsView: View {
    @Environment(PulseColors.self) private var colors
    @State private var selectedSection = 0
    @Namespace private var glassNamespace

    private let sections = [
        ("gearshape", "交易所配置"),
        ("shield.checkered", "风控参数"),
        ("bell", "通知设置"),
        ("key", "API 密钥"),
        ("person", "个人资料"),
        ("exclamationmark.triangle", "危险操作"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航 — 与控制台侧边栏风格一致
            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.bottom, PulseSpacing.md)
                    .padding(.leading, 4)

                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    settingsNavRow(icon: section.0, title: section.1, index: index)
                }

                Spacer()
            }
            .frame(width: 180, alignment: .leading)
            .padding(.leading, 6)
            .padding(.vertical, PulseSpacing.md)

            Divider().foregroundStyle(colors.border)

            // 右侧内容
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch selectedSection {
                    case 0: ExchangeSettingsView()
                    case 1: RiskSettingsView()
                    case 2: NotificationSettingsView()
                    case 3: APISettingsView()
                    case 4: ProfileSettingsView()
                    case 5: DangerZoneView()
                    default: EmptyView()
                    }
                }
                .padding(PulseSpacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsNavRow(icon: String, title: String, index: Int) -> some View {
        SettingsNavRowView(icon: icon, title: title, index: index,
                           selectedSection: $selectedSection, glassNamespace: glassNamespace)
    }
}

// MARK: - 设置导航行 — 与 SidebarButtonView 风格一致
private struct SettingsNavRowView: View {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    let icon: String
    let title: String
    let index: Int
    @Binding var selectedSection: Int
    var glassNamespace: Namespace.ID

    private var isSelected: Bool { selectedSection == index }

    var body: some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedSection = index }
        } label: {
            HStack(spacing: 6) {
                // accent 指示条
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? PulseColors.accent : .clear)
                    .frame(width: 3, height: 16)
                    .shadow(color: isSelected ? PulseColors.accent.opacity(0.4) : .clear, radius: 3)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PulseColors.accent : isHovering ? colors.textPrimary : colors.textSecondary)
                    .frame(width: 16)

                Text(title)
                    .font(isSelected ? PulseFonts.bodyMedium : PulseFonts.body)
                    .foregroundStyle(isSelected ? colors.textPrimary : isHovering ? colors.textPrimary : colors.textSecondary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                        .glassEffectID("settings-selection", in: glassNamespace)
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
    }
}
