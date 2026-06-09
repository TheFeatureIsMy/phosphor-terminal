// L10n+Dashboard.swift — AI 总控台文案

extension L10n {
    enum Dashboard {
        // AI Status Bar
        static var aiProvider: String { zh("AI Provider", en: "AI Provider") }
        static var localGPU: String { zh("本地 GPU", en: "Local GPU") }
        static var todayAICost: String { zh("今日 AI 成本", en: "Today's AI Cost") }
        static var pendingTasks: String { zh("待处理任务", en: "Pending Tasks") }
        static var providerNormal: String { zh("正常", en: "Normal") }
        static var providerDegraded: String { zh("降级", en: "Degraded") }
        static var providerUnavailable: String { zh("不可用", en: "Unavailable") }
        static var gpuRunning: String { zh("运行中", en: "Running") }
        static var gpuIdle: String { zh("空闲", en: "Idle") }
        static var gpuUnavailable: String { zh("不可用", en: "Unavailable") }

        // AI Market Judgment
        static var aiMarketJudgment: String { zh("今日 AI 市场判断", en: "AI Market Assessment") }
        static var confidence: String { zh("置信度", en: "Confidence") }
        static var bullish: String { zh("看多", en: "Bullish") }
        static var bearish: String { zh("看空", en: "Bearish") }
        static var sideways: String { zh("震荡", en: "Sideways") }
        static var riskLow: String { zh("低风险", en: "Low Risk") }
        static var riskMedium: String { zh("中风险", en: "Medium Risk") }
        static var riskHigh: String { zh("高风险", en: "High Risk") }
        static var riskCritical: String { zh("极高风险", en: "Critical Risk") }

        // Positions + Risk Card
        static var positionsAndRisk: String { zh("当前持仓 + 风险状态", en: "Positions & Risk Status") }
        static func positionCount(_ n: Int) -> String { zh("\(n) 个持仓", en: "\(n) Position\(n == 1 ? "" : "s")") }
        static var noActivePositions: String { zh("无活跃持仓", en: "No Active Positions") }
        static var symbol: String { zh("品种", en: "Symbol") }
        static var direction: String { zh("方向", en: "Side") }
        static var pnl: String { zh("盈亏", en: "P&L") }
        static var aiSuggestion: String { zh("AI 建议", en: "AI Advice") }
        static var risk: String { zh("风险", en: "Risk") }
        static var long: String { zh("多", en: "Long") }
        static var short: String { zh("空", en: "Short") }

        // AI Recommendations
        static var hold: String { zh("持有", en: "Hold") }
        static var reduce: String { zh("减仓", en: "Reduce") }
        static var takeProfit: String { zh("止盈", en: "Take Profit") }
        static var closePosition: String { zh("平仓", en: "Close") }

        // Risk levels
        static var riskLevelLow: String { zh("低", en: "Low") }
        static var riskLevelMedium: String { zh("中", en: "Med") }
        static var riskLevelHigh: String { zh("高", en: "High") }

        // Pending Confirmations
        static var pendingConfirmations: String { zh("需人工确认事项", en: "Pending Confirmations") }
        static var noPendingItems: String { zh("无待处理事项", en: "No Pending Items") }
        static var reject: String { zh("拒绝", en: "Reject") }
        static var approve: String { zh("批准", en: "Approve") }

        // Agent Signal Distribution
        static var agentSignalDist: String { zh("Agent 信号分布", en: "Agent Signal Distribution") }
        static var noSignalData: String { zh("暂无信号数据", en: "No Signal Data") }

        // Strategy Status Overview
        static var strategyOverview: String { zh("策略状态总览", en: "Strategy Overview") }
        static var draft: String { zh("草稿", en: "Draft") }
        static var running: String { zh("运行中", en: "Active") }
        static var dryRun: String { zh("模拟盘", en: "Paper") }
        static var paused: String { zh("已暂停", en: "Paused") }

        // Risk Interception Stats
        static var riskInterception: String { zh("风险拦截统计", en: "Risk Interception Stats") }
        static var rejected: String { zh("已拒绝", en: "Rejected") }
        static var reduced: String { zh("已减仓", en: "Reduced") }
        static var paperOnly: String { zh("仅模拟", en: "Paper Only") }
        static var allowed: String { zh("已放行", en: "Allowed") }

        // Expandable section
        static var moreAnalysis: String { zh("更多分析", en: "More Analytics") }

        // Equity Curve
        static var equityCurve: String { zh("权益曲线", en: "Equity Curve") }

        // Empty state
        static var aiControlTower: String { zh("AI 总控台", en: "AI Control Tower") }
        static var waitingForData: String { zh("等待 AI Agent 数据加载...", en: "Waiting for AI Agent data...") }
    }
}
