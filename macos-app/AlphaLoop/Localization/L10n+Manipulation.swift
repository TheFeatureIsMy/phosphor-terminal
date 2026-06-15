// L10n+Manipulation.swift — 操纵雷达文案

extension L10n {
    enum Manipulation {
        // MARK: - Page
        static var radarTitle: String { zh("操纵雷达", en: "Manipulation Radar") }
        static var radarSubtitle: String { zh("市场操纵行为智能识别", en: "AI-Powered Market Manipulation Detection") }

        // MARK: - M1–M8 Types
        static var typeM1: String { zh("资金协同控盘", en: "Coordinated Fund Control") }
        static var typeM2: String { zh("老庄无规律控盘", en: "Market Maker Control") }
        static var typeM3: String { zh("KOL社交拉盘", en: "KOL Social Pump") }
        static var typeM4: String { zh("少数钱包控盘", en: "Whale Wallet Control") }
        static var typeM5: String { zh("跨市场操纵", en: "Cross-Market Manipulation") }
        static var typeM6: String { zh("自成交刷量", en: "Wash Trading") }
        static var typeM7: String { zh("幽灵挂单", en: "Spoofing") }
        static var typeM8: String { zh("流动性猎杀", en: "Liquidity Hunt") }

        // MARK: - Lifecycle Stages
        static var stageSuspected: String { zh("疑似", en: "SUSPECTED") }
        static var stageAccumulate: String { zh("建仓期", en: "ACCUMULATE") }
        static var stageMarkup: String { zh("拉升期", en: "MARKUP") }
        static var stageDistribute: String { zh("派发期", en: "DISTRIBUTE") }
        static var stageCollapse: String { zh("崩盘期", en: "COLLAPSE") }
        static var stageCompleted: String { zh("已结束", en: "COMPLETED") }
        static var stageFalseAlarm: String { zh("误报", en: "FALSE ALARM") }

        // MARK: - Trading Signals
        static var signalAmbush: String { zh("可埋伏", en: "AMBUSH") }
        static var signalRide: String { zh("可上车", en: "RIDE") }
        static var signalExitOrShort: String { zh("减仓/做空", en: "EXIT/SHORT") }
        static var signalAvoid: String { zh("回避", en: "AVOID") }
        static var signalWatch: String { zh("观望", en: "WATCH") }
        static var signalCaution: String { zh("谨慎", en: "CAUTION") }
        static var signalExit: String { zh("离场", en: "EXIT") }

        // MARK: - UI Sections
        static var activeCases: String { zh("活跃案例", en: "ACTIVE CASES") }
        static var caseDetail: String { zh("案例详情", en: "CASE DETAIL") }
        static var alertFeed: String { zh("告警流", en: "ALERT FEED") }
        static var tradingSignal: String { zh("交易建议", en: "TRADING SIGNAL") }
        static var evidence: String { zh("证据", en: "EVIDENCE") }
        static var timeline: String { zh("时间线", en: "TIMELINE") }
        static var historicalScan: String { zh("历史扫描", en: "HISTORICAL SCAN") }
        static var scanSymbol: String { zh("扫描品种", en: "SCAN SYMBOL") }
        static var startScan: String { zh("开始扫描", en: "START SCAN") }
        static var confidence: String { zh("置信度", en: "CONFIDENCE") }
        static var userProfile: String { zh("用户画像", en: "USER PROFILE") }
        static var aggressive: String { zh("激进型", en: "AGGRESSIVE") }
        static var conservative: String { zh("谨慎型", en: "CONSERVATIVE") }
        static var highRisk: String { zh("高危品种", en: "HIGH RISK") }
        static var noCases: String { zh("暂无活跃案例", en: "No active cases") }
        static var byStage: String { zh("按阶段", en: "BY STAGE") }
    }
}
