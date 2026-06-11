// L10n+Workbench.swift — 策略工作台「发射控制台」改造文案

extension L10n {
    enum Workbench {
        // Header / breadcrumb
        static var title: String { zh("策略工作台", en: "Strategy Workspace") }
        static var subtitle: String { zh("发射控制台", en: "Launch Console") }
        static var noStrategySelected: String { zh("从左侧轨道选择策略", en: "Select a strategy from the rail") }
        static var noStrategyHint: String { zh("或新建草稿开始", en: "Or start a new draft") }

        // Track list (left rail)
        static var rail: String { zh("候补轨道", en: "Launch Tracks") }
        static var railSearch: String { zh("搜索策略", en: "Search") }
        static var filterAll: String { zh("全部", en: "All") }
        static var filterDraft: String { zh("草稿", en: "Drafts") }
        static var filterPaper: String { zh("模拟", en: "Paper") }
        static var filterLive: String { zh("实盘", en: "Live") }
        static var newDraft: String { zh("新建草稿", en: "New Draft") }
        static var fromSignal: String { zh("从信号生成", en: "From Signal") }

        // Lifecycle rail (7 checkpoints)
        static var stageDraft: String { zh("草稿", en: "Draft") }
        static var stageValidated: String { zh("已校验", en: "Validated") }
        static var stageBacktested: String { zh("已回测", en: "Backtested") }
        static var stagePaperRun: String { zh("模拟运行", en: "Paper Run") }
        static var stagePaperPass: String { zh("模拟通过", en: "Paper Pass") }
        static var stageLivePending: String { zh("实盘准入", en: "Live Pending") }
        static var stageLiveSmall: String { zh("小仓实盘", en: "Live Small") }

        // KPI strip
        static var kpiEquity: String { zh("权益", en: "Equity") }
        static var kpiPnl: String { zh("累计盈亏", en: "PnL") }
        static var kpiWinRate: String { zh("胜率", en: "Win Rate") }
        static var kpiDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var kpiSharpe: String { zh("夏普", en: "Sharpe") }

        // Section cards
        static var cardRuntime: String { zh("运行舱", en: "Runtime") }
        static var cardVersions: String { zh("版本", en: "Versions") }
        static var cardRisk: String { zh("风控护栏", en: "Risk Guards") }
        static var cardBacktests: String { zh("回测", en: "Backtests") }
        static var cardDryrun: String { zh("模拟盘", en: "Paper Trading") }
        static var cardSignals: String { zh("信号源", en: "Signal Sources") }

        // Runtime card
        static var runtimeRunning: String { zh("运行中", en: "Running") }
        static var runtimeStopped: String { zh("已停止", en: "Stopped") }
        static var runtimeError: String { zh("异常", en: "Error") }
        static var runtimeNoActive: String { zh("无活跃运行", en: "No active run") }
        static var runtimeHeartbeat: String { zh("心跳", en: "Heartbeat") }
        static var runtimeMode: String { zh("模式", en: "Mode") }
        static var runtimeStartedAt: String { zh("启动时间", en: "Started") }
        static var runtimeStop: String { zh("停止", en: "Stop") }

        // Versions card
        static var versionsCurrent: String { zh("当前", en: "Current") }
        static var versionsDraft: String { zh("草稿", en: "Draft") }
        static var versionsEdit: String { zh("打开画布", en: "Open Canvas") }
        static var versionsDiff: String { zh("对比", en: "Diff") }
        static var versionsHash: String { zh("DSL Hash", en: "DSL Hash") }
        static var versionsEmpty: String { zh("尚无版本，从画布开始", en: "No versions yet — start in canvas") }
        static var versionsCount: String { zh("共 %d 个版本", en: "%d versions") }

        // Risk card
        static var riskGuards: String { zh("护栏", en: "Guards") }
        static var riskEmpty: String { zh("尚未配置风控规则", en: "No risk rules configured") }
        static var riskReasonCodes: String { zh("原因码", en: "Reason Codes") }

        // Backtest card
        static var backtestRecent: String { zh("最近 3 次", en: "Last 3 runs") }
        static var backtestEmpty: String { zh("无回测记录", en: "No backtest history") }
        static var backtestStart: String { zh("启动回测", en: "Run Backtest") }

