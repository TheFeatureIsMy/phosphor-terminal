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
    }
}
