// L10n+LiveReadiness.swift — 实盘准入控制台文案
// 一屏可判断：5 级总状态 + 11 项指标 + 三重启动确认

extension L10n {
    enum LiveReadiness {

        // MARK: - Page Header
        static var pageHeader: String { zh("实盘准入", en: "LIVE READINESS") }
        static var pageSubtitle: String {
            zh("一屏可判断 · 11 项门禁 + 5 级总状态",
               en: "One-screen judgment · 11 gates + 5-level status")
        }
        static var grandStatus: String { zh("总状态", en: "GRAND STATUS") }

        // MARK: - 5-level status
        static var statusNotLive: String { zh("不可实盘", en: "NOT LIVE") }
        static var statusNeedsConfig: String { zh("待配置", en: "NEEDS CONFIG") }
        static var statusNeedsValidation: String { zh("待验证", en: "NEEDS VALIDATION") }
        static var statusPaperPassed: String { zh("模拟通过", en: "PAPER PASSED") }
        static var statusReadyForLive: String { zh("可进入实盘", en: "READY FOR LIVE") }

        static func grandStatusLabel(_ key: String) -> String {
            switch key {
            case "not_live": return statusNotLive
            case "needs_config": return statusNeedsConfig
            case "needs_validation": return statusNeedsValidation
            case "paper_passed": return statusPaperPassed
            case "ready_for_live": return statusReadyForLive
            default: return key
            }
        }

        static func grandStatusDescription(_ key: String) -> String {
            switch key {
            case "not_live":
                return zh("基础设施或数据源不可用，需修复后才能进入准入流程。",
                         en: "Infrastructure or data source is unavailable. Fix before continuing.")
            case "needs_config":
                return zh("缺少运行模式 / 策略 / 资金 / 风控 / 交易所配置。",
                         en: "Missing mode, strategy, capital, risk, or exchange configuration.")
            case "needs_validation":
                return zh("策略 DSL 验证 / 回测 / 模拟未完成，无法进入实盘。",
                         en: "DSL validation, backtest, or dry-run incomplete. Live trading blocked.")
            case "paper_passed":
                return zh("模拟已通过；可继续小仓实盘试运行。",
                         en: "Paper passed. Live Small is available.")
            case "ready_for_live":
                return zh("全部门禁通过。可启动小仓实盘（需三重确认）。",
                         en: "All gates passed. Live Small available (triple confirmation required).")
            default:
                return ""
            }
        }

        // MARK: - Selection panel
        static var selectTitle: String { zh("运行选择", en: "SELECTION") }
        static var modeLabel: String { zh("运行模式", en: "MODE") }
        static var strategyLabel: String { zh("策略", en: "STRATEGY") }
        static var capitalLabel: String { zh("资金池", en: "CAPITAL POOL") }
        static var exchangeLabel: String { zh("交易所", en: "EXCHANGE") }
        static var modePaper: String { zh("模拟", en: "PAPER") }
        static var modeLiveSmall: String { zh("小仓实盘", en: "LIVE SMALL") }
        static var modeLiveFull: String { zh("全仓实盘", en: "LIVE FULL") }
        static var notSelected: String { zh("未选择", en: "Not selected") }

        // MARK: - 11 gates
        static var gatesTitle: String { zh("11 项门禁", en: "11 GATES") }
        static var groupMode: String { zh("模式", en: "MODE") }
        static var groupStrategy: String { zh("策略", en: "STRATEGY") }
        static var groupCapital: String { zh("资金", en: "CAPITAL") }
        static var groupRisk: String { zh("风控", en: "RISK") }
        static var groupSystem: String { zh("系统", en: "SYSTEM") }
        static var groupExecution: String { zh("执行", en: "EXECUTION") }

        static var checkMode: String { zh("模式选择", en: "MODE") }
        static var checkStrategy: String { zh("策略选择", en: "STRATEGY") }
        static var checkCapital: String { zh("资金配置", en: "CAPITAL") }
        static var checkRiskConfig: String { zh("风控配置", en: "RISK CONFIG") }
        static var checkExchange: String { zh("交易所连接", en: "EXCHANGE") }
        static var checkDataSource: String { zh("数据源健康", en: "DATA SOURCE") }
        static var checkValidation: String { zh("策略验证", en: "VALIDATION") }
        static var checkBacktest: String { zh("回测通过", en: "BACKTEST") }
        static var checkDryrun: String { zh("模拟/dry-run", en: "DRYRUN") }
        static var checkNotification: String { zh("通知可用", en: "NOTIFICATION") }
        static var checkEmergencyStop: String { zh("紧急停止", en: "EMERGENCY STOP") }

