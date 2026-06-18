// AccountHeroCard.swift — Hero card: equity + KPIs + sparkline
// Left: large equity + 24h change + mode pill. Right: KPI columns
// (today PnL, week PnL, sharpe, max drawdown, win rate).
// Numbers are derived from the BFF `account` and the parallel `/api/dashboard/kpis`
// fetch. When neither source has data, the card renders the empty state.

import SwiftUI

struct AccountHeroCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let account: AccountOverviewResponse?
    let kpis: DashboardKPIsResponse?
    let mode: ModePill.Mode
    let dataSourceAvailable: Bool
    let equityCurve: [EquityPoint]

    @State private var displayEquity: Double = 0
    @State private var hasAnimated = false

    private var effectiveEquity: Double {
        if let account, account.equity > 0 { return account.equity }
        if let totalPnl = kpis?.totalPnl, totalPnl > 0 { return totalPnl }
        return 0
    }

    private var currency: String { account?.currency ?? "USDT" }

    private var todayPnlPct: Double {
        if let account, account.equity > 0 { return account.todayPnlPct }
        if let pnl = kpis?.pnlChangePct { return pnl / 100.0 }
        return 0
    }

    var body: some View {
        KryptonCard(emphasis: .bold) {
            HStack(spacing: 0) {
                leftPanel
                verticalDivider
                rightPanel
            }
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                TerminalLabel(text: L10n.Dashboard.accountOverview)
                ModePill(mode: mode, compact: true)
            }

            if !dataSourceAvailable {
                Text(L10n.Dashboard.dataSourceUnavailable)
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.warning)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(effectiveEquity > 0 ? String(format: "%.2f", displayEquity) : "—")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(colors.textPrimary)
                    .contentTransition(.numericText())

                Text(currency)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                withAnimation(.spring(response: 1.5, dampingFraction: 0.7)) {
                    displayEquity = effectiveEquity
                }
            }
            .onChange(of: effectiveEquity) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayEquity = newValue
                }
            }

            HStack(spacing: 6) {
                let isPositive = todayPnlPct >= 0
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isPositive ? PulseColors.accent : PulseColors.danger)

                Text(String(format: "%+.2f%%", todayPnlPct * 100))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(isPositive ? PulseColors.accent : PulseColors.danger)

                Text("24h")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill((isPositive ? PulseColors.accent : PulseColors.danger).opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke((isPositive ? PulseColors.accent : PulseColors.danger).opacity(0.20), lineWidth: 1)
                    )
            }

            // Sparkline
            if !equityCurve.isEmpty {
                EquityCurveChart(points: equityCurve)
                    .frame(height: 64)
                    .padding(.top, PulseSpacing.xs)
            }
        }
        .frame(width: 460, alignment: .leading)
        .padding(.trailing, PulseSpacing.lg)
        .id(settingsState.language)
    }

    // MARK: - Right Panel (KPIs)

    private var rightPanel: some View {
        HStack(spacing: 0) {
            metricColumn(
                label: L10n.Dashboard.todayPnl,
                value: formatPct(todayPnlPct),
                color: todayPnlPct >= 0 ? PulseColors.accent : PulseColors.danger,
                absolute: ""
            )
            thinDivider
            metricColumn(
                label: L10n.Dashboard.weekPnl,
                value: formatPct(account?.weekPnlPct ?? 0),
                color: (account?.weekPnlPct ?? 0) >= 0 ? PulseColors.accent : PulseColors.danger,
                absolute: ""
            )
            thinDivider
            metricColumn(
                label: L10n.Dashboard.totalPnl,
                value: formatMoney(kpis?.totalPnl ?? 0),
                color: (kpis?.totalPnl ?? 0) >= 0 ? PulseColors.accent : PulseColors.danger,
                absolute: ""
            )
            thinDivider
            metricColumn(
                label: L10n.Dashboard.winRate,
                value: formatPctRaw((kpis?.winRate ?? 0) / 100.0),
                color: PulseColors.cyan,
                absolute: ""
            )
            thinDivider
            metricColumn(
                label: L10n.Dashboard.sharpeRatio,
                value: formatNumber(kpis?.sharpeRatio ?? account?.sharpeRatio ?? 0),
                color: sharpeColor,
                absolute: L10n.Dashboard.rollingDays
            )
        }
    }

    // MARK: - Metric Column

    private func metricColumn(label: String, value: String, color: Color, absolute: String) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(color)

            if !absolute.isEmpty {
                Text(absolute)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.sm)
    }

    private var verticalDivider: some View {
        LinearGradient(
            colors: [.clear, colors.border.opacity(0.5), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1)
        .padding(.vertical, PulseSpacing.md)
    }

    private var thinDivider: some View {
        LinearGradient(
            colors: [.clear, colors.border.opacity(0.3), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1)
        .padding(.vertical, PulseSpacing.lg)
    }

    // MARK: - Sharpe

    private var sharpeColor: Color {
        let sr = kpis?.sharpeRatio ?? account?.sharpeRatio ?? 0
        if sr >= 2.0 { return PulseColors.accent }
        if sr >= 1.0 { return PulseColors.cyan }
        if sr >= 0.5 { return PulseColors.warning }
        return PulseColors.danger
    }

    // MARK: - Formatters

    private func formatPct(_ value: Double) -> String {
        if value == 0 { return "—" }
        return String(format: "%+.2f%%", value * 100)
    }

    private func formatPctRaw(_ value: Double) -> String {
        if value == 0 { return "—" }
        return String(format: "%.1f%%", value * 100)
    }

    private func formatMoney(_ value: Double) -> String {
        if value == 0 { return "—" }
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.0f", abs(value)))"
    }

    private func formatNumber(_ value: Double) -> String {
        if value == 0 { return "—" }
        return String(format: "%.2f", value)
    }
}
