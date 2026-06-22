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

        // HUD (40px top bar)
        static var hudStageLabel: String { zh("Stage", en: "Stage") }
        static var hudReadinessLabel: String { zh("准入", en: "Readiness") }
        static var hudNextLabel: String { zh("下一步", en: "Next") }
        static var hudHashCopied: String { zh("已复制", en: "Copied") }
        static var hudActionValidate: String { zh("验证", en: "Validate") }
        static var hudActionDuplicate: String { zh("复制", en: "Duplicate") }
        static var hudActionArchive: String { zh("归档", en: "Archive") }
        static var hudActionBindLive: String { zh("绑定实盘", en: "Bind Live") }
        static var hudActionRunDryrun: String { zh("运行模拟", en: "Run Dry-run") }
        static var hudActionMore: String { zh("更多", en: "More") }
        static var hudReasonAlreadyArchived: String { zh("策略已归档", en: "Strategy already archived") }
        static var hudReasonNotPaperPassed: String { zh("仅 paper_passed 状态可绑定", en: "Only paper_passed can bind live") }
        static var hudReasonNotRunnable: String { zh("当前状态不允许运行模拟", en: "Status does not allow dry-run") }
        static var hudReasonNoStrategy: String { zh("未选中策略", en: "No strategy selected") }

        // Time-ago labels (HUD identity strip)
        static var timeAgoNow: String { zh("刚刚", en: "just now") }
        static var timeAgoMinutes: String { zh("%d 分钟前", en: "%dm ago") }
        static var timeAgoHours: String { zh("%d 小时前", en: "%dh ago") }
        static var timeAgoDays: String { zh("%d 天前", en: "%dd ago") }

        // Bottom status bar
        static var statusValid: String { zh("验证通过", en: "Valid") }
        static var statusInvalid: String { zh("%d 错误", en: "%d errors") }
        static var statusUnvalidated: String { zh("未验证", en: "Unvalidated") }
        static var statusNodes: String { zh("%d 节点", en: "%d nodes") }
        static var statusEdges: String { zh("%d 连线", en: "%d edges") }
        static var statusShortcutHint: String { zh("⌘1~⌘6 切换面板 · ⌘0 关闭", en: "⌘1–⌘6 panels · ⌘0 close") }

        // Panels (chrome titles)
        static var panelList: String { zh("策略列表", en: "Strategies") }
        static var panelNode: String { zh("节点配置", en: "Node Config") }
        static var panelVersion: String { zh("版本", en: "Versions") }
        static var panelRisk: String { zh("风控绑定", en: "Risk Binding") }
        static var panelBacktest: String { zh("回测/模拟", en: "Backtest/Dry-run") }
        static var panelReadiness: String { zh("实盘准入", en: "Readiness") }
        static var panelClose: String { zh("关闭", en: "Close") }

        // Node config (⌘2 panel)
        static var nodeNoSelection: String { zh("画布中未选中节点", en: "No node selected") }
        static var nodeSignalInput: String { zh("信号输入", en: "Signal Input") }
        static var nodeIndicatorCondition: String { zh("指标条件", en: "Indicator Condition") }
        static var nodeFilter: String { zh("过滤器", en: "Filter") }
        static var nodePositionSizing: String { zh("仓位管理", en: "Position Sizing") }
        static var nodeRiskPolicy: String { zh("风控策略", en: "Risk Policy") }
        static var nodeExecutionOutput: String { zh("执行输出", en: "Execution Output") }
        static var nodeStructureDefense: String { zh("结构防御", en: "Structure Defense") }
        static var nodeAccountRisk: String { zh("账户风控", en: "Account Risk Firewall") }
        static var nodeMTFGuard: String { zh("多周期守卫", en: "MTF Guard") }
        static var nodeFieldSymbols: String { zh("标的", en: "Symbols") }
        static var nodeFieldTimeframe: String { zh("周期", en: "Timeframe") }
        static var nodeFieldSource: String { zh("来源", en: "Source") }
        static var nodeFieldIndicator: String { zh("指标", en: "Indicator") }
        static var nodeFieldOperator: String { zh("条件", en: "Operator") }
        static var nodeFieldValue: String { zh("阈值", en: "Value") }
        static var nodeFieldPositionPct: String { zh("仓位百分比", en: "Position %") }
        static var nodeFieldStoploss: String { zh("止损", en: "Stop Loss") }
        static var nodeFieldMaxOpen: String { zh("最大持仓", en: "Max Open Trades") }
        static var nodeFieldTrailing: String { zh("追踪止损", en: "Trailing Stop") }
        static var nodeFieldEntry: String { zh("入场逻辑", en: "Entry Logic") }
        static var nodeFieldExit: String { zh("出场逻辑", en: "Exit Logic") }
        static var nodeFieldStructures: String { zh("结构类型", en: "Structures") }
        static var nodeFieldMinScore: String { zh("最小评分", en: "Min Score") }
        static var nodeFieldDailyLoss: String { zh("单日最大亏损", en: "Daily Loss") }
        static var nodeFieldWeeklyLoss: String { zh("单周最大亏损", en: "Weekly Loss") }
        static var nodeFieldConsecLoss: String { zh("连续亏损上限", en: "Max Consec Loss") }
        static var nodeFieldFastTf: String { zh("快周期", en: "Fast TF") }
        static var nodeFieldSlowTf: String { zh("慢周期", en: "Slow TF") }
        static var nodeFieldStructureType: String { zh("结构类型", en: "Structure Type") }
        static var nodeFieldRuleType: String { zh("类型", en: "Rule Type") }
        static var nodeFieldCandles: String { zh("冷却K线", en: "Candles") }

        // Versions panel (⌘3)
        static var versionsRecent: String { zh("最近变更", en: "Recent Changes") }
        static var versionsList: String { zh("版本列表", en: "Versions") }
        static var versionsLatest: String { zh("最新", en: "Latest") }
        static var versionsActivityEmpty: String { zh("暂无活动", en: "No activity") }

        // Risk binding panel (⌘4)
        static var bindingNoneTitle: String { zh("未绑定风控", en: "No risk binding") }
        static var bindingNoneDesc: String { zh("绑定到 live_small 资金池后即可走实盘准入", en: "Bind to a live_small pool to enable live trading.") }
        static var bindingBindLiveSmall: String { zh("绑定 live_small", en: "Bind live_small") }
        static var bindingActive: String { zh("已生效", en: "Active") }
        static var bindingPolicyLabel: String { zh("策略", en: "Policy") }
        static var bindingPoolLabel: String { zh("资金池", en: "Pool") }
        static var bindingModeLabel: String { zh("模式", en: "Mode") }
        static var bindingRemaining: String { zh("余额", en: "Remaining") }
        static var bindingSheetTitle: String { zh("绑定风控策略", en: "Bind Risk Policy") }
        static var bindingSheetPick: String { zh("选择策略版本", en: "Pick a policy version") }
        static var bindingSheetPickPool: String { zh("选择资金池", en: "Pick a capital pool") }
        static var bindingSheetMode: String { zh("绑定模式", en: "Binding Mode") }
        static var bindingSheetApply: String { zh("绑定", en: "Apply") }
        static var bindingSheetCancel: String { zh("取消", en: "Cancel") }
        static var bindingGuardsTitle: String { zh("风控守卫", en: "Guards") }
        static var bindingGuardMaxPosition: String { zh("最大单笔", en: "Max Position") }
        static var bindingGuardDailyLoss: String { zh("单日亏损上限", en: "Daily Loss") }
        static var bindingGuardDrawdown: String { zh("回撤上限", en: "Drawdown") }
        static var bindingGuardExposure: String { zh("总敞口", en: "Total Exposure") }

        // Backtest/Dryrun panel (⌘5)
        static var btLatestBacktest: String { zh("最近回测", en: "Latest Backtest") }
        static var btLatestDryrun: String { zh("最近模拟", en: "Latest Dry-run") }
        static var btAllRuns: String { zh("全部运行", en: "All Runs") }
        static var btSeeAll: String { zh("查看全部", en: "See All") }
        static var btKindBacktest: String { zh("回测", en: "Backtest") }
        static var btKindDryrun: String { zh("模拟", en: "Dry-run") }
        static var btEmpty: String { zh("暂无运行记录", en: "No runs yet") }
        static var btReturn: String { zh("收益", en: "Return") }
        static var btErrorReason: String { zh("失败原因", en: "Error Reason") }

        // Readiness panel (⌘6)
        static var readinessStrategyGates: String { zh("策略门禁", en: "Strategy Gates") }
        static var readinessSystemGates: String { zh("系统门禁", en: "System Gates") }
        static var readinessNextStep: String { zh("下一步", en: "Next Step") }
        static var readinessPassed: String { zh("已通过", en: "Passed") }
        static var readinessGoFix: String { zh("前往修复", en: "Go fix") }
        static var readinessGrandNotLive: String { zh("尚未实盘", en: "Not Live") }
        static var readinessGrandNeedsConfig: String { zh("待配置", en: "Needs Config") }
        static var readinessGrandNeedsValidation: String { zh("待验证", en: "Needs Validation") }
        static var readinessGrandPaperPassed: String { zh("已通过模拟", en: "Paper Passed") }
        static var readinessGrandReadyLive: String { zh("可实盘", en: "Ready for Live") }
    }
}
