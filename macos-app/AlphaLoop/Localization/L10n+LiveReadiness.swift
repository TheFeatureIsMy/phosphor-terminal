// L10n+LiveReadiness.swift — 实盘准入页面文案

extension L10n {
    enum LiveReadiness {
        // MARK: - Masthead
        static var readinessScore: String { zh("准入评分", en: "READINESS") }
        static var recheck: String { zh("重新检查", en: "RE-CHECK") }
        static var paper: String { zh("模拟", en: "PAPER") }
        static var small: String { zh("小仓", en: "SMALL") }
        static var full: String { zh("全仓", en: "FULL") }

        // MARK: - States
        static var liveReady: String { zh("实盘就绪", en: "LIVE READY") }
        static var liveSmallReady: String { zh("小仓就绪", en: "LIVE SMALL READY") }
        static var paperOnly: String { zh("仅模拟", en: "PAPER ONLY") }
        static var riskLocked: String { zh("风控锁定", en: "RISK LOCKED") }
        static var emergencyLocked: String { zh("紧急锁定", en: "EMERGENCY LOCKED") }
        static var notReady: String { zh("未就绪", en: "NOT READY") }

        static func stateDescription(_ state: String) -> String {
            switch state.lowercased() {
            case "live_ready":
                return zh("全部检查通过，可启动全仓实盘交易。", en: "All checks passed. Full live trading is available.")
            case "live_small_ready":
                return zh("系统健康，策略通过部分检查。可启动小仓实盘，需完成剩余检查后解锁全仓。",
                          en: "System healthy, strategy partially cleared. Live Small available; complete remaining checks for Full Live.")
            case "paper_only":
                return zh("仅允许模拟交易。需通过更多检查后解锁实盘。",
                          en: "Paper trading only. Pass additional checks to unlock live trading.")
            case "risk_locked":
                return zh("风控系统已锁定交易。请检查风控防火墙状态。",
                          en: "Trading locked by risk system. Check risk firewall status.")
            case "emergency_locked":
                return zh("紧急锁定已激活。所有交易已暂停。",
                          en: "Emergency lock active. All trading halted.")
            default:
                return zh("系统未就绪。请完成基础设施和策略检查。",
                          en: "System not ready. Complete infrastructure and strategy checks.")
            }
        }

        // MARK: - Strategy Gates
        static var strategyGates: String { zh("策略准入门", en: "STRATEGY GATES") }
        static func gateCount(_ passed: Int, _ total: Int) -> String {
            zh("\(passed) / \(total)", en: "\(passed) / \(total)")
        }
        static var go: String { zh("通过", en: "GO") }
        static var noGo: String { zh("未通过", en: "NO-GO") }

        // Gate names
        static var gateVersion: String { zh("版本状态", en: "Version Status") }
        static var gateBacktest: String { zh("回测记录", en: "Backtest Record") }
        static var gateDryrunDuration: String { zh("模拟时长", en: "Dry-Run Duration") }
        static var gateDryrunHealth: String { zh("模拟健康", en: "Dry-Run Health") }
        static var gateNoDuplicate: String { zh("无重复", en: "No Duplicate") }
        static var gateRiskBinding: String { zh("风控绑定", en: "Risk Binding") }
        static var gateHumanConfirm: String { zh("人工确认", en: "Human Confirm") }

        // MARK: - System Health
        static var systemHealth: String { zh("系统健康", en: "SYSTEM HEALTH") }
        static var fastTrack: String { zh("快速通道", en: "Fast Track") }
        static var redis: String { zh("缓存", en: "Redis RTT") }
        static var freqtrade: String { zh("交易引擎", en: "Freqtrade") }
        static var exchangeApi: String { zh("交易所", en: "Exchange API") }
        static var postgresql: String { zh("数据库", en: "PostgreSQL") }
        static var aiCache: String { zh("AI 缓存", en: "AI Cache") }

        // MARK: - Risk Firewall
        static var riskFirewall: String { zh("风控防火墙", en: "RISK FIREWALL") }
        static var daily: String { zh("日损", en: "DAILY") }
        static var weekly: String { zh("周损", en: "WEEKLY") }
        static var consecutive: String { zh("连损", en: "CONSEC") }
        static var killSwitch: String { zh("熔断开关", en: "KILL SWITCH") }
        static var breaker: String { zh("熔断器", en: "BREAKER") }
        static var off: String { zh("关闭", en: "OFF") }
        static var normal: String { zh("正常", en: "NORMAL") }

        // MARK: - Capital Pool
        static var capitalPool: String { zh("资金配置", en: "CAPITAL POOL") }
        static var totalBudget: String { zh("总预算", en: "Total Budget") }
        static var stakePerTrade: String { zh("单笔仓位", en: "Stake / Trade") }
        static var maxOpenTrades: String { zh("最大持仓数", en: "Max Open Trades") }
        static var maxDailyLoss: String { zh("最大日损", en: "Max Daily Loss") }
        static var noLeverage: String { zh("禁止杠杆", en: "NO LEVERAGE") }
        static var spotOnly: String { zh("仅限现货", en: "SPOT ONLY") }
        static var humanConfirmRequired: String { zh("需人工确认", en: "HUMAN CONFIRM") }
        static var autoTradeOff: String { zh("自动交易关闭", en: "AUTO OFF") }

        // MARK: - Launch Sequence
        static var launchSequence: String { zh("启动序列", en: "LAUNCH SEQUENCE") }
        static var paperTrade: String { zh("模拟交易", en: "PAPER TRADE") }
        static var goLive: String { zh("小仓实盘", en: "GO LIVE") }
        static var fullLive: String { zh("全仓实盘", en: "FULL LIVE") }
        static var confirmTitle: String { zh("实盘交易确认", en: "Live Trading Confirmation") }
        static var confirmMessage: String {
            zh("此操作将使用真实资金启动自动交易。亏损不可逆。请确保已完成回测和模拟验证。",
               en: "This will start automated trading with real funds. Losses are irreversible. Ensure backtesting and paper trading are complete.")
        }
        static var confirmPhrase: String { zh("I confirm live trading", en: "I confirm live trading") }
        static var maxExposure: String { zh("最大敞口", en: "Max Exposure") }
        static var ofBudget: String { zh("占预算", en: "of budget") }
    }
}
