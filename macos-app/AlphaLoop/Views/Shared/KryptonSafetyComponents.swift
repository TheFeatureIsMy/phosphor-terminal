// KryptonSafetyComponents.swift — Phase 8 安全交互组件
// ConfirmDialog, LiveModeBanner, EmergencyPause, RiskAlert

import SwiftUI

// MARK: - Confirm Dialog

struct KryptonConfirmDialog: View {
    @Environment(PulseColors.self) private var colors
    @State private var isPressed = false

    let title: String
    let message: String
    let confirmLabel: String
    let confirmStyle: ConfirmStyle
    let onConfirm: () -> Void
    let onCancel: () -> Void

    enum ConfirmStyle {
        case danger     // Red — delete, stop, emergency
        case warning    // Amber — pause, disable
        case normal     // Green/Amber — publish, deploy

        var color: Color {
            switch self {
            case .danger: return KryptonColor.red
            case .warning: return KryptonColor.amber
            case .normal: return KryptonColor.amber
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: PulseSpacing.md) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(confirmStyle.color)
                    .shadow(color: confirmStyle.color.opacity(0.3), radius: 8)

                // Text
                VStack(spacing: PulseSpacing.xxs) {
                    Text(title)
                        .font(PulseFonts.displaySubheading)
                        .foregroundStyle(colors.textPrimary)
                    Text(message)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                HStack(spacing: PulseSpacing.sm) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textSecondary)
                            .frame(width: 100, height: 32)
                            .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surface))
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(PulseFonts.captionMedium)
                            .fontWeight(.bold)
                            .foregroundStyle(confirmStyle == .danger ? Color.white : KryptonColor.background)
                            .frame(width: 120, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.button)
                                    .fill(confirmStyle.color)
                            )
                            .shadow(color: confirmStyle.color.opacity(0.25), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(PulseSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.lg)
                    .fill(colors.cardBackground)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.lg).fill(.ultraThinMaterial))
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.lg).stroke(colors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var iconName: String {
        switch confirmStyle {
        case .danger: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .normal: return "checkmark.shield.fill"
        }
    }
}

// MARK: - Live Mode Indicator

struct LiveModeIndicator: View {
    let isLive: Bool
    let emergencyLocked: Bool

    var body: some View {
        if emergencyLocked {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 9))
                Text("EMERGENCY LOCKED").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(KryptonColor.red)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(KryptonColor.red.opacity(0.12)))
            .overlay(Capsule().stroke(KryptonColor.red.opacity(0.3), lineWidth: 1))
        } else if isLive {
            HStack(spacing: 5) {
                Circle().fill(KryptonColor.green).frame(width: 5, height: 5)
                    .shadow(color: KryptonColor.green.opacity(0.5), radius: 3)
                Text("LIVE").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(KryptonColor.green)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(KryptonColor.green.opacity(0.08)))
            .overlay(Capsule().stroke(KryptonColor.green.opacity(0.2), lineWidth: 1))
        } else {
            HStack(spacing: 5) {
                Circle().fill(KryptonColor.amber).frame(width: 5, height: 5)
                Text("PAPER").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(KryptonColor.amber)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(KryptonColor.amber.opacity(0.08)))
            .overlay(Capsule().stroke(KryptonColor.amber.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Emergency Pause Button

struct EmergencyPauseButton: View {
    @Environment(PulseColors.self) private var colors
    @State private var showConfirm = false
    @State private var isHovered = false

    let isLive: Bool
    let onPause: () -> Void

    var body: some View {
        Button {
            if isLive { showConfirm = true }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 11))
                Text("暂停交易")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(isLive ? KryptonColor.red : colors.textMuted)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isLive ? KryptonColor.red.opacity(isHovered ? 0.2 : 0.08) : colors.surface)
            )
            .overlay(
                Capsule()
                    .stroke(isLive ? KryptonColor.red.opacity(0.35) : colors.border, lineWidth: 1)
            )
            .shadow(color: isLive ? KryptonColor.red.opacity(isHovered ? 0.3 : 0.1) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isLive)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showConfirm) {
            KryptonConfirmDialog(
                title: "暂停所有自动交易",
                message: "这将立即停止所有策略的自动执行。已提交的订单不受影响。暂停后需要人工恢复。",
                confirmLabel: "确认暂停",
                confirmStyle: .danger,
                onConfirm: {
                    onPause()
                    showConfirm = false
                },
                onCancel: { showConfirm = false }
            )
        }
    }
}

// MARK: - Risk Alert Banner (high-priority inline alert)

struct RiskAlertBanner: View {
    let alerts: [RiskAlert]

    struct RiskAlert: Identifiable {
        let id = UUID()
        let type: AlertType
        let message: String
        let time: Date

        enum AlertType {
            case stopLoss, circuitBreaker, emergency, riskWarning

            var color: Color {
                switch self {
                case .stopLoss: return KryptonColor.red
                case .circuitBreaker: return Color(hex: "#ff4500")
                case .emergency: return KryptonColor.red
                case .riskWarning: return KryptonColor.amber
                }
            }

            var icon: String {
                switch self {
                case .stopLoss: return "shield.slash.fill"
                case .circuitBreaker: return "bolt.circle.fill"
                case .emergency: return "exclamationmark.triangle.fill"
                case .riskWarning: return "exclamationmark.shield.fill"
                }
            }
        }
    }

    var body: some View {
        ForEach(alerts) { alert in
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: alert.type.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(alert.type.color)
                    .shadow(color: alert.type.color.opacity(0.4), radius: 4)

                Text(alert.message)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(.white)

                Spacer()

                Text(alert.time, style: .relative)
                    .font(PulseFonts.micro)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(alert.type.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(alert.type.color.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, PulseSpacing.md)
            .padding(.top, PulseSpacing.xxs)
        }
    }
}

// MARK: - View Modifier: Confirmation

extension View {
    func confirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String,
        confirmStyle: KryptonConfirmDialog.ConfirmStyle = .normal,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            KryptonConfirmDialog(
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                confirmStyle: confirmStyle,
                onConfirm: onConfirm,
                onCancel: { isPresented.wrappedValue = false }
            )
        }
    }
}
