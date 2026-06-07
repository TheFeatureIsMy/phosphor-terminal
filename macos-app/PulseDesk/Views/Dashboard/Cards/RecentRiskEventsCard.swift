// RecentRiskEventsCard.swift — Bento 卡片: 最近风险事件
import SwiftUI

struct RecentRiskEventsCard: View {
    @Environment(PulseColors.self) private var colors

    let events: [RiskEventItem]

    struct RiskEventItem: Identifiable {
        let id = UUID()
        let type: EventType
        let description: String
        let time: String

        enum EventType {
            case stopLoss, circuitBreaker, apiError, dataAnomaly, correlation

            var icon: String {
                switch self {
                case .stopLoss: return "shield.slash.fill"
                case .circuitBreaker: return "bolt.circle.fill"
                case .apiError: return "wifi.exclamationmark"
                case .dataAnomaly: return "chart.line.flattrend.xyaxis"
                case .correlation: return "link.circle.fill"
                }
            }

            var color: Color {
                switch self {
                case .stopLoss: return KryptonColor.red
                case .circuitBreaker: return KryptonColor.red
                case .apiError: return KryptonColor.amber
                case .dataAnomaly: return KryptonColor.amber
                case .correlation: return PulseColors.cyan
                }
            }
        }
    }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "最近风险事件")

                if events.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        StatusDot(status: .online)
                        Text("无最近风险事件")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(.vertical, PulseSpacing.sm)
                } else {
                    VStack(spacing: 0) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                }
            }
        }
        .hoverEffect()
    }

    private func eventRow(_ event: RiskEventItem) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: event.type.icon)
                .font(.system(size: 11))
                .foregroundStyle(event.type.color)
                .frame(width: 20)
                .shadow(color: event.type.color.opacity(0.3), radius: 3)

            Text(event.description)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(event.time)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, PulseSpacing.xs)
        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(Color.clear))
        .overlay(alignment: .bottom) {
            if event.id != events.last?.id {
                Rectangle().fill(colors.border.opacity(0.5)).frame(height: 0.5)
            }
        }
    }
}

// MARK: - Preview Data

extension RecentRiskEventsCard.RiskEventItem {
    static var previewData: [RecentRiskEventsCard.RiskEventItem] {
        [
            RecentRiskEventsCard.RiskEventItem(type: .stopLoss, description: "BTC/USDT 止损触发 — 亏损 2.3%", time: "14:28"),
            RecentRiskEventsCard.RiskEventItem(type: .circuitBreaker, description: "ETH 熔断 — 连续 3 次触发风控", time: "13:15"),
            RecentRiskEventsCard.RiskEventItem(type: .apiError, description: "Binance API 短暂超时 — 已自动重连", time: "12:02"),
            RecentRiskEventsCard.RiskEventItem(type: .dataAnomaly, description: "SOL 价格偏离 — 数据源延迟 >500ms", time: "10:48"),
        ]
    }
}
