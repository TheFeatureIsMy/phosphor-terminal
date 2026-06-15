// PositionRiskTable.swift — Position Risk Table for Dashboard Bento Grid
// Displays open positions with risk indicators, P&L, and reason chips.

import SwiftUI

// MARK: - Data Model

struct PositionData: Identifiable {
    let id = UUID()
    let symbol: String
    let direction: String  // "long" or "short"
    let size: Double
    let entryPrice: Double
    let pnl: Double
    let pnlPct: Double
    let riskLevel: String  // "low", "medium", "high"
    let reasonCodes: [String]

    var isLong: Bool { direction == "long" }
}

// MARK: - View

struct PositionRiskTable: View {
    @Environment(PulseColors.self) private var colors

    let positions: [PositionData]
    let openCount: Int

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Label
                TerminalLabel(
                    text: L10n.Dashboard.positionRisk + " · " + L10n.Dashboard.openCount(openCount)
                )

                if positions.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.xaxis",
                        title: L10n.Dashboard.noPositions,
                        description: ""
                    )
                } else {
                    // Header row
                    headerRow

                    // Position rows
                    ForEach(positions) { position in
                        positionRow(position)
                    }
                }
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Left stripe placeholder
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
            Text(L10n.Dashboard.pnl)
                .frame(minWidth: 70, alignment: .trailing)
            Text(L10n.Dashboard.pnlPct)
                .frame(minWidth: 60, alignment: .trailing)
            Text(L10n.Dashboard.risk)
                .frame(minWidth: 60, alignment: .center)
            Text(L10n.Dashboard.reason)
                .frame(minWidth: 80, alignment: .leading)
        }
        .font(PulseFonts.micro)
        .foregroundStyle(colors.textMuted)
        .textCase(.uppercase)
        .padding(.vertical, PulseSpacing.xxs)
    }

    // MARK: - Position Row

    private func positionRow(_ position: PositionData) -> some View {
        HStack(spacing: 0) {
            // Left color stripe
            Rectangle()
                .fill(position.isLong ? colors.profit : colors.loss)
                .frame(width: 3)

            Spacer().frame(width: PulseSpacing.xs)

            // Symbol
            Text(position.symbol)
                .font(PulseFonts.bodyMedium)
                .fontWeight(.bold)
                .foregroundStyle(colors.textPrimary)
                .frame(minWidth: 80, alignment: .leading)

            // Direction
            Text(position.isLong ? L10n.Dashboard.long : L10n.Dashboard.short)
                .font(PulseFonts.micro)
                .textCase(.uppercase)
                .foregroundStyle(position.isLong ? colors.profit : colors.loss)
                .frame(minWidth: 60, alignment: .leading)

            // Size
            Text(formatNumber(position.size))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)
                .frame(minWidth: 60, alignment: .trailing)

            // Entry
            Text(formatPrice(position.entryPrice))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)
                .frame(minWidth: 70, alignment: .trailing)

            // P&L
            Text(formatPnl(position.pnl))
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(position.pnl >= 0 ? colors.profit : colors.loss)
                .frame(minWidth: 70, alignment: .trailing)

            // P&L %
            Text(formatPnlPct(position.pnlPct))
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(position.pnlPct >= 0 ? colors.profit : colors.loss)
                .frame(minWidth: 60, alignment: .trailing)

            // Risk dot + label
            HStack(spacing: 4) {
                Circle()
                    .fill(riskColor(position.riskLevel))
                    .frame(width: 7, height: 7)

                Text(riskLabel(position.riskLevel))
                    .font(PulseFonts.micro)
                    .foregroundStyle(riskColor(position.riskLevel))
                    .textCase(.uppercase)
            }
            .frame(minWidth: 60, alignment: .center)

            // Reason chips
            HStack(spacing: 4) {
                ForEach(position.reasonCodes, id: \.self) { code in
                    Text(code)
                        .font(PulseFonts.micro)
                        .foregroundStyle(chipColor(code))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(chipColor(code).opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .stroke(chipColor(code).opacity(0.20), lineWidth: 0.5)
                        )
                }
            }
            .frame(minWidth: 80, alignment: .leading)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    // MARK: - Helpers

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "low": return PulseColors.StateColors.green
        case "medium": return PulseColors.StateColors.amber
        case "high": return PulseColors.StateColors.red
        default: return colors.textMuted
        }
    }

    private func riskLabel(_ level: String) -> String {
        switch level {
        case "low": return L10n.Dashboard.riskLow
        case "medium": return L10n.Dashboard.riskMed
        case "high": return L10n.Dashboard.riskHigh
        default: return level
        }
    }

    private func chipColor(_ code: String) -> Color {
        let lowered = code.lowercased()
        if lowered.contains("risk") || lowered.contains("vol") || lowered.contains("resistance") {
            return PulseColors.StateColors.amber
        } else if lowered.contains("stop") || lowered.contains("danger") || lowered.contains("breach") {
            return PulseColors.StateColors.red
        } else {
            return PulseColors.cyan
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && value < 1000 {
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

// MARK: - Mock Data

extension PositionRiskTable {
    static let mockPositions: [PositionData] = [
        PositionData(
            symbol: "BTC/USDT", direction: "long", size: 0.15,
            entryPrice: 67420, pnl: 1830, pnlPct: 2.71,
            riskLevel: "low", reasonCodes: ["trend_aligned"]
        ),
        PositionData(
            symbol: "ETH/USDT", direction: "long", size: 2.5,
            entryPrice: 3680, pnl: 425, pnlPct: 4.62,
            riskLevel: "medium", reasonCodes: ["near_resistance"]
        ),
        PositionData(
            symbol: "SOL/USDT", direction: "short", size: 20,
            entryPrice: 168.50, pnl: -180, pnlPct: -0.53,
            riskLevel: "medium", reasonCodes: ["vol_expanding"]
        ),
        PositionData(
            symbol: "AVAX/USDT", direction: "long", size: 50,
            entryPrice: 38.20, pnl: 340.80, pnlPct: 1.78,
            riskLevel: "low", reasonCodes: ["momentum_ok"]
        ),
    ]
}
