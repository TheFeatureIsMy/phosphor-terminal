// AccountHeroCard.swift — Hero card: equity, currency, 24h change, P&L metrics
// Left: large equity + change. Right: 4 metric columns with dividers.

import SwiftUI

struct AccountHeroCard: View {
    @Environment(PulseColors.self) private var colors
    let account: AccountOverviewResponse
    let equityCurve: [EquityPoint]

    @State private var displayEquity: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        KryptonCard(emphasis: .bold) {
            HStack(spacing: 0) {
                // MARK: - Left: Equity + Change
                leftPanel

                // Vertical divider
                verticalDivider

                // MARK: - Right: 4 Metric Columns
                rightPanel
            }
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Dashboard.accountOverview)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.2f", displayEquity))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(colors.textPrimary)
                    .contentTransition(.numericText())

                Text(account.currency)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                withAnimation(.spring(response: 1.5, dampingFraction: 0.7)) {
                    displayEquity = account.equity
                }
            }
            .onChange(of: account.equity) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayEquity = newValue
                }
            }

            // 24h change line
            HStack(spacing: 6) {
                let isPositive = account.todayPnlPct >= 0
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isPositive ? colors.profit : colors.loss)

                Text(String(format: "%+.2f%%", account.todayPnlPct * 100))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(isPositive ? colors.profit : colors.loss)

                Text("24h")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(isPositive
                                  ? colors.profit.opacity(0.1)
                                  : colors.loss.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(isPositive
                                    ? colors.profit.opacity(0.2)
                                    : colors.loss.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .frame(width: 420, alignment: .leading)
        .padding(.trailing, PulseSpacing.lg)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        HStack(spacing: 0) {
            metricColumn(
                label: L10n.Dashboard.todayPnl,
                value: String(format: "%+.2f%%", account.todayPnlPct * 100),
                color: account.todayPnlPct >= 0 ? colors.profit : colors.loss,
                absolute: String(format: "$%.0f", account.equity * abs(account.todayPnlPct))
            )

            thinDivider

            metricColumn(
                label: L10n.Dashboard.weekPnl,
                value: String(format: "%+.2f%%", account.weekPnlPct * 100),
                color: account.weekPnlPct >= 0 ? colors.profit : colors.loss,
                absolute: String(format: "$%.0f", account.equity * abs(account.weekPnlPct))
            )

            thinDivider

            metricColumn(
                label: L10n.Dashboard.maxDrawdown,
                value: String(format: "%.2f%%", account.maxDrawdownPct * 100),
                color: PulseColors.warning,
                absolute: String(format: "$%.0f", account.equity * account.maxDrawdownPct)
            )

            thinDivider

            metricColumn(
                label: L10n.Dashboard.sharpeRatio,
                value: String(format: "%.2f", account.sharpeRatio ?? 0),
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

            Text(absolute)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - Dividers

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


    // MARK: - Sharpe Color

    private var sharpeColor: Color {
        let sr = account.sharpeRatio ?? 0
        if sr >= 2.0 { return colors.profit }
        if sr >= 1.0 { return PulseColors.cyan }
        if sr >= 0.5 { return PulseColors.warning }
        return colors.loss
    }
}