        // MARK: - Context summary
        static var contextTitle: String { zh("上下文", en: "CONTEXT") }
        static var notifications: String { zh("通知", en: "NOTIFICATIONS") }
        static var aiModels: String { zh("AI 模型", en: "AI MODELS") }
        static var dataSource: String { zh("数据源", en: "DATA SOURCE") }
        static var exchangeLabelShort: String { zh("交易所", en: "EXCHANGE") }
        static var freqtrade: String { zh("交易引擎", en: "FREQTRADE") }
        static var redis: String { zh("缓存", en: "REDIS") }
        static var dailyLossUsed: String { zh("日损使用", en: "DAILY USED") }
        static var weeklyLossUsed: String { zh("周损使用", en: "WEEKLY USED") }

        // MARK: - Launch authorization
        static var launchTitle: String { zh("启动授权", en: "LAUNCH AUTHORIZATION") }
        static var canStartPaper: String { zh("可启动模拟", en: "CAN START PAPER") }
        static var canStartLiveSmall: String { zh("可启动小仓实盘", en: "CAN START LIVE SMALL") }
        static var canStartFullLive: String { zh("可启动全仓实盘", en: "CAN START FULL LIVE") }
        static var startPaper: String { zh("启动模拟", en: "START PAPER") }
        static var startLiveSmall: String { zh("启动小仓实盘", en: "START LIVE SMALL") }
        static var startFullLive: String { zh("启动全仓实盘", en: "START FULL LIVE") }

        // MARK: - Blockers / warnings
        static var blockersTitle: String { zh("阻断项", en: "BLOCKERS") }
        static var warningsTitle: String { zh("警告", en: "WARNINGS") }
        static var noBlockers: String { zh("无阻断项", en: "NO BLOCKERS") }

        // MARK: - Legacy (kept for backward compat)
        static var readinessScore: String { zh("准入评分", en: "READINESS") }
        static var recheck: String { zh("重新检查", en: "RE-CHECK") }
        static var paper: String { zh("模拟", en: "PAPER") }
        static var small: String { zh("小仓", en: "SMALL") }
        static var full: String { zh("全仓", en: "FULL") }
        static var allClear: String { zh("全部通过", en: "ALL CLEAR") }
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

        // MARK: - Launch confirmation (triple)
        static var confirmTitle: String { zh("实盘启动确认", en: "Live Launch Confirmation") }
        static var confirmStep1: String { zh("第 1 步：阅读启动摘要", en: "Step 1: Review launch summary") }
        static var confirmStep2: String { zh("第 2 步：勾选确认", en: "Step 2: Check acknowledgment") }
        static var confirmStep3: String { zh("第 3 步：输入确认短语", en: "Step 3: Type the confirmation phrase") }
        static var confirmSummary: String { zh("启动摘要", en: "LAUNCH SUMMARY") }
        static var confirmCheckText: String {
            zh("我已理解以下操作将使用真实资金。亏损不可逆。",
               en: "I understand this will use real funds. Losses are irreversible.")
        }
        static var confirmMessage: String {
            zh("此操作将使用真实资金启动自动交易。亏损不可逆。请确保已完成回测和模拟验证。",
               en: "This will start automated trading with real funds. Losses are irreversible. Ensure backtesting and paper trading are complete.")
        }
        static var confirmPhrase: String { zh("I confirm live trading", en: "I confirm live trading") }
        static var confirmPhraseHint: String { zh("请输入:", en: "Please type:") }
        static var cancel: String { zh("取消", en: "CANCEL") }
        static var launch: String { zh("确认启动", en: "LAUNCH") }
        static var launching: String { zh("启动中...", en: "LAUNCHING...") }
        static var launchSuccess: String { zh("实盘已启动", en: "Live trading launched") }

        // MARK: - Infra + risk
        static var systemHealth: String { zh("系统健康", en: "SYSTEM HEALTH") }
        static var riskFirewall: String { zh("风控防火墙", en: "RISK FIREWALL") }
        static var daily: String { zh("日损", en: "DAILY") }
        static var weekly: String { zh("周损", en: "WEEKLY") }
        static var killSwitch: String { zh("熔断开关", en: "KILL SWITCH") }
        static var breaker: String { zh("熔断器", en: "BREAKER") }
        static var off: String { zh("关闭", en: "OFF") }
        static var normal: String { zh("正常", en: "NORMAL") }

        // MARK: - Capital pool
        static var totalBudget: String { zh("总预算", en: "Total Budget") }
        static var stakePerTrade: String { zh("单笔仓位", en: "Stake / Trade") }
        static var maxOpenTrades: String { zh("最大持仓数", en: "Max Open Trades") }
        static var maxDailyLoss: String { zh("最大日损", en: "Max Daily Loss") }
        static var noLeverage: String { zh("禁止杠杆", en: "NO LEVERAGE") }
        static var spotOnly: String { zh("仅限现货", en: "SPOT ONLY") }
        static var humanConfirmRequired: String { zh("需人工确认", en: "HUMAN CONFIRM") }
        static var autoTradeOff: String { zh("自动交易关闭", en: "AUTO OFF") }
        static var maxExposure: String { zh("最大敞口", en: "Max Exposure") }
        static var ofBudget: String { zh("占预算", en: "of budget") }
    }
}
