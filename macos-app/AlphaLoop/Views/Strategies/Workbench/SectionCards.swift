// SectionCards.swift — 6 张控制台 Section Card
// 纯 AlphaLoop tokens：PulseColors / PulseFonts / PulseSpacing / PulseRadii.

import SwiftUI

// MARK: - Shell

struct SectionCardShell<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    let title: String
    let accent: Color
    let chips: [ReasonChip]
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                if !chips.isEmpty {
                    ReasonChipCluster(chips: chips, compact: false)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .overlay(
                Rectangle().fill(colors.border).frame(height: 1),
                alignment: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.cardBackground)
        .overlay(
            Rectangle().fill(accent.opacity(0.7)).frame(height: 2),
            alignment: .top
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
    }
}

// MARK: - KV row helper

private struct KVRow: View {
    @Environment(PulseColors.self) private var colors
    let k: String
    let v: String
    var color: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k.uppercased())
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text(v)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? colors.textPrimary)
        }
    }
}

// MARK: - Runtime card

struct RuntimeCard: View {
    @Environment(PulseColors.self) private var colors
    let run: StrategyRunV2?

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardRuntime,
            accent: PulseColors.accent,
            chips: chips
        ) {
            if let r = run {
                KVRow(k: L10n.Workbench.runtimeMode, v: r.mode.uppercased())
                KVRow(k: L10n.Workbench.runtimeStartedAt, v: shortDate(r.startedAt))
                KVRow(k: "status", v: r.status.uppercased(), color: statusColor(r.status))
                if let summary = r.resultSummary?.value as? [String: Any] {
                    if let trades = summary["total_trades"] as? Int {
                        KVRow(k: "trades", v: "\(trades)")
                    }
                    if let pnl = summary["total_pnl"] as? Double {
                        KVRow(k: "pnl",
                              v: String(format: "%+.2f", pnl),
                              color: pnl >= 0 ? PulseColors.accent : PulseColors.danger)
                    }
                }
                heartbeat
            } else {
                emptyState
            }
        }
    }

    private var chips: [ReasonChip] {
        guard let r = run else { return [] }
        switch r.status {
        case "running": return [.init(code: "ft_heartbeat", severity: .info)]
        case "error":   return [.init(code: "runner_error", severity: .block)]
        default:        return []
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "running": return PulseColors.accent
        case "error":   return PulseColors.danger
        case "stopped": return colors.textSecondary
        default:        return PulseColors.warning
        }
    }

    private var heartbeat: some View {
        HStack(spacing: 8) {
            HeartbeatDot()
            Text(L10n.Workbench.runtimeHeartbeat.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text("1.2s")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var emptyState: some View {
        Text(L10n.Workbench.runtimeNoActive)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(colors.textMuted)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
    }

    private func shortDate(_ s: String?) -> String {
        guard let s = s, let t = s.split(separator: "T").first else { return "—" }
        return String(t)
    }
}

private struct HeartbeatDot: View {
    @State private var anim = false
    var body: some View {
        Circle()
            .fill(PulseColors.accent)
            .frame(width: 6, height: 6)
            .shadow(color: PulseColors.accent.opacity(anim ? 0.4 : 0.9), radius: 6)
            .opacity(anim ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    anim = true
                }
            }
    }
}

// MARK: - Versions card

struct VersionsCard: View {
    @Environment(PulseColors.self) private var colors
    let versions: [StrategyVersionV2]
    let onEdit: () -> Void

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardVersions,
            accent: PulseColors.accent,
            chips: chips
        ) {
            if versions.isEmpty {
                Text(L10n.Workbench.versionsEmpty)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                editButton
            } else {
                ForEach(versions.prefix(4)) { v in
                    versionRow(v, isCurrent: v.id == versions.first?.id)
                }
                if versions.count > 4 {
                    Text(String(format: L10n.Workbench.versionsCount, versions.count))
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(colors.textMuted)
                }
                editButton
                    .padding(.top, 4)
            }
        }
    }

    private var chips: [ReasonChip] {
        guard let cur = versions.first else { return [] }
        return [.init(code: "dsl_v\(cur.dslVersion)", severity: .info)]
    }

    private func versionRow(_ v: StrategyVersionV2, isCurrent: Bool) -> some View {
        let badgeFg: Color = {
            switch v.status {
            case "active", "published", "live": return PulseColors.accent
            case "paper":   return PulseColors.warning
            case "draft":   return colors.textSecondary
            default:        return PulseColors.info
            }
        }()
        let badgeBg: Color = badgeFg.opacity(0.16)
        return HStack(spacing: 10) {
            Text("v\(v.versionNo)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(PulseColors.accent)
                .frame(minWidth: 28, alignment: .leading)
            Text(String(v.dslHash.prefix(8)))
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(colors.textMuted)
            Spacer()
            Text(v.status.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(badgeFg)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeBg)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text("EDIT")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(PulseColors.accent.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isCurrent ? PulseColors.accent.opacity(0.06) : colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrent ? PulseColors.accent.opacity(0.65) : colors.border, lineWidth: isCurrent ? 1 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 6) {
                Image(systemName: "paintbrush.pointed.fill").font(.system(size: 10))
                Text(L10n.Workbench.versionsEdit.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk card

struct RiskCard: View {
    @Environment(PulseColors.self) private var colors
    let risk: RiskOverviewBFFResponse?

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardRisk,
            accent: PulseColors.warning,
            chips: chipsFromRisk
        ) {
            if let r = risk, !r.guards.isEmpty {
                ForEach(r.guards.prefix(4)) { g in
                    gaugeRow(g)
                }
            } else {
                Text(L10n.Workbench.riskEmpty)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            }
        }
    }

    private var chipsFromRisk: [ReasonChip] {
        guard let codes = risk?.reasonCodes, !codes.isEmpty else { return [] }
        return codes.prefix(2).map { code in
            ReasonChip(
                code: code.lowercased(),
                severity: risk?.state == "block" ? .block : (risk?.state == "warn" ? .warn : .info)
            )
        }
    }

    private func gaugeRow(_ g: RiskGuardResponse) -> some View {
        let pct = max(0, min(1, 1.0 - g.remainingPct))
        let healthy = g.status == "healthy"
        let warnThreshold = 0.7
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(g.label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(healthy ? PulseColors.accent : PulseColors.warning)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.surface).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [PulseColors.accent, PulseColors.warning],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * pct, height: 6)
                    if pct >= warnThreshold {
                        Rectangle()
                            .fill(PulseColors.danger)
                            .frame(width: 2, height: 10)
                            .offset(x: geo.size.width * pct - 1, y: -2)
                            .shadow(color: PulseColors.danger.opacity(0.7), radius: 4)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text("USED")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text(String(format: "REMAIN %.0f%%", g.remainingPct * 100))
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }
}

// MARK: - Backtests card

struct BacktestsCard: View {
    @Environment(PulseColors.self) private var colors
    let backtests: [Backtest]
    let onStart: () -> Void

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardBacktests,
            accent: PulseColors.info,
            chips: []
        ) {
            if backtests.isEmpty {
                Text(L10n.Workbench.backtestEmpty)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StartButton(label: L10n.Workbench.backtestStart, color: PulseColors.info, action: onStart)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(backtests.prefix(4).enumerated()), id: \.offset) { idx, bt in
                        btRow(bt, isLast: idx == min(backtests.count, 4) - 1)
                    }
                }
            }
        }
    }

    private func btRow(_ bt: Backtest, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            Text(String(bt.createdAt.prefix(10)))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(colors.textMuted)
                .frame(width: 76, alignment: .leading)
            Text("WR \(String(format: "%.0f%%", bt.winRate * 100)) · DD \(String(format: "%.1f%%", bt.maxDrawdown * 100))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(colors.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(String(format: "%+.2f%%", bt.totalReturn * 100))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(bt.totalReturn >= 0 ? PulseColors.accent : PulseColors.danger)
        }
        .padding(.vertical, 6)
        .overlay(
            Rectangle().fill(isLast ? .clear : colors.border).frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Dryrun card

struct DryrunCard: View {
    @Environment(PulseColors.self) private var colors
    let run: StrategyRunV2?
    let onStart: () -> Void

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardDryrun,
            accent: PulseColors.warning,
            chips: chips
        ) {
            if let r = run, r.mode == "dryrun" || r.mode == "paper" {
                if let summary = r.resultSummary?.value as? [String: Any] {
                    HStack(spacing: 12) {
                        metric(L10n.Workbench.dryrunOrders,
                               "\((summary["total_trades"] as? Int) ?? 0)")
                        metric(L10n.Workbench.dryrunPnl,
                               String(format: "%+.2f", (summary["total_pnl"] as? Double) ?? 0),
                               color: ((summary["total_pnl"] as? Double) ?? 0) >= 0 ? PulseColors.accent : PulseColors.danger)
                    }
                }
                statusLine(r)
            } else {
                Text(L10n.Workbench.dryrunEmpty)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StartButton(label: L10n.Workbench.dryrunStart, color: PulseColors.warning, action: onStart)
            }
        }
    }

    private var chips: [ReasonChip] {
        guard let r = run, r.mode == "dryrun" || r.mode == "paper" else { return [] }
        return [.init(code: "paper_on", severity: .info)]
    }

    private func metric(_ label: String, _ value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLine(_ r: StrategyRunV2) -> some View {
        HStack(spacing: 6) {
            Circle().fill(PulseColors.warning).frame(width: 5, height: 5)
                .shadow(color: PulseColors.warning.opacity(0.6), radius: 3)
            Text(r.status.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(colors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Signal card

struct SignalCard: View {
    @Environment(PulseColors.self) private var colors
    let signals: [AgentSignal]
    let onAttach: () -> Void

    var body: some View {
        SectionCardShell(
            title: L10n.Workbench.cardSignals,
            accent: PulseColors.info,
            chips: []
        ) {
            if signals.isEmpty {
                Text(L10n.Workbench.signalsEmpty)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StartButton(label: L10n.Workbench.signalsAttach, color: PulseColors.info, action: onAttach)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(signals.prefix(4).enumerated()), id: \.offset) { idx, s in
                        signalRow(s, isLast: idx == min(signals.count, 4) - 1)
                    }
                }
            }
        }
    }

    private func signalRow(_ s: AgentSignal, isLast: Bool) -> some View {
        let dotColor: Color = {
            switch s.source.lowercased() {
            case "ai", "agent":     return PulseColors.warning
            case "struct", "structure": return PulseColors.accent
            default:                return PulseColors.info
            }
        }()
        return HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(0.7), radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.textPrimary)
                    Text((s.direction ?? "").uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(s.direction == "long" ? PulseColors.accent : PulseColors.danger)
                }
                Text(s.source.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            Text(String(format: "%.0f", (s.confidence ?? 0) * 100))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(PulseColors.accent)
        }
        .padding(.vertical, 7)
        .overlay(
            Rectangle().fill(isLast ? .clear : colors.border).frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Shared start button

private struct StartButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill").font(.system(size: 9))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.4), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
