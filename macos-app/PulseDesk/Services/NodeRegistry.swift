// NodeRegistry.swift — Central registry of all available node types
// 76 node definitions: 23 data, 22 signal, 13 decision, 13 AI, 5 output

import SwiftUI

// MARK: - Helpers (private)

private func exchangeDropdown(default def: String = "binance") -> ConfigField {
    ConfigField(key: "exchange", label: "交易所", fieldType: .dropdown,
                defaultValue: AnyCodable(def), options: ["binance", "okx", "bybit", "gate"])
}

private func symbolField() -> ConfigField {
    ConfigField(key: "symbol", label: "交易对", fieldType: .text, defaultValue: AnyCodable("BTC/USDT"))
}

private func periodSlider(default def: Int = 14, max: Int = 100) -> ConfigField {
    ConfigField(key: "period", label: "周期", fieldType: .slider,
                defaultValue: AnyCodable(def), min: 1, max: Double(max), step: 1)
}

private func chainDropdown() -> ConfigField {
    ConfigField(key: "chain", label: "链", fieldType: .dropdown,
                defaultValue: AnyCodable("ETH"), options: ["ETH", "BSC", "SOL", "ARB"])
}

private func outputPort(_ key: String, _ name: String, _ type: PortDataType, tooltip: String = "") -> PortDefinition {
    PortDefinition(key: key, name: name, direction: .output, dataType: type, tooltip: tooltip)
}

private func inputPort(_ key: String, _ name: String, _ type: PortDataType, required: Bool = false, allowsMultiple: Bool = false, tooltip: String = "") -> PortDefinition {
    PortDefinition(key: key, name: name, direction: .input, dataType: type, isRequired: required, allowsMultiple: allowsMultiple, tooltip: tooltip)
}

private func sliderWidget(key: String, label: String, min: Double, max: Double, step: Double = 1) -> WidgetDefinition {
    WidgetDefinition(key: key, label: label, widgetType: .slider, min: min, max: max, step: step)
}

// MARK: - NodeRegistry

enum NodeRegistry {

    // ── All registered node definitions, keyed by type string ──────────
    static let allNodes: [String: NodeDefinition] = {
        var registry: [String: NodeDefinition] = [:]
        for node in allDefinitions {
            registry[node.type] = node
        }
        return registry
    }()

    /// All definitions as a flat array
    static let allDefinitions: [NodeDefinition] =
        dataNodes + signalNodes + decisionNodes + aiNodes + outputNodes

    /// Look up a node definition by type
    static func definition(for type: String) -> NodeDefinition? {
        allNodes[type]
    }

    /// All nodes in a category
    static func nodes(in category: NodeCategory) -> [NodeDefinition] {
        allDefinitions.filter { $0.category == category }
    }

    // MARK: - 3.1 Data Source Nodes (25)

