// AttributionView.swift — 归因分析页面

import SwiftUI

struct AttributionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var api: APIAttribution?
    @State private var featureData: FeatureImportanceResponse?
    @State private var slippageData: [SlippageItem] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("特征重要性", tag: 0)
                tabButton("滑点分析", tag: 1)
                tabButton("归因报告", tag: 2)
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.top, PulseSpacing.md)

            Divider().foregroundStyle(colors.border)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    Group {
                        switch selectedTab {
                        case 0: featureImportanceTab
                        case 1: slippageTab
                        case 2: reportsTab
                        default: EmptyView()
                        }
                    }
                    .padding(PulseSpacing.lg)
                }
            }
        }
        .task {
            api = APIAttribution(client: networkClient)
            await loadData()
        }
    }

    private var featureImportanceTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("SHAP 特征重要性")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            if let data = featureData {
                let maxVal = data.importances.map(abs).max() ?? 1
                ForEach(Array(zip(data.features, data.importances).enumerated()), id: \.offset) { _, pair in
                    HStack {
                        Text(pair.0)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textPrimary)
                            .frame(width: 80, alignment: .trailing)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(pair.1 > 0 ? PulseColors.accent : PulseColors.danger)
                                .frame(width: geo.size.width * CGFloat(abs(pair.1) / maxVal))
                        }
                        .frame(height: 16)

                        Text(String(format: "%.3f", pair.1))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            } else {
                EmptyStateView(icon: "chart.bar", title: "暂无特征数据", description: "运行策略后可查看特征重要性")
            }
        }
        .cardStyle()
    }

    private var slippageTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("滑点分析")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            if slippageData.isEmpty {
                EmptyStateView(icon: "chart.bar", title: "暂无滑点数据", description: "执行交易后将自动生成滑点分析")
            } else {
                ForEach(slippageData) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("信号价: \(String(format: "%.2f", item.signalPrice))")
                                .font(PulseFonts.caption)
                            Text("成交价: \(String(format: "%.2f", item.filledPrice))")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "滑点 %.2f", item.executionSlippage))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(PulseColors.warning)
                            Text(String(format: "%.3f%%", item.slippagePct))
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                    .padding(PulseSpacing.sm)
                    .background(colors.surface)
                    .cornerRadius(PulseRadii.sm)
                }
            }
        }
        .cardStyle()
    }

    private var reportsTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("归因报告")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)
            EmptyStateView(icon: "doc.text", title: "暂无归因报告", description: "运行策略回测后可生成归因报告")
        }
        .cardStyle()
    }

    private func tabButton(_ title: String, tag: Int) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedTab = tag }
        } label: {
            Text(title)
                .font(selectedTab == tag ? PulseFonts.bodyMedium : PulseFonts.body)
                .foregroundStyle(selectedTab == tag ? PulseColors.accent : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.sm)
                .background(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(selectedTab == tag ? PulseColors.accent : .clear)
                            .frame(height: 2)
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        featureData = try? await api?.getFeatureImportance(features: ["RSI", "MACD", "Volume", "BB_Upper", "EMA_20"], values: [65.5, 0.0023, 1500000, 72500, 69800])
        slippageData = (try? await api?.getSlippage()) ?? []
    }
}
