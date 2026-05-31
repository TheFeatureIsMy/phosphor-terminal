// RiskView.swift — 风险管理页面

import SwiftUI

struct RiskView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var riskEvents: [RiskEvent] = []
    @State private var correlation: [CorrelationSnapshot] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                HStack {
                    Text("风险管理")
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                }

                if isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else {
                    // Risk summary
                    HStack(spacing: PulseSpacing.md) {
                        riskStatCard(icon: "exclamationmark.triangle", label: "风险事件", value: "\(riskEvents.count)", color: PulseColors.warning)
                            .staggeredAppearance(index: 0, baseDelay: 0.02)
                        riskStatCard(icon: "link", label: "相关性对", value: "\(correlation.count)", color: PulseColors.info)
                            .staggeredAppearance(index: 1, baseDelay: 0.02)
                        riskStatCard(icon: "shield.checkered", label: "状态", value: riskEvents.isEmpty ? "正常" : "警告", color: riskEvents.isEmpty ? PulseColors.success : PulseColors.danger)
                            .staggeredAppearance(index: 2, baseDelay: 0.02)
                    }

                    Divider()
                        .foregroundStyle(colors.border)

                    // Risk events
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("风险事件")
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)

                        if riskEvents.isEmpty {
                            EmptyStateView(icon: "checkmark.shield", title: "一切正常", description: "暂无风险事件")
                        } else {
                            ForEach(Array(riskEvents.enumerated()), id: \.element.id) { index, event in
                                HStack {
                                    Image(systemName: event.eventType.icon)
                                        .foregroundStyle(event.severity.color)
                                    VStack(alignment: .leading) {
                                        Text(event.eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(PulseFonts.caption)
                                        Text(event.description ?? "")
                                            .font(PulseFonts.micro)
                                            .foregroundStyle(colors.textMuted)
                                    }
                                    Spacer()
                                    Text(event.severity.rawValue.capitalized)
                                        .font(PulseFonts.monoLabel)
                                        .foregroundStyle(event.severity.color)
                                }
                                .staggeredAppearance(index: index, baseDelay: 0.02)
                                .padding(PulseSpacing.sm)
                                .background(colors.surface)
                                .cornerRadius(PulseRadii.sm)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task { await loadData() }
    }

    private func riskStatCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)
            Text(label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.card)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let dashboard = APIDashboard(client: networkClient)
        riskEvents = (try? await dashboard.getRiskEvents()) ?? []
        correlation = (try? await dashboard.getCorrelation()) ?? []
    }
}