    static let dataNodes: [NodeDefinition] = [
        // ── CEX Market Data ──
        NodeDefinition(
            type: "data.kline", category: .data, name: "K线数据",
            icon: "chart.bar",
            outputPorts: [outputPort("kline", "K线数据", .kline)],
            configSchema: [exchangeDropdown(), symbolField(),
                           ConfigField(key: "timeframe", label: "周期", fieldType: .dropdown,
                                       defaultValue: AnyCodable("1h"),
                                       options: ["1m", "5m", "15m", "1h", "4h", "1d"])]
        ),
        NodeDefinition(
            type: "data.orderbook", category: .data, name: "订单簿",
            icon: "list.number",
            outputPorts: [outputPort("orderbook", "订单簿数据", .orderbook)],
            configSchema: [exchangeDropdown(), symbolField(),
                           ConfigField(key: "depth", label: "深度", fieldType: .number,
                                       defaultValue: AnyCodable(20), min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "data.funding", category: .data, name: "资金费率",
            icon: "drop",
            outputPorts: [outputPort("fundingRate", "资金费率", .fundingRate)],
            configSchema: [exchangeDropdown(), symbolField()]
        ),
        NodeDefinition(
            type: "data.liquidation", category: .data, name: "清算事件",
            icon: "exclamationmark.triangle",
            outputPorts: [outputPort("liquidation", "清算数据", .liquidation)],
            configSchema: [exchangeDropdown(),
                           ConfigField(key: "threshold", label: "阈值", fieldType: .number,
                                       defaultValue: AnyCodable(100000))]
        ),
        NodeDefinition(
            type: "data.openInterest", category: .data, name: "持仓量",
            icon: "chart.line.uptrend.xyaxis",
            outputPorts: [outputPort("oi", "持仓量", .number)],
            configSchema: [exchangeDropdown(), symbolField()]
        ),

        // ── On-chain Data ──
        NodeDefinition(
            type: "data.onchain.tvl", category: .data, name: "协议TVL",
            icon: "lock.shield",
            outputPorts: [outputPort("tvl", "协议TVL", .onchain)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "protocol", label: "协议", fieldType: .text,
                                       defaultValue: AnyCodable("uniswap"))]
        ),
        NodeDefinition(
            type: "data.onchain.activeAddresses", category: .data, name: "活跃地址",
            icon: "person.3",
            outputPorts: [outputPort("count", "活跃地址数", .onchain)],
            configSchema: [chainDropdown()]
        ),
        NodeDefinition(
            type: "data.onchain.whaleAlert", category: .data, name: "巨鲸转账",
            icon: "fish",
            outputPorts: [outputPort("transfers", "巨鲸转账", .array)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "minAmount", label: "最低金额", fieldType: .number,
                                       defaultValue: AnyCodable(1000000))]
        ),
        NodeDefinition(
            type: "data.onchain.dexVolume", category: .data, name: "DEX交易量",
            icon: "arrow.triangle.2.circlepath",
            outputPorts: [outputPort("volume", "DEX交易量", .onchain)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "dex", label: "DEX", fieldType: .text,
                                       defaultValue: AnyCodable("uniswap"))]
        ),
        NodeDefinition(
            type: "data.onchain.dexLiquidity", category: .data, name: "DEX流动性",
            icon: "drop.triangle",
            outputPorts: [outputPort("liquidity", "DEX流动性", .onchain)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "pool", label: "资金池", fieldType: .text,
                                       defaultValue: AnyCodable("ETH/USDC"))]
        ),
        NodeDefinition(
            type: "data.onchain.lendingRate", category: .data, name: "借贷利率",
            icon: "percent",
            outputPorts: [outputPort("rate", "借贷利率", .onchain)],
            configSchema: [ConfigField(key: "protocol", label: "协议", fieldType: .text,
                                       defaultValue: AnyCodable("aave"))]
        ),
        NodeDefinition(
            type: "data.onchain.stakingYield", category: .data, name: "质押收益",
            icon: "leaf",
            outputPorts: [outputPort("apy", "质押收益", .onchain)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "validator", label: "验证者", fieldType: .text)]
        ),
        NodeDefinition(
            type: "data.onchain.gasPrice", category: .data, name: "Gas价格",
            icon: "fuelpump",
            outputPorts: [outputPort("gwei", "Gas价格", .onchain)],
            configSchema: [chainDropdown()]
        ),
        NodeDefinition(
            type: "data.onchain.nftVolume", category: .data, name: "NFT交易量",
            icon: "photo.on.rectangle",
            outputPorts: [outputPort("volume", "NFT交易量", .onchain)],
            configSchema: [chainDropdown(),
                           ConfigField(key: "collection", label: "系列", fieldType: .text)]
        ),

        // ── Sentiment Data ──
        NodeDefinition(
            type: "data.sentiment.social", category: .data, name: "社交情绪",
            icon: "bubble.left.and.bubble.right",
            outputPorts: [outputPort("sentimentScore", "情绪分数", .sentiment)],
            configSchema: [ConfigField(key: "source", label: "来源", fieldType: .dropdown,
                                       defaultValue: AnyCodable("twitter"),
                                       options: ["twitter", "reddit", "telegram"]),
                           ConfigField(key: "keywords", label: "关键词", fieldType: .text)]
        ),
        NodeDefinition(
            type: "data.sentiment.news", category: .data, name: "新闻情绪",
            icon: "newspaper",
            outputPorts: [outputPort("sentimentScore", "情绪分数", .sentiment)],
            configSchema: [ConfigField(key: "source", label: "来源", fieldType: .dropdown,
                                       defaultValue: AnyCodable("coindesk"),
                                       options: ["coindesk", "cointelegraph", "decrypt"]),
                           ConfigField(key: "keywords", label: "关键词", fieldType: .text)]
        ),
        NodeDefinition(
            type: "data.sentiment.fearGreed", category: .data, name: "恐惧贪婪指数",
            icon: "gauge.medium",
            outputPorts: [outputPort("index", "恐惧贪婪指数", .sentiment)],
            configSchema: []
        ),

        // ── Macro Data ──
        NodeDefinition(
            type: "data.macro.dxy", category: .data, name: "美元指数",
            icon: "dollarsign.circle",
            outputPorts: [outputPort("value", "数值", .macro)],
            configSchema: []
        ),
        NodeDefinition(
            type: "data.macro.bondYield", category: .data, name: "国债收益率",
            icon: "chart.xyaxis.line",
            outputPorts: [outputPort("yield", "国债收益率", .macro)],
            configSchema: [ConfigField(key: "maturity", label: "期限", fieldType: .dropdown,
                                       defaultValue: AnyCodable("10y"),
                                       options: ["2y", "5y", "10y", "30y"])]
        ),
        NodeDefinition(
            type: "data.macro.cpi", category: .data, name: "CPI数据",
            icon: "chart.pie",
            outputPorts: [outputPort("value", "数值", .macro)],
            configSchema: []
        ),
        NodeDefinition(
            type: "data.macro.fedRate", category: .data, name: "联邦基金利率",
            icon: "building.columns",
            outputPorts: [outputPort("rate", "联邦利率", .macro)],
            configSchema: []
        ),
        NodeDefinition(
            type: "data.macro.sp500", category: .data, name: "标普500",
            icon: "chart.line.uptrend.xyaxis",
            outputPorts: [outputPort("value", "数值", .macro)],
            configSchema: []
        ),

        // ── Custom ──
        NodeDefinition(
            type: "data.custom.api", category: .data, name: "自定义API",
            icon: "globe",
            outputPorts: [outputPort("customData", "自定义数据", .object)],
            configSchema: [ConfigField(key: "url", label: "URL", fieldType: .text),
                           ConfigField(key: "parser", label: "解析器", fieldType: .text),
                           ConfigField(key: "headers", label: "请求头", fieldType: .text)]
        ),
    ]

    // MARK: - 3.2 Signal Processing Nodes (22)

    static let signalNodes: [NodeDefinition] = [
        // ── Technical Indicators ──
        NodeDefinition(
            type: "indicator.rsi", category: .signal, name: "RSI指标",
            icon: "waveform.path.ecg",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("rsiValue", "RSI值", .indicator)],
            configSchema: [periodSlider(default: 14),
                           ConfigField(key: "overbought", label: "超买", fieldType: .slider,
                                       defaultValue: AnyCodable(70), min: 50, max: 100, step: 1),
                           ConfigField(key: "oversold", label: "超卖", fieldType: .slider,
                                       defaultValue: AnyCodable(30), min: 0, max: 50, step: 1)],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.macd", category: .signal, name: "MACD",
            icon: "waveform",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("macd", "MACD线", .indicator), outputPort("signal", "信号线", .indicator),
                          outputPort("histogram", "柱状图", .indicator)],
            configSchema: [ConfigField(key: "fast", label: "快线", fieldType: .slider,
                                       defaultValue: AnyCodable(12), min: 1, max: 50, step: 1),
                           ConfigField(key: "slow", label: "慢线", fieldType: .slider,
                                       defaultValue: AnyCodable(26), min: 1, max: 50, step: 1),
                           ConfigField(key: "signal", label: "信号线", fieldType: .slider,
                                       defaultValue: AnyCodable(9), min: 1, max: 50, step: 1)],
            widgetDefinitions: [sliderWidget(key: "fast", label: "快", min: 1, max: 50)]
        ),
        NodeDefinition(
            type: "indicator.bollinger", category: .signal, name: "布林带",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("upper", "上轨", .indicator), outputPort("middle", "中轨", .indicator),
                          outputPort("lower", "下轨", .indicator)],
            configSchema: [periodSlider(default: 20),
                           ConfigField(key: "stdDev", label: "标准差", fieldType: .slider,
                                       defaultValue: AnyCodable(2.0), min: 0.5, max: 5.0, step: 0.1)],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.ma", category: .signal, name: "均线",
            icon: "chart.line.flattrend.xyaxis",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("maValue", "均线值", .indicator)],
            configSchema: [periodSlider(default: 50, max: 200),
                           ConfigField(key: "type", label: "类型", fieldType: .dropdown,
                                       defaultValue: AnyCodable("EMA"),
                                       options: ["SMA", "EMA", "WMA", "DEMA"])],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 200)]
        ),
        NodeDefinition(
            type: "indicator.atr", category: .signal, name: "ATR",
            icon: "arrow.up.arrow.down",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("atrValue", "ATR值", .indicator)],
            configSchema: [periodSlider()],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.ichimoku", category: .signal, name: "一目均衡表",
            icon: "cloud.sun",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("tenkan", "转换线", .indicator), outputPort("kijun", "基准线", .indicator),
                          outputPort("senkouA", "先行带A", .indicator), outputPort("senkouB", "先行带B", .indicator),
                          outputPort("chikou", "迟行带", .indicator)],
            configSchema: [ConfigField(key: "tenkan", label: "转换线", fieldType: .slider,
                                       defaultValue: AnyCodable(9), min: 1, max: 100, step: 1),
                           ConfigField(key: "kijun", label: "基准线", fieldType: .slider,
                                       defaultValue: AnyCodable(26), min: 1, max: 100, step: 1),
                           ConfigField(key: "senkou", label: "先行带", fieldType: .slider,
                                       defaultValue: AnyCodable(52), min: 1, max: 100, step: 1)]
        ),
        NodeDefinition(
            type: "indicator.fibonacci", category: .signal, name: "斐波那契",
            icon: "fibrechannel",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("levels", "斐波那契位", .array)],
            configSchema: [ConfigField(key: "swingHigh", label: "波段高点", fieldType: .number),
                           ConfigField(key: "swingLow", label: "波段低点", fieldType: .number)]
        ),
        NodeDefinition(
            type: "indicator.vwap", category: .signal, name: "VWAP",
            icon: "chart.bar.xaxis",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("vwap", "VWAP值", .indicator)],
            configSchema: []
        ),
        NodeDefinition(
            type: "indicator.obv", category: .signal, name: "OBV",
            icon: "barometer",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("obv", "OBV值", .indicator)],
            configSchema: []
        ),
        NodeDefinition(
            type: "indicator.stochastic", category: .signal, name: "随机指标",
            icon: "slider.horizontal.3",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("k", "K值", .indicator), outputPort("d", "D值", .indicator)],
            configSchema: [ConfigField(key: "kPeriod", label: "K周期", fieldType: .slider,
                                       defaultValue: AnyCodable(14), min: 1, max: 100, step: 1),
                           ConfigField(key: "dPeriod", label: "D周期", fieldType: .slider,
                                       defaultValue: AnyCodable(3), min: 1, max: 100, step: 1),
                           ConfigField(key: "smooth", label: "平滑", fieldType: .slider,
                                       defaultValue: AnyCodable(3), min: 1, max: 10, step: 1)],
            widgetDefinitions: [sliderWidget(key: "kPeriod", label: "K", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.adx", category: .signal, name: "ADX",
            icon: "arrow.left.and.right",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("adx", "ADX值", .indicator), outputPort("diPlus", "DI+", .indicator),
                          outputPort("diMinus", "DI-", .indicator)],
            configSchema: [periodSlider()],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.cci", category: .signal, name: "CCI",
            icon: "waveform.path",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("cci", "CCI值", .indicator)],
            configSchema: [periodSlider(default: 20)],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.williamsR", category: .signal, name: "威廉指标",
            icon: "arrow.down.to.line",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("williamsR", "威廉R值", .indicator)],
            configSchema: [periodSlider()],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.mfi", category: .signal, name: "MFI",
            icon: "banknote",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("mfi", "MFI值", .indicator)],
            configSchema: [periodSlider()],
            widgetDefinitions: [sliderWidget(key: "period", label: "周期", min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "indicator.custom", category: .signal, name: "自定义指标",
            icon: "function",
            inputPorts: [inputPort("kline", "K线数据", .kline, required: true)],
            outputPorts: [outputPort("result", "指标结果", .indicator)],
            configSchema: [ConfigField(key: "formula", label: "公式", fieldType: .expression)]
        ),

        // ── Math / Filter / Transform / Logic ──
        NodeDefinition(
            type: "math.expression", category: .signal, name: "数学表达式",
            icon: "x.squareroot",
            inputPorts: [inputPort("a", "输入A", .number), inputPort("b", "输入B", .number)],
            outputPorts: [outputPort("result", "计算结果", .number)],
            configSchema: [ConfigField(key: "expression", label: "表达式", fieldType: .expression)]
        ),
        NodeDefinition(
            type: "filter.threshold", category: .signal, name: "阈值过滤",
            icon: "line.horizontal.3.decrease.circle",
            inputPorts: [inputPort("value", "输入值", .number, required: true)],
            outputPorts: [outputPort("signal", "过滤信号", .signal)],
            configSchema: [ConfigField(key: "threshold", label: "阈值", fieldType: .number,
                                       defaultValue: AnyCodable(70)),
                           ConfigField(key: "operator", label: "运算符", fieldType: .dropdown,
                                       defaultValue: AnyCodable(">"),
                                       options: [">", "<", "=", ">=", "<="])]
        ),
        NodeDefinition(
            type: "transform.smooth", category: .signal, name: "平滑处理",
            icon: "waveform.path.ecg.rectangle",
            inputPorts: [inputPort("data", "原始数据", .array, required: true)],
            outputPorts: [outputPort("smoothed", "平滑数据", .array)],
            configSchema: [ConfigField(key: "method", label: "方法", fieldType: .dropdown,
                                       defaultValue: AnyCodable("MA"),
                                       options: ["MA", "指数", "Kalman"])]
        ),
        NodeDefinition(
            type: "transform.normalize", category: .signal, name: "归一化",
            icon: "arrow.up.and.down.text.horizontal",
            inputPorts: [inputPort("data", "原始数据", .array, required: true)],
            outputPorts: [outputPort("normalized", "归一化数据", .array)],
            configSchema: [ConfigField(key: "min", label: "最小值", fieldType: .number,
                                       defaultValue: AnyCodable(0)),
                           ConfigField(key: "max", label: "最大值", fieldType: .number,
                                       defaultValue: AnyCodable(1))]
        ),
        NodeDefinition(
            type: "logic.delay", category: .signal, name: "延迟",
            icon: "clock.arrow.circlepath",
            inputPorts: [inputPort("any", "输入信号", .signal)],
            outputPorts: [outputPort("any", "延迟信号", .signal)],
            configSchema: [ConfigField(key: "delay", label: "延迟(周期)", fieldType: .number,
                                       defaultValue: AnyCodable(1), min: 1, max: 100)]
        ),
        NodeDefinition(
            type: "logic.gate", category: .signal, name: "逻辑门",
            icon: "lock.shield",
            inputPorts: [inputPort("signal", "输入信号", .signal, required: true)],
            outputPorts: [outputPort("signal", "输出信号", .signal)],
            configSchema: [ConfigField(key: "condition", label: "条件", fieldType: .expression)]
        ),
    ]

    // MARK: - 3.3 Decision Nodes (13)

    static let decisionNodes: [NodeDefinition] = [
        NodeDefinition(
            type: "condition.if", category: .decision, name: "条件判断",
            icon: "questionmark.diamond",
            inputPorts: [inputPort("condition", "条件", .boolean, required: true)],
            outputPorts: [outputPort("true", "真分支", .signal), outputPort("false", "假分支", .signal)],
            configSchema: [ConfigField(key: "condition", label: "条件", fieldType: .expression)]
        ),
        NodeDefinition(
            type: "condition.multi", category: .decision, name: "多条件分支",
            icon: "arrow.triangle.branch",
            inputPorts: [inputPort("value", "输入值", .number, required: true)],
            outputPorts: [outputPort("branches", "分支结果", .array)],
            configSchema: [ConfigField(key: "cases", label: "分支", fieldType: .expression)]
        ),
        NodeDefinition(
            type: "condition.combine", category: .decision, name: "条件组合",
            icon: "rectangle.connected.to.line.below",
            inputPorts: [inputPort("a", "条件A", .boolean), inputPort("b", "条件B", .boolean)],
            outputPorts: [outputPort("combined", "组合结果", .boolean)],
            configSchema: [ConfigField(key: "logic", label: "逻辑", fieldType: .dropdown,
                                       defaultValue: AnyCodable("AND"),
                                       options: ["AND", "OR", "加权"])]
        ),

        // ── Strategy ──
        NodeDefinition(
            type: "strategy.entry", category: .decision, name: "入场信号",
            icon: "arrow.down.right.circle",
            inputPorts: [inputPort("signal", "入场信号", .signal, required: true)],
            outputPorts: [outputPort("order", "订单", .object)],
            configSchema: [ConfigField(key: "entryConditions", label: "入场条件", fieldType: .expression),
                           ConfigField(key: "positionSize", label: "仓位大小", fieldType: .number,
                                       defaultValue: AnyCodable(1000))]
        ),
        NodeDefinition(
            type: "strategy.exit", category: .decision, name: "出场信号",
            icon: "arrow.up.right.circle",
            inputPorts: [inputPort("signal", "出场信号", .signal, required: true),
                         inputPort("position", "当前持仓", .position)],
            outputPorts: [outputPort("order", "订单", .object)],
            configSchema: [ConfigField(key: "exitConditions", label: "出场条件", fieldType: .expression),
                           ConfigField(key: "takeProfit", label: "止盈(%)", fieldType: .number,
                                       defaultValue: AnyCodable(5)),
                           ConfigField(key: "stopLoss", label: "止损(%)", fieldType: .number,
                                       defaultValue: AnyCodable(2)),
                           ConfigField(key: "trailing", label: "追踪止损(%)", fieldType: .number,
                                       defaultValue: AnyCodable(1))]
        ),
        NodeDefinition(
            type: "strategy.rebalance", category: .decision, name: "再平衡",
            icon: "arrow.triangle.2.circlepath",
            inputPorts: [inputPort("positions", "持仓列表", .array)],
            outputPorts: [outputPort("orders", "订单列表", .array)],
            configSchema: [ConfigField(key: "allocation", label: "配置", fieldType: .expression)]
        ),

        // ── Position Sizing ──
        NodeDefinition(
            type: "sizing.fixed", category: .decision, name: "固定仓位",
            icon: "number.square",
            inputPorts: [],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "amount", label: "金额", fieldType: .number,
                                       defaultValue: AnyCodable(1000))]
        ),
        NodeDefinition(
            type: "sizing.percentage", category: .decision, name: "百分比仓位",
            icon: "percent",
            inputPorts: [inputPort("balance", "账户余额", .number)],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "percent", label: "百分比", fieldType: .slider,
                                       defaultValue: AnyCodable(10), min: 0, max: 100, step: 1)],
            widgetDefinitions: [sliderWidget(key: "percent", label: "%", min: 0, max: 100)]
        ),
        NodeDefinition(
            type: "sizing.kelly", category: .decision, name: "凯利公式",
            icon: "function",
            inputPorts: [],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "winRate", label: "胜率", fieldType: .number,
                                       defaultValue: AnyCodable(0.55)),
                           ConfigField(key: "odds", label: "赔率", fieldType: .number,
                                       defaultValue: AnyCodable(2.0))]
        ),
        NodeDefinition(
            type: "sizing.volatility", category: .decision, name: "波动率仓位",
            icon: "waveform.path.ecg.rectangle",
            inputPorts: [inputPort("atr", "ATR值", .indicator, required: true)],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "atrMultiplier", label: "ATR倍数", fieldType: .slider,
                                       defaultValue: AnyCodable(2.0), min: 0.5, max: 5.0, step: 0.1)],
            widgetDefinitions: [WidgetDefinition(key: "atrMultiplier", label: "ATR", widgetType: .slider,
                                                  min: 0.5, max: 5.0, step: 0.1)]
        ),
        NodeDefinition(
            type: "sizing.pyramid", category: .decision, name: "金字塔加仓",
            icon: "triangle",
            inputPorts: [inputPort("signal", "加仓信号", .signal)],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "levels", label: "层数", fieldType: .number,
                                       defaultValue: AnyCodable(3)),
                           ConfigField(key: "multiplier", label: "倍数", fieldType: .number,
                                       defaultValue: AnyCodable(1.5))]
        ),
        NodeDefinition(
            type: "sizing.antiMartingale", category: .decision, name: "反马丁格尔",
            icon: "arrow.clockwise.circle",
            inputPorts: [inputPort("signal", "加仓信号", .signal)],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "baseSize", label: "基础仓位", fieldType: .number,
                                       defaultValue: AnyCodable(100)),
                           ConfigField(key: "multiplier", label: "倍数", fieldType: .number,
                                       defaultValue: AnyCodable(2.0))]
        ),
        NodeDefinition(
            type: "sizing.maxDrawdown", category: .decision, name: "最大回撤限制",
            icon: "arrow.down.to.line.compact",
            inputPorts: [inputPort("balance", "账户余额", .number)],
            outputPorts: [outputPort("quantity", "下单数量", .number)],
            configSchema: [ConfigField(key: "maxDrawdown", label: "最大回撤(%)", fieldType: .slider,
                                       defaultValue: AnyCodable(20), min: 1, max: 50, step: 1)],
            widgetDefinitions: [sliderWidget(key: "maxDrawdown", label: "回撤", min: 1, max: 50)]
        ),
    ]

    // MARK: - 3.4 AI Nodes (13)

    static let aiNodes: [NodeDefinition] = [
        NodeDefinition(
            type: "ai.llm", category: .ai, name: "LLM推理",
            icon: "brain.head.profile",
            inputPorts: [inputPort("context", "上下文", .text)],
            outputPorts: [outputPort("text", "文本输出", .llmOutput), outputPort("analysis", "分析结果", .object)],
            configSchema: [ConfigField(key: "model", label: "模型", fieldType: .dropdown,
                                       defaultValue: AnyCodable("Claude"),
                                       options: ["GPT-4", "Claude", "DeepSeek"]),
                           ConfigField(key: "temperature", label: "温度", fieldType: .slider,
                                       defaultValue: AnyCodable(0.7), min: 0, max: 2.0, step: 0.1),
                           ConfigField(key: "systemPrompt", label: "系统提示", fieldType: .code)]
        ),
        NodeDefinition(
            type: "ai.rag", category: .ai, name: "RAG检索",
            icon: "doc.text.magnifyingglass",
            inputPorts: [inputPort("query", "查询文本", .text, required: true)],
            outputPorts: [outputPort("documents", "检索文档", .array)],
            configSchema: [ConfigField(key: "knowledgeBase", label: "知识库", fieldType: .multiselect),
                           ConfigField(key: "topK", label: "返回数量", fieldType: .number,
                                       defaultValue: AnyCodable(5), min: 1, max: 20)]
        ),
        NodeDefinition(
            type: "ai.sentiment.nlp", category: .ai, name: "NLP情绪",
            icon: "text.bubble",
            inputPorts: [inputPort("text", "输入文本", .text, required: true)],
            outputPorts: [outputPort("score", "情绪分数", .sentiment), outputPort("label", "情绪标签", .text)],
            configSchema: [ConfigField(key: "model", label: "模型", fieldType: .text)]
        ),
        NodeDefinition(
            type: "ai.sentiment.finbert", category: .ai, name: "FinBERT情绪",
            icon: "brain",
            inputPorts: [inputPort("text", "输入文本", .text, required: true)],
            outputPorts: [outputPort("score", "情绪分数", .sentiment), outputPort("label", "情绪标签", .text)],
            configSchema: []
        ),
        NodeDefinition(
            type: "ai.forecast", category: .ai, name: "AI预测",
            icon: "crystal.ball",
            inputPorts: [inputPort("kline", "K线数据", .kline)],
            outputPorts: [outputPort("prediction", "预测值", .number), outputPort("confidence", "置信度", .number)],
            configSchema: [ConfigField(key: "model", label: "模型", fieldType: .text),
                           ConfigField(key: "horizon", label: "预测周期", fieldType: .number,
                                       defaultValue: AnyCodable(24))]
        ),
        NodeDefinition(
            type: "ai.agent", category: .ai, name: "AI Agent",
            icon: "person.circle",
            inputPorts: [inputPort("context", "上下文", .text)],
            outputPorts: [outputPort("result", "Agent结果", .object)],
            configSchema: [ConfigField(key: "agentType", label: "Agent类型", fieldType: .dropdown,
                                       defaultValue: AnyCodable("研究员"),
                                       options: ["研究员", "交易员", "风控"])]
        ),
        NodeDefinition(
            type: "ai.scoring", category: .ai, name: "信号评分",
            icon: "star.circle",
            inputPorts: [inputPort("signal", "交易信号", .signal, required: true)],
            outputPorts: [outputPort("score", "评分", .number), outputPort("ranking", "排名", .text)],
            configSchema: [ConfigField(key: "scoringModel", label: "评分模型", fieldType: .text)]
        ),
        NodeDefinition(
            type: "ai.freqai.model", category: .ai, name: "FreqAI模型",
            icon: "cpu",
            inputPorts: [inputPort("kline", "K线数据", .kline)],
            outputPorts: [outputPort("prediction", "预测值", .number)],
            configSchema: [ConfigField(key: "modelConfig", label: "模型配置", fieldType: .code)]
        ),
        NodeDefinition(
            type: "ai.freqai.train", category: .ai, name: "FreqAI训练",
            icon: "arrow.triangle.2.circlepath",
            inputPorts: [],
            outputPorts: [outputPort("model", "训练模型", .object), outputPort("metrics", "训练指标", .object)],
            configSchema: [ConfigField(key: "trainingData", label: "训练数据", fieldType: .filePicker),
                           ConfigField(key: "params", label: "参数", fieldType: .expression)]
        ),
        NodeDefinition(
            type: "ai.backtest.result", category: .ai, name: "回测结果",
            icon: "clock.arrow.circlepath",
            inputPorts: [inputPort("strategy", "策略配置", .object)],
            outputPorts: [outputPort("metrics", "回测指标", .object), outputPort("equityCurve", "权益曲线", .array)],
            configSchema: [ConfigField(key: "strategyConfig", label: "策略配置", fieldType: .code)]
        ),
        NodeDefinition(
            type: "ai.backtest.optimize", category: .ai, name: "回测优化",
            icon: "slider.horizontal.2.arrow.trianglehead.left.and.right",
            inputPorts: [inputPort("metrics", "回测指标", .object)],
            outputPorts: [outputPort("bestParams", "最优参数", .object)],
            configSchema: [ConfigField(key: "target", label: "目标函数", fieldType: .expression)]
        ),
        NodeDefinition(
            type: "ai.correlation", category: .ai, name: "相关性分析",
            icon: "chart.dots.scatter",
            inputPorts: [inputPort("data", "价格数据", .array)],
            outputPorts: [outputPort("matrix", "相关矩阵", .object)],
            configSchema: [ConfigField(key: "symbols", label: "交易对", fieldType: .text,
                                       defaultValue: AnyCodable("BTC,ETH,SOL")),
                           ConfigField(key: "window", label: "窗口", fieldType: .number,
                                       defaultValue: AnyCodable(30))]
        ),
        NodeDefinition(
            type: "ai.anomaly", category: .ai, name: "异常检测",
            icon: "exclamationmark.triangle",
            inputPorts: [inputPort("data", "输入数据", .array, required: true)],
            outputPorts: [outputPort("anomalies", "异常点", .array)],
            configSchema: [ConfigField(key: "method", label: "方法", fieldType: .dropdown,
                                       defaultValue: AnyCodable("Z-Score"),
                                       options: ["Z-Score", "IQR", "Isolation Forest"])]
        ),
    ]

    // MARK: - 3.5 Output Nodes (5)

    static let outputNodes: [NodeDefinition] = [
        NodeDefinition(
            type: "output.order", category: .output, name: "下单",
            icon: "arrow.right.circle",
            inputPorts: [inputPort("order", "订单对象", .object, required: true)],
            configSchema: [exchangeDropdown(),
                           ConfigField(key: "execution", label: "执行方式", fieldType: .dropdown,
                                       defaultValue: AnyCodable("市价"),
                                       options: ["市价", "限价", "IOC", "FOK"])]
        ),
        NodeDefinition(
            type: "output.alert", category: .output, name: "告警通知",
            icon: "bell.circle",
            inputPorts: [inputPort("message", "消息内容", .text, required: true)],
            configSchema: [ConfigField(key: "channels", label: "通知渠道", fieldType: .multiselect,
                                       options: ["Telegram", "邮件", "Toast"]),
                           ConfigField(key: "template", label: "模板", fieldType: .code)]
        ),
        NodeDefinition(
            type: "output.log", category: .output, name: "日志",
            icon: "text.alignleft",
            inputPorts: [inputPort("data", "日志数据", .object)],
            configSchema: [ConfigField(key: "level", label: "级别", fieldType: .dropdown,
                                       defaultValue: AnyCodable("Info"),
                                       options: ["Debug", "Info", "Warn", "Error"])]
        ),
        NodeDefinition(
            type: "output.dashboard", category: .output, name: "仪表盘展示",
            icon: "rectangle.on.rectangle.angled",
            inputPorts: [inputPort("data", "展示数据", .object, required: true)],
            configSchema: [ConfigField(key: "displayType", label: "展示类型", fieldType: .dropdown,
                                       defaultValue: AnyCodable("折线"),
                                       options: ["折线", "柱状", "饼图", "K线"])]
        ),
        NodeDefinition(
            type: "output.webhook", category: .output, name: "Webhook",
            icon: "network",
            inputPorts: [inputPort("payload", "Webhook负载", .object, required: true)],
            configSchema: [ConfigField(key: "url", label: "URL", fieldType: .text),
                           ConfigField(key: "headers", label: "请求头", fieldType: .text)]
        ),
    ]
}
