// L10n+Backtest.swift — 回测实验室文案

extension L10n {
    enum BacktestLab {
        // Header
        static var title: String         { zh("回测实验室", en: "Backtest Lab") }
        static var subtitle: String      { zh("多 run 对比 · 推进准入", en: "Multi-run compare · Promotion gate") }
        static var newRun: String        { zh("新建 Run", en: "New Run") }
        static var strategyPicker: String { zh("选择策略", en: "Strategy") }
        static var noStrategy: String    { zh("先在工作台选定一个策略", en: "Pick a strategy in the workspace first") }

        // Run rail
        static var runRail: String       { zh("RUN 列表", en: "RUN LIST") }
        static var runEmpty: String      { zh("尚无回测记录", en: "No backtest runs yet") }
        static var runEmptyHint: String  { zh("点右上「新建 Run」开始", en: "Tap “New Run” to start") }
        static var compareHint: String   { zh("最多对比 3 个 run", en: "Up to 3 runs compared") }
        static var championBadge: String { zh("冠军", en: "CHAMP") }
        static var dryrunSection: String { zh("模拟运行", en: "DRY-RUNS") }
        static var runStatusRunning: String   { zh("运行中", en: "Running") }
        static var runStatusCompleted: String { zh("完成", en: "Done") }
        static var runStatusFailed: String    { zh("失败", en: "Failed") }

        // Comparison workbench
        static var compareMatrix: String { zh("KPI 对比矩阵", en: "KPI Matrix") }
        static var equityOverlay: String { zh("权益叠加", en: "Equity Overlay") }
        static var pickRunHint: String   { zh("在左侧勾选 run 开始对比", en: "Select runs on the left to compare") }
        static var champion: String      { zh("冠军推荐", en: "Champion") }
        static var championReason: String { zh("Sharpe 最高 · 回撤受控", en: "Highest Sharpe · drawdown contained") }
        static var promoteToPaper: String { zh("推进至模拟盘", en: "Promote to Paper") }

        // KPI labels
        static var kpiReturn: String     { zh("收益", en: "Return") }
        static var kpiSharpe: String     { zh("Sharpe", en: "Sharpe") }
        static var kpiMaxDD: String      { zh("最大回撤", en: "Max DD") }
        static var kpiWinRate: String    { zh("胜率", en: "Win Rate") }
        static var kpiTrades: String     { zh("交易数", en: "Trades") }
        static var kpiProfitFactor: String { zh("盈亏比", en: "PF") }

        // Inspector
        static var inspector: String     { zh("RUN 详情", en: "RUN DETAILS") }
        static var inspectorEmpty: String { zh("选中一个 run 查看详情", en: "Select a run to inspect") }
        static var configSnapshot: String { zh("配置快照", en: "Config") }
        static var equitySpark: String   { zh("权益曲线", en: "Equity") }
        static var recentTrades: String  { zh("最近交易", en: "Recent Trades") }
        static var noTrades: String      { zh("无交易明细", en: "No trades") }
        static var promotionGate: String { zh("推进准入", en: "Promotion Gate") }
        static var openMtfGuard: String  { zh("HTF Tribunal", en: "HTF Tribunal") }
        static var openLiveReadiness: String { zh("实盘准入检查", en: "Live Readiness") }

        // Run table columns
        static var colTime: String       { zh("时间", en: "Time") }
        static var colSide: String       { zh("方向", en: "Side") }
        static var colPrice: String      { zh("价格", en: "Price") }
        static var colQty: String        { zh("数量", en: "Qty") }
        static var colPnl: String        { zh("盈亏", en: "P&L") }

        // New run sheet
        static var sheetTitle: String    { zh("新建回测 Run", en: "Configure Backtest Run") }
        static var fieldVersion: String  { zh("策略版本", en: "Version") }
        static var fieldStart: String    { zh("开始日期", en: "Start") }
        static var fieldEnd: String      { zh("结束日期", en: "End") }
        static var fieldCapital: String  { zh("初始资金", en: "Capital") }
        static var fieldSymbols: String  { zh("交易标的", en: "Symbols") }
        static var hintSymbols: String   { zh("逗号分隔，如 BTC/USDT, ETH/USDT", en: "Comma-separated, e.g. BTC/USDT, ETH/USDT") }
        static var submit: String        { zh("启动", en: "Launch") }
        static var cancel: String        { zh("取消", en: "Cancel") }
        static var submitting: String    { zh("提交中…", en: "Submitting…") }
        static var submitFailed: String  { zh("提交失败", en: "Submit failed") }

