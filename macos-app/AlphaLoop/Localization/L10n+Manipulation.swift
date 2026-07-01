// L10n+Manipulation.swift — 操纵雷达文案

extension L10n {
    enum Manipulation {
        // MARK: - Page
        static var radarTitle: String { zh("操纵雷达", en: "Manipulation Radar") }
        static var radarSubtitle: String { zh("市场操纵行为智能识别", en: "AI-Powered Market Manipulation Detection") }
        static var disclaimer: String { zh("本页面所有信号均为统计推断，不构成投资建议。", en: "All signals on this page are statistical inferences and do not constitute investment advice.") }

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

        // MARK: - Narrative Sections (§0–§8)
        static var verdict: String { zh("判定结果", en: "VERDICT") }
        static var lifecycleTimeline: String { zh("生命周期", en: "LIFECYCLE TIMELINE") }
        static var evidenceMatrix: String { zh("证据层矩阵", en: "EVIDENCE LAYER MATRIX") }
        static var whaleConcentration: String { zh("巨鲸与筹码集中", en: "WHALE CONCENTRATION") }
        static var crossMarketPressure: String { zh("跨市场压力", en: "CROSS-MARKET PRESSURE") }
        static var socialAcceleration: String { zh("社交加速", en: "SOCIAL ACCELERATION") }
        static var defenseStrategyImpact: String { zh("防御策略影响", en: "DEFENSE & STRATEGY IMPACT") }
        static var similarHistoricalCases: String { zh("相似历史案例", en: "SIMILAR HISTORICAL CASES") }

        // MARK: - Verdict Panel
        static var likely: String { zh("疑似", en: "Likely") }
        static var evidenceConsistentWith: String { zh("证据符合", en: "Evidence consistent with") }
        static var dataQuality: String { zh("数据完整度", en: "Data quality") }
        static var dataCompleteness: String { zh("数据完整度", en: "Data completeness") }
        static var maxConfidence: String { zh("最大置信度", en: "Max confidence") }
        static var dataUnavailable: String { zh("数据不可用", en: "Data unavailable") }

        // MARK: - Evidence Layers
        static var layerPrice: String { zh("量价", en: "Price Volume") }
        static var layerOrderbook: String { zh("订单簿", en: "Orderbook") }
        static var layerOnchain: String { zh("链上", en: "Onchain") }
        static var layerSocial: String { zh("社交/新闻", en: "Social/News") }
        static var layerCrossMarket: String { zh("跨市场", en: "Cross-Market") }

        // MARK: - Whale / Cross-Market / Social Features
        static var featTop10Concentration: String { zh("前10集中度", en: "Top 10 concentration") }
        static var featExchangeInflow: String { zh("交易所净流入", en: "Exchange net inflow") }
        static var featFundingRate: String { zh("资金费率 Z 值", en: "Funding rate Z-score") }
        static var featOpenInterest: String { zh("持仓量变化", en: "Open interest change") }
        static var featLongShortRatio: String { zh("多空比", en: "Long/Short ratio") }
        static var featBasis: String { zh("基差", en: "Basis") }

        // MARK: - Strategy Impact
        static var affectedSymbols: String { zh("影响交易对", en: "AFFECTED SYMBOLS") }
        static var strategyImpact: String { zh("策略联动", en: "STRATEGY IMPACT") }
        static var openStrategyRisk: String { zh("打开策略风控", en: "Open Strategy Risk") }
        static var wouldBlock: String { zh("将被阻断", en: "Would block") }
        static var filterDisabled: String { zh("过滤器已关闭", en: "Filter disabled") }

        // MARK: - Masthead
        static var mastheadTitle: String { zh("操纵雷达", en: "MANIPULATION RADAR") }
        static var mastheadSubtitle: String { zh("统计推断", en: "STATISTICAL INFERENCE") }
        static var loadFailed: String { zh("加载失败", en: "Load Failed") }
        static var retry: String { zh("重试", en: "Retry") }

        // MARK: - Alert Type Badges
        static var alertStageChange: String { zh("阶段变更", en: "STAGE") }
        static var alertNewCase: String { zh("新案例", en: "NEW") }
        static var alertConfidenceSpike: String { zh("置信飙升", en: "SPIKE") }
        static var alertSignalChange: String { zh("信号变更", en: "SIGNAL") }

        // MARK: - Lifecycle Abbreviations
        static var abbrSuspected: String { zh("疑似", en: "SUS") }
        static var abbrAccumulate: String { zh("建仓", en: "ACC") }
        static var abbrMarkup: String { zh("拉升", en: "MKP") }
        static var abbrDistribute: String { zh("派发", en: "DST") }
        static var abbrCollapse: String { zh("崩盘", en: "COL") }

        // MARK: - Social Features
        static var featMentionVelocity: String { zh("提及增速", en: "Mention velocity") }
        static var featSentimentExtremity: String { zh("情绪极端度", en: "Sentiment extremity") }

        // MARK: - Action Labels
        static var edit: String { zh("编辑", en: "Edit") }
    }
}
