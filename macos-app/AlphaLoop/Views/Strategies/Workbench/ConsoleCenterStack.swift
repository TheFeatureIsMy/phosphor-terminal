// ConsoleCenterStack.swift — Lifecycle rail / KPI strip / Reason chip cluster
// Pure AlphaLoop tokens: PulseColors / PulseFonts / PulseSpacing / PulseRadii.
// (Dropped: ConsoleHeaderRow + purple StateBanner — the new WorkspaceHeader replaces them.)

import SwiftUI

// MARK: - Reason chip / cluster

enum ReasonSeverity: String, Codable, Hashable {
    case info, warn, block, ok

    func fg(_ colors: PulseColors) -> Color {
        switch self {
        case .info:  return PulseColors.info
        case .warn:  return PulseColors.warning
        case .block: return PulseColors.danger
        case .ok:    return PulseColors.accent
        }
    }
    func bg(_ colors: PulseColors) -> Color { fg(colors).opacity(0.16) }

    var label: String {
        switch self {
        case .info:  return L10n.Workbench.severityInfo
        case .warn:  return L10n.Workbench.severityWarn
        case .block: return L10n.Workbench.severityBlock
        case .ok:    return L10n.Workbench.severityInfo
        }
    }
}

struct ReasonChip: Hashable {
    let code: String
    let severity: ReasonSeverity
}

