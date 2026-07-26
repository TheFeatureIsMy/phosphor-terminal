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
        static var newEntriesControl: String { zh("新开仓控制", en: "NEW ENTRIES CONTROL") }
        static var confirmBlockMessage: String { zh("将阻止所有新订单开仓。当前已有 %d 个活动锁定。确认继续？", en: "This will prevent all new orders from being opened. %d active lock(s) present. Confirm?") }
        static var confirmUnblockMessage: String { zh("将解除禁止新开仓状态，恢复正常交易操作。确认继续？", en: "This will unblock new entries and resume normal trading operations. Confirm?") }
        static var stopProtection: String { zh("止损保护", en: "STOP PROTECTION") }
        static var killSwitchActive: String { zh("已激活", en: "Active") }
        static var killSwitchInactive: String { zh("未激活", en: "Inactive") }
        static var refreshAll: String { zh("刷新全部", en: "Refresh All") }
        static var goToExecutionForResume: String { zh("请前往执行中心恢复指定策略运行", en: "Go to Execution Center to resume the specified strategy") }
        static var cbFilterAll: String { zh("全部", en: "All") }
        static var cbFilterEmergency: String { zh("紧急停止", en: "Emergency") }
        static var cbFilterKillSwitch: String { zh("Kill Switch", en: "Kill Switch") }
        static var cbFilterLossLock: String { zh("亏损锁", en: "Loss Lock") }
        static var cbFilterManualClose: String { zh("手动平仓", en: "Manual") }
        static var cbFilterSafeMode: String { zh("安全模式", en: "Safe Mode") }
        static var cbFilterAllClear: String { zh("全部清除", en: "ALL CLEAR") }
        static var cbLoadFailed: String { zh("加载失败", en: "Load Failed") }
        static var cbNoData: String { zh("暂无熔断数据", en: "No Breaker Data") }
        static var cbNoRecordsYet: String { zh("系统未触发过熔断，运行正常", en: "No circuit breakers triggered — system running normally") }
        static var cbNoRecordsForFilter: String { zh("当前筛选条件下无熔断记录", en: "No circuit breaker records for this filter") }
        static var cbConfirmResolveMessage: String { zh("确认将此熔断事件标记为已解决？", en: "Mark this circuit breaker event as resolved?") }
        static var cbRefresh: String { zh("刷新", en: "Refresh") }

        // MARK: - Protocol 风控中心布局(risk-03 稿)
        static var protoEyebrow: String { zh("Risk Center · 风控中心", en: "Risk Center") }
        static var protoTitle: String { zh("所有交易意图的最后一道门", en: "The final gate for every trade intent") }
        static var protoSubtitle: String { zh("水位监控、守卫网格、拦截事件与门禁规则，构成 RiskEngine 强制门禁体系。", en: "Water-level monitoring, guard grid, blocked intents and gate rules form the RiskEngine enforcement system.") }

        // Water hero
        static var waterBadge: String { zh("全局风险水位 · GLOBAL RISK", en: "Global Risk") }
        static var waterLabel: String { zh("风险敞口", en: "Exposure") }
        static var waterSafe: String { zh("安全", en: "Safe") }
        static var waterWatch: String { zh("关注", en: "Watch") }
        static var waterWarn: String { zh("警戒", en: "Alert") }
        static var waterTrigger: String { zh("触发", en: "Trigger") }
        static var waterDrawdown: String { zh("组合回撤", en: "Drawdown") }
        static var waterMargin: String { zh("保证金率", en: "Margin") }
        static var waterToBreaker: String { zh("距熔断", en: "To breaker") }
        static var waterBlocked: String { zh("今日拦截", en: "Blocked today") }

        // Guards grid
        static var guardsTitle: String { zh("风控守卫", en: "Risk Guards") }
        static var guardsDim: String { zh("维度", en: "dims") }
        static var guardHealthy: String { zh("正常", en: "OK") }
        static var guardWarning: String { zh("警戒", en: "Alert") }
        static var guardCritical: String { zh("临界", en: "Critical") }
        static var guardBreached: String { zh("触发", en: "Breached") }

        // Blocked intents
        static var blockedTitle: String { zh("风控拦截事件流", en: "Blocked Intents") }
        static var blockedNone: String { zh("当前无拦截事件", en: "No blocked intents") }
        static var blockedRejected: String { zh("已拒绝", en: "Rejected") }

        // Gate rules
        static var gateRulesTitle: String { zh("门禁规则", en: "Gate Rules") }
        static var gateRulesReadOnly: String { zh("只读", en: "Read-only") }
        static var gateRulesActive: String { zh("生效", en: "Active") }
    }
}
