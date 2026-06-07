// L10n+AgentPlatform.swift — Agent 平台文案

extension L10n {
    enum Agent {
        static var title: String { zh("Agent 平台", en: "Agent Platform") }
        static var empty: String { zh("暂无 Agent", en: "No Agents") }
        static var emptyDesc: String { zh("Agent 将自动出现在此", en: "Agents will appear here automatically") }

        // Card
        static var signals: String { zh("信号", en: "Signals") }
        static var avgScore: String { zh("平均评分", en: "Avg Score") }
        static var recentSignals: String { zh("最近信号", en: "Recent Signals") }
        static var moreSignals: String { zh("更多信号", en: "More Signals") }

        // Kinds
        static var kindResearch: String { zh("研究", en: "Research") }
        static var kindManual: String { zh("手动", en: "Manual") }
        static var kindExecution: String { zh("执行", en: "Execution") }

        // Permission levels
        static var permObserveOnly: String { zh("仅观察", en: "Observe Only") }
        static var permAdvisory: String { zh("建议", en: "Advisory") }
        static var permExecute: String { zh("可执行", en: "Execute") }

        // Actions
        static var demote: String { zh("降级", en: "Demote") }
        static var disable: String { zh("禁用", en: "Disable") }
        static var promote: String { zh("升级", en: "Promote") }
        static var viewDetail: String { zh("查看详情", en: "View Details") }

        // Detail view
        static var detailTitle: String { zh("Agent 详情", en: "Agent Details") }
        static var performance: String { zh("性能指标", en: "Performance") }
        static var signalHistory: String { zh("信号历史", en: "Signal History") }
        static var configuration: String { zh("配置", en: "Configuration") }
        static var winRate: String { zh("胜率", en: "Win Rate") }
        static var weight: String { zh("权重", en: "Weight") }
        static var uptime: String { zh("运行时长", en: "Uptime") }
        static var lastHeartbeat: String { zh("最后心跳", en: "Last Heartbeat") }
        static var totalSignals: String { zh("总信号数", en: "Total Signals") }
        static var accuracy: String { zh("准确率", en: "Accuracy") }
    }
}
