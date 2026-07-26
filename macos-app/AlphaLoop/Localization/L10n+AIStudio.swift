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

        // MARK: - Protocol research-03 稿布局
        static var protoEyebrow: String { zh("Multi-Agent Research · 多 Agent 投研辩论", en: "Multi-Agent Research") }
        static var protoTitle: String { zh("让多位分析师为你辩一场", en: "Let the analysts debate for you") }
        static func protoSubtitle(_ symbol: String) -> String { zh("对 \(symbol) 展开多 Agent 研究、多空辩论、风控裁定，产出可读的投研结论与可发布信号。", en: "Multi-agent research, debate and risk ruling on \(symbol), producing readable conclusions and publishable signals.") }
        static var agentsTitle: String { zh("多 Agent 观点", en: "Agent Perspectives") }
        static var agentsCount: String { zh("位分析师并陈", en: "analysts") }
        static var stanceBull: String { zh("看多", en: "Long") }
        static var stanceBear: String { zh("看空", en: "Short") }
        static var stanceNeutral: String { zh("中性", en: "Neutral") }
        static var stanceRisk: String { zh("放行(约束)", en: "Pass (constrained)") }
        static var verdictTitle: String { zh("综合裁定 · 结论", en: "Verdict · Conclusion") }
        static var verdictConsensus: String { zh("综合共识", en: "Consensus") }
        static var currentPrice: String { zh("现价", en: "Price") }
        static var change24h: String { zh("24h", en: "24h") }
        static var perpSuffix: String { zh("· 永续", en: " · Perp") }
        static var triggerReason: String { zh("本次研究触发原因", en: "Trigger") }
        static var evidence: String { zh("证据", en: "Evidence") }
        static var estimatedNote: String { zh("置信度为估算", en: "confidence estimated") }
        static var noFakeInsight: String { zh("AI 结论仅供参考，不构成交易指令", en: "AI conclusions are advisory only, not trading commands") }
    }

        // Evidence & traceability (R9)
        static var modelProvider: String { zh("模型供应商", en: "Model Provider") }
        static var modelName: String { zh("模型名称", en: "Model Name") }
        static var promptVersion: String { zh("Prompt 版本", en: "Prompt Version") }
        static var inputDataSource: String { zh("输入数据源", en: "Input Data Source") }
        static var evidenceSource: String { zh("证据来源", en: "Evidence Source") }
        static var modelLatency: String { zh("模型延迟", en: "Model Latency") }
        static var uncertainty: String { zh("不确定性", en: "Uncertainty") }
        static var facts: String { zh("事实", en: "Facts") }
        static var modelInterpretation: String { zh("模型解读", en: "Model Interpretation") }
        static var tradingImplication: String { zh("交易含义", en: "Trading Implication") }
        static var riskWarning: String { zh("风险提示", en: "Risk Warning") }
        static var strategyImpact: String { zh("策略影响", en: "Strategy Impact") }
        static var noFakeInsight: String { zh("AI 结论仅供参考，不构成交易指令", en: "AI conclusions are advisory only, not trading commands") }
        static var separationNotice: String { zh("事实 = 可观测数据 | 解读 = 模型推断 | 建议 = 仅供参考", en: "Facts = observable | Interpretation = inferred | Recommendation = advisory") }
}
