// L10n+Risk.swift — 风控页面文案

extension L10n {
    enum Risk {
        static var blockNewEntries: String { zh("禁止新开仓", en: "Block New Entries") }
        static var unblock: String { zh("解除禁止", en: "Unblock") }
        static var confirmBlock: String { zh("确认禁止新开仓", en: "Confirm Block New Entries") }
        static var confirmUnblock: String { zh("确认解除禁止", en: "Confirm Unblock") }
        static var riskRules: String { zh("风控规则", en: "Risk Rules") }
        static var riskRulesSummary: String { zh("当前生效的阈值与开关", en: "Currently effective thresholds and switches") }
        static var dailyLossLimit: String { zh("日亏损上限", en: "Daily Loss Limit") }
        static var weeklyLossLimit: String { zh("周亏损上限", en: "Weekly Loss Limit") }
        static var consecutiveLosses: String { zh("连续亏损次数", en: "Consecutive Losses") }
        static var maxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var correlationThreshold: String { zh("相关性阈值", en: "Correlation Threshold") }
        static var killSwitch: String { zh("Kill Switch", en: "Kill Switch") }
        static var markResolved: String { zh("标记已解决", en: "Mark Resolved") }
        static var confirmMarkResolved: String { zh("确认标记已解决", en: "Confirm Mark Resolved") }
        static var unresolved: String { zh("未解决", en: "Unresolved") }
        static var resolved: String { zh("已解决", en: "Resolved") }
        static var cannotResolveKillSwitch: String { zh("Kill Switch 类型不可手动解决", en: "Kill switch type cannot be manually resolved") }
    }
}
