// UnifiedToolbar.swift — 一体化工具状态栏
import SwiftUI

struct UnifiedToolbar: View {
    @Environment(PulseColors.self) private var colors
    let providerStatus: String
    let gpuStatus: String
    let todayCost: Double
    let pendingJobs: Int

    var body: some View {
        HStack(spacing: 0) {
            toolbarItem(icon: "cloud.fill", label: "AI PROVIDER", value: providerStatusLabel, color: providerStatusColor)
            toolbarDivider
            toolbarItem(icon: "cpu.fill", label: "LOCAL GPU", value: gpuStatusLabel, color: gpuStatusColor)
            toolbarDivider
            toolbarItem(icon: "dollarsign.circle.fill", label: "AI COST TODAY", value: String(format: "$%.2f", todayCost), color: colors.textPrimary)
            toolbarDivider
            toolbarItem(icon: "gearshape.2.fill", label: "PENDING JOBS", value: "\(pendingJobs)", color: pendingJobs > 0 ? KryptonColor.amber : KryptonColor.green)
            toolbarDivider
            HStack(spacing: PulseSpacing.xxs) {
                StatusDot(status: .online)
                Text("FREQTRADE")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textPrimary)
                Text("15ms")
                    .font(PulseFonts.micro)
                    .foregroundStyle(KryptonColor.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().stroke(KryptonColor.green.opacity(0.3), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, PulseSpacing.sm)
        .padding(.horizontal, PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(KryptonColor.card.opacity(0.7))
                .background(RoundedRectangle(cornerRadius: PulseRadii.md).fill(.ultraThinMaterial))
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
    }

    private func toolbarItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .tracking(0.5)
                Text(value)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 24)
            .padding(.horizontal, PulseSpacing.xs)
    }

    private var providerStatusLabel: String {
        switch providerStatus {
        case "degraded": return "DEGRADED"
        case "cloud_unavailable": return "UNAVAILABLE"
        default: return "NORMAL"
        }
    }

    private var providerStatusColor: Color {
        switch providerStatus {
        case "degraded": return KryptonColor.amber
        case "cloud_unavailable": return KryptonColor.red
        default: return KryptonColor.green
        }
    }

    private var gpuStatusLabel: String {
        switch gpuStatus {
        case "active": return "RUNNING"
        case "unavailable": return "UNAVAILABLE"
        default: return "IDLE"
        }
    }

    private var gpuStatusColor: Color {
        switch gpuStatus {
        case "active": return KryptonColor.green
        case "unavailable": return KryptonColor.red
        default: return colors.textMuted
        }
    }
}
