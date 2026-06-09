// L10n+Navigation.swift — 侧边栏和路由标签

extension L10n {
    enum Nav {
        // Sections
        static var overview: String { zh("概览", en: "OVERVIEW") }
        static var strategy: String { zh("策略", en: "STRATEGY") }
        static var structure: String { zh("结构", en: "MARKET") }
        static var execution: String { zh("执行", en: "EXECUTION") }
        static var risk: String { zh("风控", en: "RISK") }
        static var aiResearch: String { zh("AI 研究", en: "AI RESEARCH") }
        static var growth: String { zh("增长", en: "PERFORMANCE") }
        static var system: String { zh("系统", en: "SYSTEM") }

        // Routes
        static var dashboard: String { zh("总览控制台", en: "Dashboard") }
        static var liveReadiness: String { zh("实盘准入", en: "Go-Live Checklist") }
        static var strategyWorkspace: String { zh("策略工作台", en: "Strategies") }
        static var strategyCanvas: String { zh("策略画布", en: "Strategy Canvas") }
        static var backtestSimulation: String { zh("回测 / 模拟", en: "Backtest & Paper") }
        static var marketStructure: String { zh("市场结构", en: "Market Structure") }
        static var structureMatrix: String { zh("结构矩阵", en: "Correlation Matrix") }
        static var manipulationRadar: String { zh("操纵雷达", en: "Surveillance") }
        static var executionCenter: String { zh("执行中心", en: "Execution") }
        static var ordersPositions: String { zh("订单 / 持仓", en: "Orders & Positions") }
        static var reconciliationBus: String { zh("对账总线", en: "Reconciliation") }
        static var riskCenter: String { zh("风控中心", en: "Risk Monitor") }
        static var stopProtection: String { zh("止损保护", en: "Stop-Loss Rules") }
        static var circuitBreakers: String { zh("熔断记录", en: "Circuit Breakers") }
        static var aiStudio: String { zh("AI 投研室", en: "AI Research") }
        static var agentPlatform: String { zh("Agent 平台", en: "AI Agents") }
        static var signalCenter: String { zh("信号中心", en: "Signals") }
        static var marketSentiment: String { zh("市场情绪", en: "Sentiment") }
        static var growthReview: String { zh("复盘成长", en: "Trade Review") }
        static var failureClustering: String { zh("失败聚类", en: "Loss Patterns") }
        static var strategyOptimization: String { zh("策略优化", en: "Optimization") }
        static var serviceManagement: String { zh("服务管理", en: "Services") }
        static var dataSourceManagement: String { zh("数据源管理", en: "Data Sources") }
        static var systemSettings: String { zh("系统设置", en: "Settings") }

        // Status bar
        static var strategies: String { zh("策略", en: "Strategies") }
        static var positions: String { zh("持仓", en: "Positions") }
        static var notifications: String { zh("通知", en: "Notifications") }
        static var searchShortcut: String { zh("搜索 (⌘K)", en: "Search (⌘K)") }
    }
}