struct ReasonChipCluster: View {
    @Environment(PulseColors.self) private var colors
    let chips: [ReasonChip]
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(chips, id: \.self) { c in
                Text(c.code.lowercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(c.severity.fg(colors))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(c.severity.bg(colors))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}

// MARK: - Lifecycle rail (7 checkpoint rings)

struct LifecycleRailV2: View {
    @Environment(PulseColors.self) private var colors
    let currentStatus: String

    @State private var pulse: Bool = false

    var body: some View {
        let current = LifecycleStage.from(status: currentStatus)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .stroke(colors.border, lineWidth: 1)
                )

            Text(L10n.Workbench.subtitle.uppercased())
                .font(PulseFonts.micro)
                .tracking(2.0)
                .foregroundStyle(colors.textMuted)
                .padding(.top, 8)
                .padding(.leading, 14)

            checkpointRow(current: current)
                .padding(.top, 30)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private func checkpointRow(current: LifecycleStage) -> some View {
        let stages = LifecycleStage.allCases
        let total = stages.count
        let pastFraction = Double(max(0, current.rawValue)) / Double(total - 1)
        let currentFraction = pastFraction + (1.0 / Double(total - 1)) * 0.4

        return ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(colors.border)
                        .frame(width: w, height: 1)
                    Rectangle()
                        .fill(PulseColors.accent.opacity(0.55))
                        .frame(width: w * CGFloat(min(currentFraction, 1.0)), height: 1)
                    Rectangle()
                        .fill(PulseColors.accent)
                        .frame(width: w * CGFloat(pastFraction), height: 1)
                }
                .offset(y: 17)
            }
            .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { idx, stage in
                    checkpointNode(idx: idx, stage: stage, current: current)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func checkpointNode(idx: Int, stage: LifecycleStage, current: LifecycleStage) -> some View {
        let isCurrent = stage == current
        let isPast = stage.rawValue < current.rawValue

        let accent = PulseColors.accent
        let ringStroke: Color = isCurrent ? accent : (isPast ? accent.opacity(0.7) : colors.border)
        let ringFill: Color   = isCurrent ? accent.opacity(0.18) : (isPast ? accent.opacity(0.10) : colors.surface)
        let numberColor: Color = isCurrent ? accent : (isPast ? accent.opacity(0.8) : colors.textMuted)
        let labelColor: Color  = isCurrent ? colors.textPrimary : (isPast ? colors.textSecondary : colors.textMuted)

        return VStack(spacing: 6) {
            ZStack {
                if isCurrent {
                    Circle()
                        .stroke(accent.opacity(pulse ? 0.08 : 0.22), lineWidth: pulse ? 8 : 4)
                        .frame(width: pulse ? 50 : 42, height: pulse ? 50 : 42)
                        .blur(radius: 1)
                }
                Circle()
                    .fill(ringFill)
                    .overlay(Circle().stroke(ringStroke, lineWidth: 2))
                    .frame(width: 34, height: 34)
                if isPast {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                } else {
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(numberColor)
                }
            }
            .frame(height: 34)

            Text(stage.label.uppercased())
                .font(PulseFonts.micro)
                .tracking(0.8)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - KPI strip

struct ConsoleKpiStrip: View {
    @Environment(PulseColors.self) private var colors
    let snapshot: WorkspaceSnapshot?

    var body: some View {
        HStack(spacing: 10) {
            kpi(L10n.Workbench.kpiEquity, value: equityText, stripe: PulseColors.accent,
                sub: "USDT", valColor: colors.textPrimary)
            kpi(L10n.Workbench.kpiPnl, value: pnlText, stripe: pnlStripe,
                sub: "TOTAL", valColor: pnlColor)
            kpi(L10n.Workbench.kpiWinRate, value: winText, stripe: PulseColors.accent,
                sub: nil, valColor: colors.textPrimary)
            kpi(L10n.Workbench.kpiDrawdown, value: ddText, stripe: ddStripe,
                sub: "MAX", valColor: ddColor)
            kpi(L10n.Workbench.kpiSharpe, value: sharpeText, stripe: PulseColors.accent,
                sub: "RATIO", valColor: colors.textPrimary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func kpi(_ label: String, value: String, stripe: Color, sub: String?, valColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(PulseFonts.micro)
                .tracking(1.4)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(valColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let s = sub {
                Text(s.uppercased())
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.cardBackground)
        .overlay(
            Rectangle()
                .fill(stripe.opacity(0.65))
                .frame(height: 2),
            alignment: .top
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
    }

    // MARK: - Computed

    private var equityText: String {
        guard let v = snapshot?.equity, v > 0 else { return "—" }
        return formatNumeric(v, fractionDigits: 0)
    }
    private var pnlText: String {
        guard let v = snapshot?.pnlPct else { return "—" }
        return String(format: "%+.2f%%", v * 100)
    }
    private var pnlColor: Color {
        guard let v = snapshot?.pnlPct else { return colors.textMuted }
        return v >= 0 ? PulseColors.accent : PulseColors.danger
    }
    private var pnlStripe: Color {
        guard let v = snapshot?.pnlPct else { return PulseColors.accent }
        return v >= 0 ? PulseColors.accent : PulseColors.danger
    }
    private var winText: String {
        guard let v = snapshot?.winRate else { return "—" }
        return String(format: "%.0f%%", v * 100)
    }
    private var ddText: String {
        guard let v = snapshot?.maxDrawdown else { return "—" }
        return String(format: "%.1f%%", v * 100)
    }
    private var ddColor: Color {
        guard let v = snapshot?.maxDrawdown else { return colors.textMuted }
        if v >= 0.15 { return PulseColors.danger }
        if v >= 0.08 { return PulseColors.warning }
        return colors.textPrimary
    }
    private var ddStripe: Color {
        guard let v = snapshot?.maxDrawdown else { return PulseColors.accent }
        if v >= 0.15 { return PulseColors.danger }
        if v >= 0.08 { return PulseColors.warning }
        return PulseColors.accent
    }
    private var sharpeText: String {
        guard let v = snapshot?.sharpe, v != 0 else { return "—" }
        return String(format: "%.2f", v)
    }

    private func formatNumeric(_ v: Double, fractionDigits: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = fractionDigits
        fmt.maximumFractionDigits = fractionDigits
        return fmt.string(from: NSNumber(value: v)) ?? String(format: "%.\(fractionDigits)f", v)
    }
}
