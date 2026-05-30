// SentimentView.swift — 市场情绪页面

import SwiftUI

struct SentimentView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var api: APISentiment?
    @State private var summary: SentimentSummaryResponse?
    @State private var isLoading = true
    @State private var analysisText = ""
    @State private var analysisResult: TextSentimentResponse?
    @State private var isAnalyzing = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // Header
                HStack {
                    Text("市场情绪")
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                }

                if isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else {
                    // Fear & Greed Gauge
                    if let summary {
                        HStack(alignment: .top, spacing: PulseSpacing.lg) {
                            FearGreedGauge(
                                index: summary.fearGreedIndex,
                                label: summary.fearGreedLabel
                            )
                            .frame(width: 200)

                            // Symbol sentiments
                            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                                Text("市场概览")
                                    .font(PulseFonts.bodyMedium)
                                    .foregroundStyle(colors.textPrimary)

                                ForEach(summary.marketOverview, id: \.symbol) { item in
                                    HStack {
                                        Text(item.symbol)
                                            .font(PulseFonts.bodyMedium)
                                            .foregroundStyle(colors.textPrimary)
                                            .frame(width: 60, alignment: .leading)

                                        // Score bar
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(colors.surface)
                                                .overlay(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(colorForSentiment(item.sentiment))
                                                        .frame(width: geo.size.width * item.score)
                                                }
                                        }
                                        .frame(height: 8)

                                        Text(String(format: "%.0f%%", item.score * 100))
                                            .font(PulseFonts.monoLabel)
                                            .foregroundStyle(colorForSentiment(item.sentiment))
                                            .frame(width: 40, alignment: .trailing)
                                    }
                                }
                            }
                        }
                        .cardStyle()
                    }

                    // Text Analysis
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("文本情绪分析")
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)

                        TextEditor(text: $analysisText)
                            .font(PulseFonts.body)
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                            .padding(PulseSpacing.xs)
                            .background(colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))

                        HStack {
                            Spacer()
                            ProofAlphaButton(title: "分析") {
                                Task { await analyzeText() }
                            }
                            .disabled(analysisText.isEmpty || isAnalyzing)
                        }

                        if let result = analysisResult {
                            HStack(spacing: PulseSpacing.lg) {
                                sentimentBar(label: "正面", value: result.positive, color: PulseColors.success)
                                sentimentBar(label: "中性", value: result.neutral, color: colors.textMuted)
                                sentimentBar(label: "负面", value: result.negative, color: PulseColors.danger)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task {
            api = APISentiment(client: networkClient)
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        summary = try? await api?.getSummary()
    }

    private func analyzeText() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        analysisResult = try? await api?.analyzeText(analysisText)
    }

    private func sentimentBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: CGFloat(value) * 100, height: 6)
                Text(String(format: "%.0f%%", value * 100))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(color)
            }
        }
    }

    private func colorForSentiment(_ s: String) -> Color {
        switch s {
        case "positive": return PulseColors.success
        case "negative": return PulseColors.danger
        default: return PulseColors.warning
        }
    }
}
