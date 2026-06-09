// ServiceHealthCard.swift — Bento 卡片: 服务 & 数据源健康
import SwiftUI

struct ServiceHealthCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let services: [ServiceStatus]

    struct ServiceStatus: Identifiable {
        let id = UUID()
        let name: String
        let state: StateType
        let detail: String

        enum StateType {
            case healthy, degraded, down

            var color: Color {
                switch self {
                case .healthy: return KryptonColor.green
                case .degraded: return KryptonColor.amber
                case .down: return KryptonColor.red
                }
            }

            var label: String {
                switch self {
                case .healthy: return "OK"
                case .degraded: return "DEGRADED"
                case .down: return "DOWN"
                }
            }
        }
    }

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.zh("服务 & 数据源健康", en: "Service & Data Source Health"))

                if services.isEmpty {
                    Text(L10n.zh("等待健康检查数据...", en: "Awaiting health check data..."))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(.vertical, PulseSpacing.sm)
                } else {
                    VStack(spacing: 1) {
                        ForEach(services) { svc in
                            serviceRow(svc)
                        }
                    }
                }
            }
        }
        .hoverEffect()
        .id(settingsState.language)
    }

    private func serviceRow(_ svc: ServiceStatus) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Circle()
                .fill(svc.state.color)
                .frame(width: 5, height: 5)
                .shadow(color: svc.state.color.opacity(0.4), radius: 3)

            Text(svc.name)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Text(svc.state.label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(svc.state.color)
                    .fontWeight(.bold)

                Text(svc.detail)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, PulseSpacing.xs)
    }
}

// MARK: - Preview Helpers

extension ServiceHealthCard.ServiceStatus {
    static var previewData: [ServiceHealthCard.ServiceStatus] {
        [
            ServiceHealthCard.ServiceStatus(name: "Freqtrade", state: .healthy, detail: "12ms"),
            ServiceHealthCard.ServiceStatus(name: "Redis", state: .healthy, detail: "2ms"),
            ServiceHealthCard.ServiceStatus(name: "Binance API", state: .healthy, detail: "45ms"),
            ServiceHealthCard.ServiceStatus(name: "OKX API", state: .healthy, detail: "38ms"),
            ServiceHealthCard.ServiceStatus(name: "Bybit WS", state: .healthy, detail: "LIVE"),
            ServiceHealthCard.ServiceStatus(name: "PostgreSQL", state: .healthy, detail: "OK"),
            ServiceHealthCard.ServiceStatus(name: "OpenAI API", state: .degraded, detail: "1.2s"),
            ServiceHealthCard.ServiceStatus(name: "Claude API", state: .healthy, detail: "320ms"),
        ]
    }
}
