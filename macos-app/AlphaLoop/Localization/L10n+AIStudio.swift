// L10n+AIStudio.swift — AI 投研室文案

extension L10n {
    enum AIStudio {
        // Header
        static var title: String { zh("AI 投研室", en: "AI Research Studio") }
        static var subtitle: String { zh("多智能体协同研究 · TradingAgents", en: "Multi-Agent Research · TradingAgents") }

        // Research input
        static var researchTarget: String { zh("研究标的", en: "Research Target") }
        static var enterSymbol: String { zh("输入交易对...", en: "Enter symbol...") }
        static var researchDepth: String { zh("研究深度", en: "Research Depth") }
        static var popular: String { zh("热门:", en: "Popular:") }
        static var startResearch: String { zh("开始研究", en: "Start Research") }

        // Depth options
        static var depthQuick: String { zh("快速", en: "Quick") }
        static var depthStandard: String { zh("标准", en: "Standard") }
        static var depthDeep: String { zh("深度", en: "Deep") }

        // Research progress
        static var analyzing: String { zh("多智能体分析中...", en: "Multi-Agent Analysis in Progress...") }
        static var analyzingDesc: String { zh("正在调用 Bull / Bear / Technical / Sentiment / On-chain / Risk 智能体", en: "Invoking Bull / Bear / Technical / Sentiment / On-chain / Risk agents") }

        // Perspectives
        static var multiPerspective: String { zh("多视角分析", en: "Multi-Perspective Analysis") }
        static var bullView: String { zh("多头观点", en: "Bull Thesis") }
        static var bearView: String { zh("空头观点", en: "Bear Thesis") }
        static var technicalAnalysis: String { zh("技术分析", en: "Technical Analysis") }
        static var sentimentAnalysis: String { zh("情绪分析", en: "Sentiment Analysis") }
        static var onChainAnalysis: String { zh("链上分析", en: "On-Chain Analysis") }
        static var riskAssessment: String { zh("风险评估", en: "Risk Assessment") }
        static var fundamentals: String { zh("基本面", en: "Fundamentals") }
        static var newsAnalysis: String { zh("新闻分析", en: "News Analysis") }

        // Final rating
        static var finalRating: String { zh("最终评级", en: "Final Rating") }
        static var direction: String { zh("方向", en: "Direction") }
        static var confidence: String { zh("置信度", en: "Confidence") }
        static var riskLevel: String { zh("风险等级", en: "Risk Level") }
        static var recommendation: String { zh("综合建议", en: "Recommendation") }

        // Direction labels
        static var bullish: String { zh("看多", en: "Bullish") }
        static var bearish: String { zh("看空", en: "Bearish") }
        static var sideways: String { zh("震荡", en: "Sideways") }

        // Actions
        static var generateDraft: String { zh("生成策略草稿", en: "Generate Strategy Draft") }
        static var generatingDraft: String { zh("生成中...", en: "Generating...") }
        static var publishAsSignal: String { zh("发布为信号", en: "Publish as Signal") }
        static var publishing: String { zh("发布中...", en: "Publishing...") }

        // Errors
        static var enterTarget: String { zh("请输入研究标的", en: "Please enter a research target") }
        static var researchFailed: String { zh("研究失败", en: "Research Failed") }
        static func requestFailed(_ detail: String) -> String { zh("研究请求失败: \(detail)", en: "Research request failed: \(detail)") }
        static func publishFailed(_ detail: String) -> String { zh("发布信号失败: \(detail)", en: "Failed to publish signal: \(detail)") }
        static func draftFailed(_ detail: String) -> String { zh("生成策略草稿失败: \(detail)", en: "Failed to generate strategy draft: \(detail)") }
    }
}
