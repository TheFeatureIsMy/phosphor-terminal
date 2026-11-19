// PulseComponents.swift — 补充自定义 UI 组件（扩展 FormControls.swift）
// PulseDropdown / PulseNumberField / PulseFilterChip / PulseModal / PulseActionButton

import SwiftUI

// MARK: - PulseNumberField

struct PulseNumberField: View {
    let label: String
    @Binding var value: Double
    var suffix: String = ""
    @Environment(PulseColors.self) private var colors
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            TextField("", value: $value, format: .number)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .frame(width: 60)
            if !suffix.isEmpty {
                Text(suffix)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, PulseSpacing.xs)
        .background(colors.surface)
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(isFocused ? PulseColors.accent.opacity(0.5) : colors.border, lineWidth: isFocused ? 1.5 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }
}

// MARK: - PulseDropdown

struct PulseDropdown<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [(value: T, label: String)]
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    HStack {
                        Text(option.label)
                        if selection == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                Text(currentLabel)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(colors.surface)
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(isHovering ? colors.borderHover : colors.border, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .menuStyle(.borderlessButton)
        #if os(macOS)
        .onHover { h in withAnimation(PulseAnimation.easeOutFast) { isHovering = h } }
        #endif
    }

    private var currentLabel: String {
        options.first(where: { $0.value == selection })?.label ?? label
    }
}

// MARK: - PulseFilterChip

struct PulseFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(isSelected ? colors.textPrimary : colors.textMuted)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xxs)
                .background(isSelected ? PulseColors.accent.opacity(0.15) : colors.surface.opacity(isHovering ? 0.6 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(isSelected ? PulseColors.accent.opacity(0.4) : colors.border.opacity(0.3), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { h in withAnimation(PulseAnimation.easeOutFast) { isHovering = h } }
        #endif
    }
}

// MARK: - PulseActionButton

struct PulseActionButton: View {
    let label: String
    var icon: String? = nil
    var style: Variant = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    enum Variant { case primary, secondary, danger }

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseSpacing.xs) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(fgColor)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 11)) }
                    Text(label).font(PulseFonts.monoLabel)
                }
            }
            .foregroundStyle(fgColor)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(bgColor)
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(borderColor, lineWidth: borderWidth))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(color: style == .primary ? PulseColors.accent.opacity(isHovering ? 0.35 : 0.18) : .clear,
                    radius: isHovering ? 14 : 8, y: 0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        #if os(macOS)
        .onHover { h in withAnimation(PulseAnimation.easeOutFast) { isHovering = h } }
        #endif
    }

    private var bgColor: Color {
        switch style {
        case .primary: return PulseColors.accent
        case .secondary: return colors.surface.opacity(isHovering ? 0.8 : 0.6)
        case .danger: return PulseColors.danger.opacity(isHovering ? 0.2 : 0.12)
        }
    }
    private var fgColor: Color {
        switch style { case .primary: return PulseColors.onAccent; case .secondary: return colors.textPrimary; case .danger: return PulseColors.danger }
    }
    private var borderColor: Color {
        switch style { case .primary: return .clear; case .secondary: return colors.border; case .danger: return PulseColors.danger.opacity(0.3) }
    }
    private var borderWidth: CGFloat {
        style == .primary ? 0 : 0.5
    }
}

// MARK: - PulseModal

struct PulseModalModifier<ModalContent: View>: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @Binding var isPresented: Bool
    let title: String
    @ViewBuilder let modalContent: () -> ModalContent

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(PulseAnimation.easeOutMedium) { isPresented = false } }

                    VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                        HStack {
                            Text(title)
                                .font(PulseFonts.displaySubheading)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                            Button {
                                withAnimation(PulseAnimation.easeOutMedium) { isPresented = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(colors.textMuted)
                                    .padding(6)
                                    .background(colors.surface)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        modalContent()
                    }
                    .padding(PulseSpacing.xl)
                    .frame(maxWidth: 500)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .fill(colors.background)
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(PulseAnimation.springDefault, value: isPresented)
            }
        }
    }
}

extension View {
    func pulseModal<Content: View>(isPresented: Binding<Bool>, title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(PulseModalModifier(isPresented: isPresented, title: title, modalContent: content))
    }
}
