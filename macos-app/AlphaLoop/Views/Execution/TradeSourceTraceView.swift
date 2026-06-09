// TradeSourceTraceView.swift — Trade Source Trace §5.4
// 纵向链路图：Signal → Strategy → Snapshot → RiskDecision → Execution → Trade

import SwiftUI

struct TradeSourceTraceView: View {
    @Environment(PulseColors.self) private var colors
    let trace: TradeSourceTrace?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .foregroundStyle(PulseColors.accent)
                    .font(.system(size: 12))
                Text(L10n.zh("来源追踪", en: "Source Trace"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            if let trace = trace?.trace {
                VStack(alignment: .leading, spacing: 0) {
                    traceNode(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Signal",
                        subtitle: trace.signal?.direction ?? L10n.zh("无信号", en: "No signal"),
                        detail: trace.signal?.sourceType,
                        color: PulseColors.cyan,
                        isFirst: true
                    )
                    traceConnector()
                    traceNode(
                        icon: "doc.text.fill",
                        title: "Strategy",
                        subtitle: trace.strategy?.strategyName ?? L10n.zh("无策略", en: "No strategy"),
                        detail: trace.strategy?.dslVersion.map { "DSL v\($0)" },
                        color: PulseColors.accent
                    )
                    traceConnector()
                    traceNode(
                        icon: "camera.metering.spot",
                        title: "Snapshot",
                        subtitle: trace.runtimeSnapshot?.decision ?? L10n.zh("无快照", en: "No snapshot"),
                        detail: trace.runtimeSnapshot?.reasonCodes?.joined(separator: ", "),
                        color: PulseColors.amber
                    )
                    traceConnector()
                    traceNode(
                        icon: "shield.checkered",
                        title: "Risk Decision",
                        subtitle: trace.riskDecision?.decisionType ?? L10n.zh("无决策", en: "No decision"),
                        detail: trace.riskDecision?.reasonCode,
                        color: riskDecisionColor(trace.riskDecision?.decisionType)
                    )
                    traceConnector()
                    traceNode(
                        icon: "bolt.fill",
                        title: "Execution",
                        subtitle: trace.execution?.runMode ?? L10n.zh("无执行", en: "No execution"),
                        detail: trace.execution?.pnlPct.map { String(format: "%.2f%%", $0 * 100) },
                        color: executionColor(trace.execution?.pnlPct),
                        isLast: true
                    )
                }
            } else {
                Text(L10n.zh("暂无追踪数据", en: "No trace data"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PulseSpacing.md)
            }
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(colors.border, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func traceNode(
        icon: String,
        title: String,
        subtitle: String,
        detail: String?,
        color: Color,
        isFirst: Bool = false,
        isLast: Bool = false
    ) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Text(subtitle)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func traceConnector() -> some View {
        HStack {
            Rectangle()
                .fill(colors.border)
                .frame(width: 1.5, height: 12)
                .padding(.leading, 13)
            Spacer()
        }
    }

    private func riskDecisionColor(_ type: String?) -> Color {
        switch type {
        case "ALLOW": PulseColors.accent
        case "REDUCE_SIZE": PulseColors.amber
        case "REJECT": PulseColors.danger
        default: colors.textMuted
        }
    }

    private func executionColor(_ pnl: Double?) -> Color {
        guard let pnl else { return colors.textMuted }
        return pnl >= 0 ? PulseColors.accent : PulseColors.danger
    }
}
