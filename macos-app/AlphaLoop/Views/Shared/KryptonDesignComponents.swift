// KryptonDesignComponents.swift — Phase 3 新增组件
// StatusPill, TradingTable, ErrorBanner, SignalTag, RiskBadge

import SwiftUI

// MARK: - KryptonStatusPill

struct KryptonStatusPill: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    let value: String
    let state: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(state).frame(width: 5, height: 5)
                .shadow(color: state.opacity(0.5), radius: 3)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.monoLabel).foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }
}

// MARK: - KryptonRiskBadge

struct KryptonRiskBadge: View {
    enum Level: String {
        case low, medium, high, critical

        var color: Color {
            switch self {
            case .low: return KryptonColor.green
            case .medium: return Color(hex: "#f7a600")
            case .high: return KryptonColor.red
            case .critical: return Color(hex: "#ff4500")
            }
        }

        var label: String {
            switch self {
            case .low: return "LOW"
            case .medium: return "MED"
            case .high: return "HIGH"
            case .critical: return "CRIT"
            }
        }

        init(fromRiskLevel risk: String) {
            switch risk {
            case "low": self = .low
            case "high": self = .high
            case "critical": self = .critical
            default: self = .medium
            }
        }
    }

    let level: Level
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(level.color).frame(width: 5, height: 5)
                .shadow(color: level.color.opacity(0.5), radius: 2)
            if showLabel {
                Text(level.label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(level.color)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(level.color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.badge).stroke(level.color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - KryptonSignalTag

struct KryptonSignalTag: View {
    enum Direction {
        case long, short, neutral

        var color: Color {
            switch self {
            case .long: return KryptonColor.green
            case .short: return KryptonColor.red
            case .neutral: return Color(hex: "#f7a600")
            }
        }

        var label: String {
            switch self {
            case .long: return L10n.zh("LONG 多", en: "LONG")
            case .short: return L10n.zh("SHORT 空", en: "SHORT")
            case .neutral: return "NEUTRAL"
            }
        }
    }

    let direction: Direction
    let agentName: String
    var showAgent: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(direction.color).frame(width: 5, height: 5)
                Text(direction.label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(direction.color)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(direction.color.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.badge).stroke(direction.color.opacity(0.15), lineWidth: 1))

            if showAgent {
                Text(agentName)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - KryptonTradingTable

struct KryptonTradingTable<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    @Environment(PulseColors.self) private var colors

    let data: Data
    let columns: [TableColumn]
    let maxHeight: CGFloat?
    let emptyMessage: String
    @ViewBuilder let rowContent: (Data.Element) -> RowContent

    struct TableColumn {
        let label: String
        let width: CGFloat
        let alignment: Alignment

        init(_ label: String, width: CGFloat, alignment: Alignment = .leading) {
            self.label = label
            self.width = width
            self.alignment = alignment
        }
    }

    init(
        data: Data,
        columns: [TableColumn],
        maxHeight: CGFloat? = 240,
        emptyMessage: String = L10n.zh("暂无数据", en: "No Data"),
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.columns = columns
        self.maxHeight = maxHeight
        self.emptyMessage = emptyMessage
        self.rowContent = rowContent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    Text(col.label)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .frame(width: col.width, alignment: col.alignment)
                }
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 8)
            .background(colors.surface)

            Divider().background(colors.border)

            // Body
            if data.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text(emptyMessage)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                }
                .frame(height: 120)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                            rowContent(item)
                            if index < data.count - 1 {
                                Divider().background(colors.border.opacity(0.5))
                            }
                        }
                    }
                }
                .frame(maxHeight: maxHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }
}

// MARK: - KryptonErrorBanner

struct KryptonErrorBanner: View {
    @Environment(PulseColors.self) private var colors
    let message: String
    let severity: Severity
    let onDismiss: (() -> Void)?

    enum Severity {
        case info, warning, error, critical

        var color: Color {
            switch self {
            case .info: return KryptonColor.green
            case .warning: return Color(hex: "#f7a600")
            case .error: return KryptonColor.red
            case .critical: return Color(hex: "#ff4500")
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .critical: return "bolt.shield.fill"
            }
        }
    }

    init(message: String, severity: Severity = .info, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.severity = severity
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: severity.icon)
                .font(.system(size: 12))
                .foregroundStyle(severity.color)
                .shadow(color: severity.color.opacity(0.4), radius: 4)

            Text(message)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(severity.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - KryptonSectionHeader

struct KryptonSectionHeader: View {
    @Environment(PulseColors.self) private var colors
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "#f7a600"))
                .frame(width: 2, height: 14)

            Text(title)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.2)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct KryptonDesignComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            KryptonStatusPill(label: "FREQTRADE", value: "12ms", state: KryptonColor.green)
            KryptonRiskBadge(level: .high)
            KryptonRiskBadge(level: .low)
            KryptonSignalTag(direction: .long, agentName: "ALPHA-AGENT")
            KryptonSignalTag(direction: .short, agentName: "SENTINEL")
            KryptonErrorBanner(message: "Freqtrade connection lost — retrying in 5s", severity: .error, onDismiss: {})
            KryptonErrorBanner(message: "All systems operational", severity: .info)
            KryptonSectionHeader(title: "Active Positions")
        }
        .padding()
        .background(Color(hex: "#12151f"))
        .environment(PulseColors(themeManager: ThemeManager()))
    }
}
#endif
