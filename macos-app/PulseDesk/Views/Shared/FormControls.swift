// FormControls.swift — 表单控件样式
// macOS 26 Liquid Glass — .glassEffect() + 霓虹聚焦 + 悬停态

import SwiftUI

// MARK: - 暗黑文本框修饰器 — Liquid Glass
struct DarkTextFieldModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.body)
            .foregroundStyle(colors.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(
                        isFocused ? PulseColors.accent.opacity(0.5) :
                        isHovering ? colors.borderHover : colors.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .shadow(color: isFocused ? PulseColors.accent.opacity(0.1) : .clear, radius: 8)
            .focused($isFocused)
            .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
            .animation(PulseAnimation.easeOutFast, value: isFocused)
    }
}

// MARK: - 暗黑下拉选择器修饰器 — Liquid Glass
struct DarkPickerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.body)
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xxs)
            .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(isHovering ? colors.borderHover : colors.border, lineWidth: 1)
            )
            .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
    }
}

// MARK: - 暗黑分段选择器修饰器 — Liquid Glass
struct DarkSegmentedPickerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.captionMedium)
            .padding(2)
            .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(colors.border, lineWidth: 1)
            )
    }
}

// MARK: - 暗黑按钮修饰器 — Liquid Glass
struct DarkButtonModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.captionMedium)
            .foregroundStyle(isHovering ? colors.textPrimary : colors.textSecondary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(isHovering ? colors.borderHover : colors.border, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func darkTextField() -> some View {
        modifier(DarkTextFieldModifier())
    }

    func darkPicker() -> some View {
        modifier(DarkPickerModifier())
    }

    func darkSegmentedPicker() -> some View {
        modifier(DarkSegmentedPickerModifier())
    }

    func darkButton() -> some View {
        modifier(DarkButtonModifier())
    }
}

/// PulseDesk 风格的文本框 — Liquid Glass + 霓虹聚焦环
struct PulseTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    @Environment(PulseColors.self) private var colors
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            Text(label)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textSecondary)
            TextField(placeholder, text: $text)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xs)
                .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(
                            isFocused ? PulseColors.accent.opacity(0.5) :
                            isHovering ? colors.borderHover : colors.border,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .shadow(color: isFocused ? PulseColors.accent.opacity(0.1) : .clear, radius: 8)
                .focused($isFocused)
                .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
                .animation(PulseAnimation.easeOutFast, value: isFocused)
        }
    }
}

/// PulseDesk 风格的安全输入框 — Liquid Glass + 霓虹聚焦环
struct PulseSecureField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    @Environment(PulseColors.self) private var colors
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            Text(label)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textSecondary)
            SecureField(placeholder, text: $text)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xs)
                .glassEffect(.regular, in: .rect(cornerRadius: PulseRadii.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(
                            isFocused ? PulseColors.accent.opacity(0.5) :
                            isHovering ? colors.borderHover : colors.border,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .shadow(color: isFocused ? PulseColors.accent.opacity(0.1) : .clear, radius: 8)
                .focused($isFocused)
                .onHover { hovering in withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering } }
                .animation(PulseAnimation.easeOutFast, value: isFocused)
        }
    }
}

/// PulseDesk 风格的开关 — macOS 26 自动 Liquid Glass
struct PulseToggle: View {
    let label: String
    @Binding var isOn: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack {
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(PulseColors.accent)
        }
    }
}

/// PulseDesk 风格的表单行 — 标签 + 控件
struct PulseFormRow<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    var labelWidth: CGFloat = 120
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            Text(label)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: 360, alignment: .leading)
            Spacer()
        }
    }
}
