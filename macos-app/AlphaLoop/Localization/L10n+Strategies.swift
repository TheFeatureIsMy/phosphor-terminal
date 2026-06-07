// L10n+Strategies.swift — 策略相关文案

extension L10n {
    enum Strategies {
        static var title: String { zh("策略管理", en: "Strategy Management") }
        static var canvas: String { zh("策略画布", en: "Strategy Canvas") }
        static var create: String { zh("新建策略", en: "New Strategy") }
        static var empty: String { zh("暂无策略", en: "No Strategies") }
        static var emptyDesc: String { zh("创建你的第一个量化交易策略", en: "Create your first quantitative trading strategy") }
        static var templates: String { zh("模板库", en: "Templates") }
        static var validate: String { zh("验证", en: "Validate") }
        static var strategyList: String { zh("策略列表", en: "Strategy List") }
        static var selectToEdit: String { zh("选择左侧策略开始编辑", en: "Select a strategy to start editing") }
        static var orCreateNew: String { zh("或创建新策略", en: "Or create a new strategy") }
        static var browseTemplates: String { zh("浏览模板", en: "Browse Templates") }

        // Detail tabs
        static var tabOverview: String { zh("概览", en: "Overview") }
        static var tabDSL: String { zh("DSL 规则", en: "DSL Rules") }
        static var tabCanvas: String { zh("画布", en: "Canvas") }
        static var tabBacktest: String { zh("回测", en: "Backtest") }
        static var tabVersions: String { zh("版本", en: "Versions") }
        static var tabRuns: String { zh("运行记录", en: "Run Records") }
        static var tabSignals: String { zh("信号", en: "Signals") }
        static var tabDryrun: String { zh("模拟", en: "Dry Run") }
        static var tabRisk: String { zh("风控", en: "Risk") }
        static var tabGrowth: String { zh("增长", en: "Growth") }

        // Status
        static var statusDraft: String { zh("草稿", en: "Draft") }
        static var statusActive: String { zh("运行中", en: "Active") }
        static var statusPaused: String { zh("已暂停", en: "Paused") }
        static var statusArchived: String { zh("已归档", en: "Archived") }

        // Filters
        static var filterAll: String { zh("全部", en: "All") }
        static var filterDryrun: String { zh("模拟", en: "Dry Run") }
        static var filterLive: String { zh("实盘", en: "Live") }
        static var filterRunning: String { zh("运行中", en: "Running") }
        static var filterStopped: String { zh("已停止", en: "Stopped") }
        static var filterAbnormal: String { zh("异常", en: "Abnormal") }

        // Canvas
        static var validationPassed: String { zh("验证通过", en: "Validation Passed") }
        static var validationFailed: String { zh("验证失败", en: "Validation Failed") }
        static var notValidated: String { zh("未验证", en: "Not Validated") }
        static var dslPreview: String { zh("DSL 预览", en: "DSL Preview") }
        static var codePreview: String { zh("代码预览", en: "Code Preview") }
        static var copyDSL: String { zh("复制 DSL", en: "Copy DSL") }

        // CRUD
        static var deleteTitle: String { zh("删除策略", en: "Delete Strategy") }
        static var deleteMessage: String { zh("确定要删除这个策略吗？此操作不可撤销。", en: "Are you sure you want to delete this strategy? This action cannot be undone.") }
        static var renameTitle: String { zh("重命名策略", en: "Rename Strategy") }
        static var newName: String { zh("新名称", en: "New Name") }
        static var enterName: String { zh("请输入策略名称", en: "Enter strategy name") }

        // Templates
        static var templateRSI: String { zh("RSI 均值回归", en: "RSI Mean Reversion") }
        static var templateRSIDesc: String { zh("RSI 超卖买入、超买卖出，适合震荡行情", en: "Buy on RSI oversold, sell on overbought. Suitable for ranging markets") }
        static var templateBollinger: String { zh("布林带突破", en: "Bollinger Breakout") }
        static var templateBollingerDesc: String { zh("价格突破布林带上轨做多，跌破下轨做空", en: "Long on upper band breakout, short on lower band breakdown") }
        static var templateMACD: String { zh("MACD 趋势跟踪", en: "MACD Trend Following") }
        static var templateMACDDesc: String { zh("MACD 金叉做多、死叉做空，搭配 EMA 过滤", en: "Long on MACD golden cross, short on death cross with EMA filter") }
        static var templateMTF: String { zh("多时间框架确认", en: "Multi-Timeframe Confirmation") }
        static var templateMTFDesc: String { zh("大周期定方向，小周期定入场，多级别共振", en: "Higher TF for direction, lower TF for entry, multi-TF confluence") }
        static var templateGrid: String { zh("网格交易", en: "Grid Trading") }
        static var templateGridDesc: String { zh("在固定价格区间内等距挂单，赚取波动收益", en: "Place evenly spaced orders within a price range to profit from volatility") }
    }
}
