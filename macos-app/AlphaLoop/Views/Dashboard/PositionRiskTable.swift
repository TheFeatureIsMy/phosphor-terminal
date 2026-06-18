// PositionRiskTable.swift — Position Risk Table for Dashboard Bento Grid
// Displays real open positions from /api/execution/positions.
// No mock fallback: when the data source is unavailable the table renders
// EmptyStateView with the data-source-unavailable tag.

import SwiftUI

// MARK: - Data Model

struct PositionData: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let direction: String
    let size: Double
    let entryPrice: Double
    let currentPrice: Double
    let pnl: Double
    let pnlPct: Double
    let riskLevel: String
    let reasonCodes: [String]
    let stateDifference: String?

    var isLong: Bool { direction.lowercased() == "long" }

    var stateKey: String {
        switch (stateDifference ?? "").lowercased() {
        case "in_sync", "": return "in_sync"
        case "drift": return "drift"
        case "local_only": return "local_only"
        case "exchange_only": return "exchange_only"
        default: return "unknown"
        }
    }
}

// MARK: - View

struct PositionRiskTable: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let positions: [PositionData]
    let openCount: Int
    let dataSourceAvailable: Bool

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(alignment: .center, spacing: PulseSpacing.xs) {
                    TerminalLabel(text: L10n.Dashboard.positionRisk + " · " + L10n.Dashboard.openCount(openCount))

                    Spacer()

                    if !dataSourceAvailable {
                        dataSourceBadge
                    }
                }

                if positions.isEmpty {
                    EmptyStateView(
                        icon: dataSourceAvailable ? "chart.bar.xaxis" : "antenna.radiowaves.left.and.right.slash",
                        title: dataSourceAvailable
                            ? L10n.Dashboard.noPositions
                            : L10n.Dashboard.dataSourceUnavailable,
                        description: ""
                    )
                    .frame(minHeight: 120)
                } else {
                    headerRow
                    ForEach(positions) { position in
                        positionRow(position)
                    }
                }
            }
        }
    }

    private var dataSourceBadge: some View {
        Text(L10n.Dashboard.dataSourceUnavailable)
            .font(PulseFonts.micro)
            .foregroundStyle(PulseColors.warning)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(PulseColors.warning.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(PulseColors.warning.opacity(0.25), lineWidth: 0.5)
            )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 3)
            Spacer().frame(width: PulseSpacing.xs)

            Text(L10n.Dashboard.symbol)
                .frame(minWidth: 80, alignment: .leading)
            Text(L10n.Dashboard.direction)
                .frame(minWidth: 60, alignment: .leading)
            Text(L10n.Dashboard.size)
                .frame(minWidth: 60, alignment: .trailing)
            Text(L10n.Dashboard.entry)
                .frame(minWidth: 70, alignment: .trailing)
            Text(L10n.Dashboard.mark)
                .frame(minWidth: 70, alignment: .trailing)
            Text(L10n.Dashboard.pnl)
                .frame(minWidth: 70, alignment: .trailing)
            Text(L10n.Dashboard.pnlPct)
                .frame(minWidth: 60, alignment: .trailing)
            Text(L10n.Dashboard.risk)
                .frame(minWidth: 70, alignment: .center)
        }
        .font(PulseFonts.micro)
        .foregroundStyle(colors.textMuted)
        .textCase(.uppercase)
        .padding(.vertical, PulseSpacing.xxs)
    }

    // MARK: - Position Row

    private func positionRow(_ position: PositionData) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(position.isLong ? PulseColors.accent : PulseColors.danger)
                .frame(width: 3)
                .shadow(color: (position.isLong ? PulseColors.accent : PulseColors.danger).opacity(0.4), radius: 3)

            Spacer().frame(width: PulseSpacing.xs)

            Text(position.symbol)
                .font(PulseFonts.bodyMedium)
                .fontWeight(.bold)
                .foregroundStyle(colors.textPrimary)
                .frame(minWidth: 80, alignment: .leading)

            Text(position.isLong ? L10n.Dashboard.long : L10n.Dashboard.short)
                .font(PulseFonts.micro)
                .textCase(.uppercase)
                .foregroundStyle(position.isLong ? PulseColors.accent : PulseColors.danger)
                .frame(minWidth: 60, alignment: .leading)

            Text(formatNumber(position.size))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)
                .frame(minWidth: 60, alignment: .trailing)

            Text(formatPrice(position.entryPrice))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)
                .frame(minWidth: 70, alignment: .trailing)

            Text(formatPrice(position.currentPrice))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .frame(minWidth: 70, alignment: .trailing)

            Text(formatPnl(position.pnl))
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(position.pnl >= 0 ? PulseColors.accent : PulseColors.danger)
                .frame(minWidth: 70, alignment: .trailing)

            Text(formatPnlPct(position.pnlPct))
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(position.pnlPct >= 0 ? PulseColors.accent : PulseColors.danger)
                .frame(minWidth: 60, alignment: .trailing)

            stateBadge(for: position)
                .frame(minWidth: 70, alignment: .center)
        }
        .padding(.vertical, PulseSpacing.xxs)
        .id(settingsState.language)
    }

    // MARK: - State Badge

    private func stateBadge(for position: PositionData) -> some View {
        let (label, color) = stateMeta(position.stateKey)
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.4), radius: 2)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(color)
                .textCase(.uppercase)
        }
    }

    private func stateMeta(_ key: String) -> (String, Color) {
        switch key {
        case "in_sync": return (L10n.Dashboard.stateInSync, PulseColors.StateColors.green)
        case "drift": return (L10n.Dashboard.stateDrift, PulseColors.StateColors.amber)
        case "local_only": return (L10n.Dashboard.stateLocalOnly, PulseColors.cyan)
        case "exchange_only": return (L10n.Dashboard.stateExchangeOnly, PulseColors.cyan)
        default: return (L10n.Dashboard.stateUnknown, colors.textMuted)
        }
    }

    // MARK: - Number formatting

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }

    private func formatPrice(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        } else if value >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.4f", value)
        }
    }

    private func formatPnl(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        if abs(value) >= 1000 {
            return prefix + String(format: "%.0f", value)
        }
        return prefix + String(format: "%.2f", value)
    }

    private func formatPnlPct(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + String(format: "%.2f%%", value)
    }
}
