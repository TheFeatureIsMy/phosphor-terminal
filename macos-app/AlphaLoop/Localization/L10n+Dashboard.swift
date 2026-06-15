// L10n+Dashboard.swift — 交易操作总控台文案

extension L10n {
    enum Dashboard {

        // MARK: - Status Bar

        static var systemState: String { zh("系统", en: "SYS") }
        static var freqtrade: String { zh("交易引擎", en: "FREQTRADE") }
        static var redis: String { zh("缓存", en: "REDIS") }
        static var exchange: String { zh("交易所", en: "EXCHANGE") }

        // MARK: - Account Hero

        static var accountOverview: String { zh("账户总览", en: "ACCOUNT OVERVIEW") }
        static var todayPnl: String { zh("今日盈亏", en: "TODAY P&L") }
        static var weekPnl: String { zh("本周盈亏", en: "WEEK P&L") }
        static var maxDrawdown: String { zh("最大回撤", en: "MAX DRAWDOWN") }
        static var sharpeRatio: String { zh("夏普比率", en: "SHARPE RATIO") }
        static var rollingDays: String { zh("30日滚动", en: "30d rolling") }

        // MARK: - Available Actions

        static var suggestedActions: String { zh("建议操作", en: "SUGGESTED ACTIONS") }

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
        static func gatesPassed(_ n: Int) -> String {
            zh("全部 \(n) 项检查通过", en: "All \(n) gates passed")
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

        // MARK: - Recent Decisions

        static var recentDecisions: String { zh("近期决策", en: "RECENT DECISIONS") }

        // MARK: - Alert Timeline

        static var alertTimeline: String { zh("告警时间线", en: "ALERT TIMELINE") }

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

        // MARK: - Legacy (remove when DashboardView.swift is rewritten)

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
        static var aiMarketJudgment: String { zh("今日 AI 市场判断", en: "AI Market Assessment") }
        static var confidence: String { zh("置信度", en: "Confidence") }
        static var bullish: String { zh("看多", en: "Bullish") }
        static var bearish: String { zh("看空", en: "Bearish") }
        static var sideways: String { zh("震荡", en: "Sideways") }
        static var riskCritical: String { zh("极高风险", en: "Critical Risk") }
        static var riskMedium: String { zh("中风险", en: "Medium Risk") }
        static var positionsAndRisk: String { zh("当前持仓 + 风险状态", en: "Positions & Risk Status") }
        static func positionCount(_ n: Int) -> String { zh("\(n) 个持仓", en: "\(n) Position\(n == 1 ? "" : "s")") }
        static var noActivePositions: String { zh("无活跃持仓", en: "No Active Positions") }
        static var aiSuggestion: String { zh("AI 建议", en: "AI Advice") }
        static var hold: String { zh("持有", en: "Hold") }
        static var reduce: String { zh("减仓", en: "Reduce") }
        static var takeProfit: String { zh("止盈", en: "Take Profit") }
        static var closePosition: String { zh("平仓", en: "Close") }
        static var riskLevelLow: String { zh("低", en: "Low") }
        static var riskLevelMedium: String { zh("中", en: "Med") }
        static var riskLevelHigh: String { zh("高", en: "High") }
        static var pendingConfirmations: String { zh("需人工确认事项", en: "Pending Confirmations") }
        static var noPendingItems: String { zh("无待处理事项", en: "No Pending Items") }
        static var reject: String { zh("拒绝", en: "Reject") }
        static var approve: String { zh("批准", en: "Approve") }
        static var agentSignalDist: String { zh("Agent 信号分布", en: "Agent Signal Distribution") }
        static var noSignalData: String { zh("暂无信号数据", en: "No Signal Data") }
        static var strategyOverview: String { zh("策略状态总览", en: "Strategy Overview") }
        static var draft: String { zh("草稿", en: "Draft") }
        static var dryRun: String { zh("模拟盘", en: "Paper") }
        static var paused: String { zh("已暂停", en: "Paused") }
        static var riskInterception: String { zh("风险拦截统计", en: "Risk Interception Stats") }
        static var rejected: String { zh("已拒绝", en: "Rejected") }
        static var reduced: String { zh("已减仓", en: "Reduced") }
        static var allowed: String { zh("已放行", en: "Allowed") }
        static var moreAnalysis: String { zh("更多分析", en: "More Analytics") }
        static var equityCurve: String { zh("权益曲线", en: "Equity Curve") }
        static var aiControlTower: String { zh("AI 总控台", en: "AI Control Tower") }
    }
}
