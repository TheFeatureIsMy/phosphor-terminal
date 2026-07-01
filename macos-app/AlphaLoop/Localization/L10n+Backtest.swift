// L10n+Backtest.swift — 回测实验室文案

extension L10n {
    enum BacktestLab {
        // Tab bar
        static var backtestTab: String { zh("回测", en: "Backtest") }
        static var dryrunTab: String { zh("模拟", en: "Dryrun") }

        enum RunRail {
            static var newRun: String { zh("新建运行", en: "New Run") }
            static var stop: String { zh("停止", en: "Stop") }
        }

        // ConfigPanel fields
        static var fieldVersion: String { zh("策略版本", en: "Version") }
        static var fieldStart: String { zh("开始日期", en: "Start") }
        static var fieldEnd: String { zh("结束日期", en: "End") }
        static var fieldCapital: String { zh("初始资金", en: "Capital") }
        static var fieldSymbols: String { zh("交易标的", en: "Symbols") }
        static var fieldTimeframe: String { zh("时间周期", en: "Timeframe") }
        static var fieldFee: String { zh("手续费模型", en: "Fee Model") }
        static var fieldSlippage: String { zh("滑点模型", en: "Slippage") }
        static var fieldSlippageNone: String { zh("无", en: "None") }

        // Run sheet (ConfigPanel)
        static var sheetMaxOpen: String { zh("最大持仓", en: "Max Open") }
        static var sheetWallet: String { zh("初始钱包", en: "Wallet") }
        static var sheetSubmit: String { zh("发起", en: "Start") }

        // Phase / unlock hints
        static var phaseRunning: String { zh("运行中…", en: "Running…") }

        // Section titles
        static var sectionConfig: String { zh("运行参数", en: "Run Parameters") }
        static var sectionSummary: String { zh("收益摘要", en: "Return Summary") }
        static var sectionCurve: String { zh("权益曲线", en: "Equity Curve") }
        static var sectionTradeList: String { zh("交易列表", en: "Trade List") }
        static var sectionCompare: String { zh("历史对比", en: "Historical Compare") }

        // Status (StatusSummaryBlock)
        static var statusFailed: String { zh("失败", en: "Failed") }
        static var statusCompleted: String { zh("已完成", en: "Completed") }

        // KPI labels
        static var kpiReturn: String { zh("收益", en: "Return") }
        static var kpiMaxDD: String { zh("最大回撤", en: "Max DD") }
        static var kpiWinRate: String { zh("胜率", en: "Win Rate") }
        static var kpiProfitFactor: String { zh("盈亏比", en: "PF") }

        // Trade list
        static var colEntry: String { zh("入场价", en: "Entry") }
        static var colPair: String { zh("交易对", en: "Pair") }
        static var colSide: String { zh("方向", en: "Side") }
        static var colExit: String { zh("出场价", en: "Exit") }
        static var colPnl: String { zh("盈亏", en: "P&L") }
        static var colDuration: String { zh("持仓时长", en: "Duration") }
        static var tradesEmpty: String { zh("本次运行无成交", en: "No trades in this run") }
        static var runClusterTitle: String { zh("本次 run 失败聚类", en: "In-run Failure Clusters") }

        // Equity curve
        static var curveEmpty: String { zh("本次运行未导出 equity curve 数据", en: "No equity curve exported for this run") }

        // Run-level errors
        static var timeoutError: String { zh("运行超时", en: "Run timed out") }
        static var runFailed: String { zh("运行失败", en: "Run failed") }

        // Risk warning messages
        static var warnMaxDrawdown: String { zh("最大回撤超过 25%，风险过高", en: "Max drawdown exceeds 25%, too risky") }
        static var warnProfitFactor: String { zh("盈亏比 < 1，策略负期望", en: "Profit factor < 1, negative expectancy") }
        static var warnLowTrades: String { zh("样本不足，统计意义有限", en: "Sample too small, limited statistical significance") }
        static var warnLowWinrate: String { zh("胜率偏低", en: "Win rate low") }
        static var warnNegativeSharpe: String { zh("夏普为负，风险调整收益为负", en: "Negative Sharpe, risk-adjusted return negative") }

        // MARK: - Top bar
        static var runSwitcherTitle: String { zh("运行 #%d · %@ · %@", en: "Run #%d · %@ · %@") }
        static var compare: String { zh("对比", en: "Compare") }

        // MARK: - Metrics
        static var metricTotalReturn: String { zh("总收益", en: "Total Return") }
        static var metricMaxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var metricSharpe: String { zh("夏普", en: "Sharpe") }
        static var metricWinRate: String { zh("胜率", en: "Win Rate") }
        static var metricProfitLossRatio: String { zh("盈亏比", en: "Profit/Loss") }
        static var metricTradeCount: String { zh("交易数", en: "Trades") }
        static var metricProfitFactor: String { zh("利润因子", en: "Profit Factor") }
        static var metricDuration: String { zh("运行时长", en: "Duration") }

        // MARK: - Strategy context + trade list
        static func strategyContextCollapsed(_ name: String, _ warningCount: Int, _ gate: String) -> String {
            zh("\(name) · \(warningCount) 条风险警告 · 晋升门: \(gate)", en: "\(name) · \(warningCount) warnings · gate: \(gate)")
        }
        static func showAllTrades(_ count: Int) -> String { zh("显示全部 \(count) 笔", en: "Show all \(count) trades") }
        static var noTrades: String { zh("无成交记录", en: "No trades") }

        // MARK: - Drawers
        static var newRunDrawerTitle: String { zh("新建运行", en: "New Run") }
        static var historyDrawerTitle: String { zh("历史记录", en: "History") }

        // MARK: - Right Context Rail
        enum Context {
            static var strategyMeta: String { zh("策略信息", en: "Strategy") }
            static var strategy: String { zh("策略", en: "Strategy") }
            static var strategyType: String { zh("类型", en: "Type") }
            static var dslHash: String { zh("DSL 哈希", en: "DSL Hash") }
            static var mode: String { zh("模式", en: "Mode") }
            static var engine: String { zh("引擎", en: "Engine") }
            static var execTime: String { zh("完成时间", en: "Completed") }
            static var risk: String { zh("风险警告", en: "Risk Warnings") }
            static var noRisk: String { zh("未触发风险阈值", en: "No risk thresholds triggered") }
            static var smallSample: String { zh("样本不足，结论谨慎", en: "Small sample, treat cautiously") }
            static var strategyClusters: String { zh("策略级失败聚类", en: "Strategy-level Clusters") }
            static var promotion: String { zh("晋级实盘", en: "Live Promotion") }
            static var ready: String { zh("已就绪", en: "Ready") }
            static var notReady: String { zh("未就绪", en: "Not Ready") }
            static var goLive: String { zh("前往实盘准备", en: "Go to Live Readiness") }
            static var noReadiness: String { zh("无就绪数据", en: "No readiness data") }
        }
    }
}
