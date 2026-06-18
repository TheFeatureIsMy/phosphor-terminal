// L10n+Dashboard.swift — 交易操作总控台文案

extension L10n {
    enum Dashboard {

        // MARK: - Page Header

        static var pageHeader: String { zh("驾驶舱", en: "Cockpit") }
        static var pageSubtitle: String {
            zh("实时驾驶舱 · 所有指标均为后端真实数据",
               en: "Real-time cockpit · Every metric is sourced from the live backend")
        }
        static var dataSourceBadge: String { zh("LIVE", en: "LIVE") }
        static var dataSourceUnavailable: String {
            zh("数据源暂不可用",
               en: "DATA SOURCE UNAVAILABLE")
        }

        // MARK: - Mode Pill

        static var modeTitle: String { zh("运行模式", en: "MODE") }
        static var modeLive: String { zh("实盘 LIVE", en: "LIVE") }
        static var modePaper: String { zh("模拟 PAPER", en: "PAPER") }
        static var modeDryRun: String { zh("演练 DRYRUN", en: "DRYRUN") }
        static var modeStopped: String { zh("已停止 STOPPED", en: "STOPPED") }
        static var modeMock: String { zh("MOCK", en: "MOCK") }
        static var modeNotReady: String { zh("未就绪", en: "NOT READY") }
        static func modeDetail(_ name: String) -> String {
            zh("当前：\(name)", en: "Current: \(name)")
        }

        // MARK: - Status Bar / Strip

        static var systemState: String { zh("系统", en: "SYS") }
        static var freqtrade: String { zh("交易引擎", en: "FREQTRADE") }
        static var redis: String { zh("缓存", en: "REDIS") }
        static var exchange: String { zh("交易所", en: "EXCHANGE") }
        static var providers: String { zh("PROVIDER", en: "PROVIDERS") }
        static var aiModels: String { zh("AI 模型", en: "AI MODELS") }
        static var lastUpdate: String { zh("最近更新", en: "LAST UPDATE") }

        // MARK: - Account Hero

        static var accountOverview: String { zh("账户总览", en: "ACCOUNT OVERVIEW") }
        static var equity: String { zh("账户权益", en: "EQUITY") }
        static var todayPnl: String { zh("今日盈亏", en: "TODAY P&L") }
        static var weekPnl: String { zh("本周盈亏", en: "WEEK P&L") }
        static var totalPnl: String { zh("累计盈亏", en: "TOTAL P&L") }
        static var maxDrawdown: String { zh("最大回撤", en: "MAX DRAWDOWN") }
        static var sharpeRatio: String { zh("夏普比率", en: "SHARPE RATIO") }
        static var winRate: String { zh("胜率", en: "WIN RATE") }
        static var rollingDays: String { zh("30日滚动", en: "30d rolling") }
        static var todaysTrades: String { zh("今日交易", en: "TODAY'S TRADES") }
        static var kpiTitle: String { zh("关键指标", en: "KEY METRICS") }

        // MARK: - Available Actions

        static var suggestedActions: String { zh("建议操作", en: "SUGGESTED ACTIONS") }
        static var actionStartPaper: String { zh("启动模拟", en: "START PAPER") }
        static var actionStartLiveSmall: String { zh("启动小仓实盘", en: "START LIVE SMALL") }
        static var actionStartFullLive: String { zh("启动全量实盘", en: "START FULL LIVE") }
        static var actionEmergencyStop: String { zh("紧急停止", en: "EMERGENCY STOP") }
        static var actionCancelAll: String { zh("取消全部挂单", en: "CANCEL ALL ORDERS") }
        static var actionForceClose: String { zh("强制平仓", en: "FORCE CLOSE") }
        static var actionRunCheck: String { zh("运行就绪检查", en: "RUN READINESS CHECK") }
        static var actionRefresh: String { zh("刷新", en: "REFRESH") }

        // MARK: - Strategy Runtime

        static var strategyRuntime: String { zh("策略运行", en: "STRATEGY RUNTIME") }
        static var running: String { zh("运行中", en: "running") }
        static var positions: String { zh("持仓", en: "positions") }
        static var pending: String { zh("挂单", en: "pending") }
        static var reconciling: String { zh("对账中", en: "reconciling") }

        // MARK: - Live Readiness

        static var liveReadiness: String { zh("实盘准入", en: "LIVE READINESS") }
        static var liveReady: String { zh("实盘就绪", en: "LIVE READY") }
        static var paperOnly: String { zh("仅模拟", en: "PAPER ONLY") }
        static var riskLocked: String { zh("风控锁定", en: "RISK LOCKED") }
        static var notReady: String { zh("未就绪", en: "NOT READY") }
        static var liveReadinessChecks: String { zh("准入检查项", en: "READINESS CHECKS") }
        static func gatesPassed(_ n: Int) -> String {
            zh("全部 \(n) 项检查通过", en: "All \(n) gates passed")
        }
        static var readinessNoData: String {
            zh("暂未拉到 readiness 数据",
               en: "No readiness data available")
        }

        // MARK: - Global Risk

        static var globalRiskState: String { zh("全局风控", en: "GLOBAL RISK STATE") }
        static var dailyLoss: String { zh("日损余额", en: "DAILY") }
        static var weeklyLoss: String { zh("周损余额", en: "WEEKLY") }
        static var normal: String { zh("正常", en: "NORMAL") }
        static var warning: String { zh("警告", en: "WARNING") }
        static var blocked: String { zh("阻断", en: "BLOCKED") }
        static var locked: String { zh("锁定", en: "LOCKED") }
        static var emergencyLocked: String { zh("紧急锁定", en: "EMERGENCY LOCKED") }

