// CanvasTopActionBar.swift — 策略画布顶部操作栏
// Phase 6: 提取为独立组件，整合策略信息 + 版本 + 操作按钮

import SwiftUI

struct CanvasTopActionBar: View {
    @Environment(PulseColors.self) private var colors

    let strategyName: String?
    let strategyStatus: String?
    let strategyVersion: Int?
    let hasDSL: Bool
    let isSaving: Bool
    let saveSuccess: Bool
    let validationValid: Bool?
    let validationErrors: Int
    let errorMessage: String?

    let onCreate: () -> Void
    let onTemplate: () -> Void
    let onValidate: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // Left: Strategy info
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "paintbrush.pointed")
                    .font(.system(size: 11))
                    .foregroundStyle(PulseColors.accent)

                if let name = strategyName {
                    HStack(spacing: PulseSpacing.xs) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)

                        if let version = strategyVersion {
                            Text("v\(version)")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(colors.surface))
                        }
                    }
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, PulseSpacing.xxs)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                } else {
                    Text("选择策略开始编辑")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }

            Spacer()

            // Right: Status + Actions
            HStack(spacing: PulseSpacing.sm) {
                // Save status indicator
                if isSaving {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        Text("保存中...")
                            .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                } else if saveSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11)).foregroundStyle(KryptonColor.green)
                        Text("已保存")
                            .font(PulseFonts.caption).foregroundStyle(KryptonColor.green)
                    }
                }

                // Validation status
                if let valid = validationValid {
                    HStack(spacing: 4) {
                        Circle().fill(valid ? KryptonColor.green : KryptonColor.red).frame(width: 5, height: 5)
                        Text(valid ? "验证通过" : "\(validationErrors) 错误")
                            .font(PulseFonts.caption)
                            .foregroundStyle(valid ? KryptonColor.green : KryptonColor.red)
                    }
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(PulseFonts.micro).foregroundStyle(KryptonColor.red)
                        .lineLimit(1)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(KryptonColor.redSoft))
                }

                // Action buttons
                HStack(spacing: PulseSpacing.xxs) {
                    KryptonActionChip(label: "新建", icon: "plus", action: onCreate)
                    KryptonActionChip(label: "模板", icon: "square.grid.2x2", action: onTemplate)
                    KryptonActionChip(label: "验证", icon: "checkmark.shield", action: onValidate, disabled: !hasDSL)
                    KryptonActionChip(label: "保存", icon: "square.and.arrow.down", action: onSave, primary: true, disabled: !hasDSL)
                }
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(colors.surfaceElevated.opacity(0.5))
    }

    private var statusColor: Color {
        switch strategyStatus {
        case "active": return KryptonColor.green
        case "draft": return KryptonColor.amber
        case "paused": return Color.orange
        default: return colors.textMuted
        }
    }
}

// MARK: - Action Chip Button

struct KryptonActionChip: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    let icon: String
    let action: () -> Void
    var primary: Bool = false
    var disabled: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .medium))
                Text(label).font(PulseFonts.caption).fontWeight(primary ? .bold : .regular)
            }
            .foregroundStyle(primary ? KryptonColor.background : (disabled ? colors.textMuted : colors.textSecondary))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(primary
                        ? (disabled ? colors.surfaceHover : (isHovered ? KryptonColor.amberActive : KryptonColor.amber))
                        : (isHovered ? colors.surfaceHover : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .stroke(primary ? .clear : colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}
