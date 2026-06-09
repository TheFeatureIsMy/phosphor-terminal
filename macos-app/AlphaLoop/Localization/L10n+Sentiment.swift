// L10n+Sentiment.swift — 市场情绪文案

extension L10n {
    enum Sentiment {
        // Header
        static var title: String { zh("市场情绪", en: "Market Sentiment") }

        // Fear & Greed
        static var marketOverview: String { zh("市场概览", en: "Market Overview") }

        // Text Analysis
        static var textAnalysis: String { zh("文本情绪分析", en: "Text Sentiment Analysis") }
        static var analyze: String { zh("分析", en: "Analyze") }

        // Sentiment labels
        static var positive: String { zh("正面", en: "Positive") }
        static var neutral: String { zh("中性", en: "Neutral") }
        static var negative: String { zh("负面", en: "Negative") }

        // Publish
        static var publishAsSignal: String { zh("发布为信号", en: "Publish as Signal") }
        static func published(_ id: String) -> String { zh("已发布: \(id)...", en: "Published: \(id)...") }
    }
}