        // MARK: - Position Risk

        static var positionRisk: String { zh("持仓风险", en: "POSITION RISK") }
        static func openCount(_ n: Int) -> String {
            zh("\(n) 个持仓", en: "\(n) OPEN")
        }
        static var symbol: String { zh("品种", en: "SYMBOL") }
        static var direction: String { zh("方向", en: "DIRECTION") }
        static var size: String { zh("数量", en: "SIZE") }
        static var entry: String { zh("开仓价", en: "ENTRY") }
        static var mark: String { zh("现价", en: "MARK") }
        static var pnl: String { zh("盈亏", en: "P&L") }
        static var pnlPct: String { zh("盈亏%", en: "P&L %") }
        static var risk: String { zh("风险", en: "RISK") }
        static var reason: String { zh("原因", en: "REASON") }
        static var long: String { zh("做多", en: "LONG") }
        static var short: String { zh("做空", en: "SHORT") }
        static var riskLow: String { zh("低", en: "LOW") }
        static var riskMed: String { zh("中", en: "MED") }
        static var riskHigh: String { zh("高", en: "HIGH") }
        static var noPositions: String { zh("无持仓", en: "No open positions") }
        static var stateInSync: String { zh("本端/交易所同步", en: "IN SYNC") }
        static var stateDrift: String { zh("存在差异", en: "DRIFT") }
        static var stateLocalOnly: String { zh("仅本端", en: "LOCAL ONLY") }
        static var stateExchangeOnly: String { zh("仅交易所", en: "EXCHANGE ONLY") }
        static var stateUnknown: String { zh("状态未知", en: "STATE UNKNOWN") }

        // MARK: - Provider Health

        static var providerHealth: String { zh("PROVIDER 健康", en: "PROVIDER HEALTH") }
        static func providerSummary(_ total: Int, _ healthy: Int, _ warning: Int, _ error: Int) -> String {
            zh("共 \(total) 个 · 正常 \(healthy) · 警告 \(warning) · 异常 \(error)",
               en: "\(total) total · \(healthy) healthy · \(warning) warn · \(error) error")
        }
        static var providerStatusOk: String { zh("正常", en: "OK") }
        static var providerStatusWarn: String { zh("警告", en: "WARN") }
        static var providerStatusError: String { zh("异常", en: "ERROR") }
        static var providerNoData: String {
            zh("未配置 provider",
               en: "No providers configured")
        }
        static func providerCategory(_ name: String) -> String { name }

        // MARK: - AI Models

        static var aiModelStatus: String { zh("AI 模型", en: "AI MODELS") }
        static var aiModelsLoaded: String { zh("已加载", en: "LOADED") }
        static var aiModelsNotLoaded: String { zh("未加载", en: "NOT LOADED") }
        static var aiModelsMissing: String { zh("未配置", en: "MISSING") }
        static var aiModelsNoData: String {
            zh("未拉取 AI 模型状态",
               en: "No AI model status available")
        }

        // MARK: - Recent Decisions / Signals

        static var recentDecisions: String { zh("近期决策", en: "RECENT DECISIONS") }
        static var signalsFeed: String { zh("最新信号 (含溯源)", en: "SIGNAL FEED (WITH SOURCE)") }
        static var signalSourceAgent: String { zh("来源 Agent", en: "AGENT") }
        static var signalSourceStrategy: String { zh("关联策略", en: "STRATEGY") }
        static var signalSourceSnapshot: String { zh("特征快照", en: "SNAPSHOT") }
        static var sourceNotTraced: String { zh("未关联溯源", en: "NO TRACE") }
        static var noSignals: String {
            zh("暂无最新信号",
               en: "No recent signals")
        }

        // MARK: - Alert Timeline

        static var alertTimeline: String { zh("告警时间线", en: "ALERT TIMELINE") }
        static var noAlerts: String {
            zh("暂无告警",
               en: "No alerts")
        }

        // MARK: - Emergency

        static var emergencyControl: String { zh("紧急控制", en: "EMERGENCY CONTROL") }
        static var haltAllTrading: String { zh("停止全部交易", en: "HALT ALL TRADING") }
        static var haltDescription: String {
            zh("停止所有策略 · 取消挂单 · 保留持仓",
               en: "Stops all strategies · Cancels pending orders · Preserves positions")
        }
        static var confirmHaltTitle: String { zh("确认停止交易", en: "Confirm Halt Trading") }
        static var confirmHaltMessage: String {
            zh("此操作将立即停止所有自动交易策略并取消所有挂单。需要手动恢复。",
               en: "This will immediately stop all automated trading strategies and cancel all pending orders. Manual restart required.")
        }

        // MARK: - Misc

        static var dashboardTitle: String { zh("总览", en: "Dashboard") }
        static var waitingForData: String { zh("等待数据...", en: "Waiting for data...") }
        static var collapsePanel: String { zh("收起面板", en: "COLLAPSE") }
        static var expandPanel: String { zh("展开面板", en: "EXPAND") }

        // MARK: - Kept for EquityCurveChart

        static var equityCurve: String { zh("权益曲线", en: "Equity Curve") }
    }
}