        // Dryrun card
        static var dryrunOrders: String { zh("订单", en: "Orders") }
        static var dryrunPnl: String { zh("纸面盈亏", en: "Paper PnL") }
        static var dryrunEmpty: String { zh("尚未开启模拟盘", en: "No paper trading yet") }
        static var dryrunStart: String { zh("启动模拟盘", en: "Start Paper") }

        // Signal card
        static var signalsBound: String { zh("绑定信号", en: "Bound Signals") }
        static var signalsEmpty: String { zh("尚未接入信号源", en: "No signals attached") }
        static var signalsAttach: String { zh("接入信号", en: "Attach Signal") }

        // Context drawer
        static var drawerDecision: String { zh("决策", en: "Decision") }
        static var drawerReason: String { zh("原因码", en: "Reason") }
        static var drawerLogs: String { zh("日志", en: "Logs") }
        static var drawerSnapshot: String { zh("最新决策快照", en: "Latest Decision Snapshot") }
        static var drawerEmpty: String { zh("暂无决策数据", en: "No decision data") }
        static var drawerCollapse: String { zh("折叠", en: "Collapse") }
        static var drawerExpand: String { zh("展开", en: "Expand") }

        // Quick actions
        static var actionValidate: String { zh("校验", en: "Validate") }
        static var actionBacktest: String { zh("回测", en: "Backtest") }
        static var actionDryrun: String { zh("模拟", en: "Paper") }
        static var actionPromote: String { zh("申请实盘", en: "Promote") }
        static var actionArchive: String { zh("归档", en: "Archive") }

        // Canvas Edit Bay
        static var canvasEditBay: String { zh("编辑舱", en: "Edit Bay") }
        static var canvasPalette: String { zh("调色板", en: "Palette") }
        static var canvasInspector: String { zh("检查器", en: "Inspector") }
        static var canvasUnsaved: String { zh("未保存", en: "Unsaved") }
        static var canvasSaveDraft: String { zh("保存草稿", en: "Save Draft") }
        static var canvasPublish: String { zh("保存并发布", en: "Save & Publish") }
        static var canvasValidate: String { zh("校验", en: "Validate") }
        static var canvasClose: String { zh("关闭", en: "Close") }
        static var canvasLoading: String { zh("画布加载中…", en: "Loading canvas…") }
        static var canvasUnavailable: String { zh("画布资源缺失", en: "Canvas resources missing") }

        // Severity labels for reason chips
        static var severityInfo: String { zh("信息", en: "Info") }
        static var severityWarn: String { zh("警告", en: "Warn") }
        static var severityBlock: String { zh("阻断", en: "Block") }

        // Workspace mode toggle
        static var modeConsole: String { zh("控制台", en: "Console") }
        static var modeCanvas: String { zh("画布", en: "Canvas") }
        static var switcherPlaceholder: String { zh("切换策略", en: "Switch strategy") }
        static var inspectorTitle: String { zh("上下文", en: "Context") }

        // Canvas in-place
        static var canvasNoVersion: String { zh("当前策略尚无版本，画布从空白开始", en: "No version yet — canvas starts blank") }
        static var canvasReturnConsole: String { zh("返回控制台", en: "Back to Console") }

        // Lifecycle off-path badges
        static var offPathPaused: String { zh("已暂停", en: "Paused") }
        static var offPathArchived: String { zh("已归档", en: "Archived") }
        static var offPathRejected: String { zh("已驳回", en: "Rejected") }

        // Lifecycle transitions (user-triggered)
        static var lifecycleMenu: String { zh("生命周期", en: "Lifecycle") }
        static var transitionValidate: String { zh("提交校验", en: "Submit for validation") }
        static var transitionStartPaper: String { zh("启动模拟盘", en: "Start paper run") }
        static var transitionPromoteLive: String { zh("申请实盘", en: "Promote to live") }
        static var transitionApproveLive: String { zh("批准实盘", en: "Approve live") }
        static var transitionPause: String { zh("暂停", en: "Pause") }
        static var transitionResume: String { zh("恢复运行", en: "Resume") }
        static var transitionArchive: String { zh("归档", en: "Archive") }
        static var transitionReject: String { zh("驳回", en: "Reject") }
        static var transitionReopen: String { zh("重新开启", en: "Reopen") }
        static var transitionFailed: String { zh("跃迁失败", en: "Transition failed") }
        static var transitionNoneAvailable: String { zh("当前状态无可用操作", en: "No actions available") }
    }
}