        // MARK: - Phase / unlock hints
        static var phaseIdle: String { zh("请选择策略", en: "Select a strategy") }
        static var phaseConfiguring: String { zh("配置并运行回测", en: "Configure and run backtest") }
        static var phaseRunning: String { zh("运行中…", en: "Running…") }
        static var phaseWaitingComplete: String { zh("等待运行完成", en: "Waiting for run to complete") }

        // MARK: - Section titles
        static var sectionConfig: String { zh("运行参数", en: "Run Parameters") }
        static var sectionStatus: String { zh("运行状态", en: "Run Status") }
        static var sectionSummary: String { zh("收益摘要", en: "Return Summary") }
        static var sectionCurve: String { zh("权益曲线", en: "Equity Curve") }
        static var sectionTradeList: String { zh("交易列表", en: "Trade List") }
        static var sectionCompare: String { zh("历史对比", en: "Historical Compare") }
        static var sectionRisk: String { zh("风险诊断", en: "Risk Diagnostics") }
        static var sectionPromotion: String { zh("晋级实盘", en: "Promotion to Live") }
        static var sectionDataSource: String { zh("数据源", en: "Data Source") }

        // MARK: - ConfigPanel fields
        static var fieldTimeframe: String { zh("时间周期", en: "Timeframe") }
        static var fieldDateRange: String { zh("日期区间", en: "Date Range") }
        static var fieldFee: String { zh("手续费模型", en: "Fee Model") }
        static var fieldSlippage: String { zh("滑点模型", en: "Slippage") }
        static var fieldSlippageNone: String { zh("无", en: "None") }
        static var fieldSlippageBps: String { zh("固定 bps", en: "Fixed bps") }
        static var fieldSlippagePct: String { zh("百分比", en: "Percentage") }
        static var feeExchangeDefault: String { zh("交易所默认 (0.05%)", en: "Exchange default (0.05%)") }
        static var feeCustom: String { zh("自定义", en: "Custom") }

        // MARK: - StatusPanel
        static var statusBacktestCard: String { zh("回测", en: "Backtest") }
        static var statusDryrunCard: String { zh("模拟 (dry_run)", en: "Simulation (dry_run)") }
        static var statusPending: String { zh("待发起", en: "Idle") }
        static var statusRunning: String { zh("运行中", en: "Running") }
        static var statusCompleted: String { zh("已完成", en: "Completed") }
        static var statusFailed: String { zh("失败", en: "Failed") }
        static var statusNoRun: String { zh("尚无运行记录", en: "No runs yet") }
        static var statusViewLog: String { zh("查看日志", en: "View Log") }
        static var statusTimeout: String { zh("运行超时", en: "Run timed out") }
        static var timeoutError: String   { zh("运行超时", en: "Run timed out") }
        static var runFailed: String      { zh("运行失败", en: "Run failed") }

        // MARK: - SummaryPanel
        static var metricReturn: String { zh("收益", en: "Return") }
        static var metricMaxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var metricWinRate: String { zh("胜率", en: "Win Rate") }
        static var metricProfitFactor: String { zh("盈亏比", en: "Profit Factor") }
        static var metricVsLast: String { zh("vs 上次", en: "vs last") }

        // MARK: - CurvePanel
        static var curveEquity: String { zh("权益", en: "Equity") }
        static var curveDrawdown: String { zh("回撤", en: "Drawdown") }
        static var curveEmpty: String { zh("本次运行未导出 equity curve 数据", en: "No equity curve exported for this run") }

        // MARK: - TradeListPanel
        static var colPair: String { zh("交易对", en: "Pair") }
        static var colEntry: String { zh("入场价", en: "Entry") }
        static var colExit: String { zh("出场价", en: "Exit") }
        static var colDuration: String { zh("持仓时长", en: "Duration") }
        static var colMtf: String { zh("MTF 状态", en: "MTF State") }
        static var tradesEmpty: String { zh("本次运行无成交", en: "No trades in this run") }
        static var runClusterTitle: String { zh("本次 run 失败聚类", en: "In-run Failure Clusters") }
        static var runClusterTooFew: String { zh("亏损样本不足，无法聚类", en: "Too few losses to cluster") }

        // MARK: - ComparePanel
        static var compareEmpty: String { zh("在 Run Rail 勾选 run 启用对比", en: "Select runs in the rail to compare") }
        static var compareBest: String { zh("最佳", en: "Best") }

        // MARK: - RiskPanel
        static var strategyClusterTitle: String { zh("策略级失败聚类", en: "Strategy-level Failure Clusters") }
        static var strategyClusterEmpty: String { zh("暂无策略级失败聚类记录", en: "No strategy-level clusters") }
        static var generateShadow: String { zh("生成 shadow strategy", en: "Generate shadow strategy") }
        static var warnMaxDrawdown: String { zh("最大回撤超过 25%，风险过高", en: "Max drawdown exceeds 25%, too risky") }
        static var warnProfitFactor: String { zh("盈亏比 < 1，策略负期望", en: "Profit factor < 1, negative expectancy") }
        static var warnLowTrades: String { zh("样本不足，统计意义有限", en: "Sample too small, limited statistical significance") }
        static var warnLowWinrate: String { zh("胜率偏低", en: "Win rate low") }
        static var warnNegativeSharpe: String { zh("夏普为负，风险调整收益为负", en: "Negative Sharpe, risk-adjusted return negative") }
        static var runFailedNoResult: String { zh("本次运行失败，无结果可分析", en: "Run failed, no result to analyze") }

        // MARK: - PromotionPanel
        static var promotionTitle: String { zh("晋级实盘准入", en: "Live Promotion Gate") }
        static var promotionGrandStatus: String { zh("总状态", en: "Grand Status") }
        static var promotionGates: String { zh("闸门", en: "Gates") }
        static var promotionGateBacktest: String { zh("回测", en: "Backtest") }
        static var promotionGateDryrun: String { zh("模拟", en: "Dry-run") }
        static var ctaViewReadiness: String { zh("查看 Live Readiness 面板", en: "Open Live Readiness") }
        static var ctaGoLiveSmall: String { zh("前往启动 live_small", en: "Proceed to live_small") }
        static var promotionUnavailable: String { zh("准入评估暂不可用", en: "Promotion evaluation unavailable") }
        static var retry: String { zh("重试", en: "Retry") }

        // MARK: - DataSourceFooter
        static var dsEngine: String { zh("回测引擎", en: "Engine") }
        static var dsFreqtrade: String { zh("Freqtrade backtesting", en: "Freqtrade backtesting") }
        static var dsSource: String { zh("数据源", en: "Data source") }
        static var dsExecTime: String { zh("执行时间", en: "Exec time") }
        static var dsDslHash: String { zh("DSL hash", en: "DSL hash") }
        static var dsConfigSnapshot: String { zh("查看完整配置", en: "View full config") }

        // MARK: - MOCK
        static var mockBadge: String { zh("MOCK", en: "MOCK") }
        static var mockNoHistory: String { zh("mock 模式不提供历史数据", en: "Mock mode provides no historical data") }

        // MARK: - NewRunSheet
        static var sheetTitleBacktest: String { zh("新建回测", en: "New Backtest") }
        static var sheetTitleDryrun: String { zh("新建模拟", en: "New Dry-run") }
        static var sheetSubmit: String { zh("发起", en: "Start") }
        static var sheetCancel: String { zh("取消", en: "Cancel") }
        static var sheetSubmitting: String { zh("提交中…", en: "Submitting…") }
        static var sheetInvalidDate: String { zh("请选择有效的日期区间", en: "Select a valid date range") }
        static var sheetInvalidCapital: String { zh("初始资金必须大于 0", en: "Capital must be > 0") }
        static var sheetNoSymbols: String { zh("至少选择一个交易对", en: "Select at least one symbol") }
    }
}
