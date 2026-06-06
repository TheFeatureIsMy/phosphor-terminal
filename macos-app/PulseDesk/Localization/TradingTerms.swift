// TradingTerms.swift — 专业交易术语解释字典

import Foundation

@MainActor
enum TradingTerms {
    static func explanation(for term: String) -> String? {
        let lang = SettingsState.shared.language
        return definitions[term.uppercased()]?[lang]
    }

    private static let definitions: [String: [Language: String]] = [
        "RSI": [
            .zhCN: "相对强弱指标 — 衡量价格变动的速度和幅度，判断超买超卖",
            .enUS: "Relative Strength Index — measures speed and magnitude of price movements to evaluate overbought/oversold conditions",
        ],
        "MACD": [
            .zhCN: "移动平均线收敛/发散指标 — 通过快慢均线的交叉判断趋势变化",
            .enUS: "Moving Average Convergence Divergence — identifies trend changes through fast/slow MA crossovers",
        ],
        "EMA": [
            .zhCN: "指数移动平均线 — 对近期价格赋予更高权重的均线",
            .enUS: "Exponential Moving Average — a moving average that gives more weight to recent prices",
        ],
        "FVG": [
            .zhCN: "公允价值缺口 — 价格快速移动时留下的未测试价格区域，通常会被回填",
            .enUS: "Fair Value Gap — untested price area left by rapid price movement, often gets filled",
        ],
        "BOS": [
            .zhCN: "结构突破 — 价格突破前一个关键高点或低点，表示趋势延续",
            .enUS: "Break of Structure — price breaks a previous key high/low, indicating trend continuation",
        ],
        "CHOCH": [
            .zhCN: "特征变化 — 价格突破关键结构位，暗示趋势可能反转",
            .enUS: "Change of Character — price breaks a key structural level, suggesting potential trend reversal",
        ],
        "OB": [
            .zhCN: "订单块 — 机构大量建仓的价格区域，通常提供强支撑/阻力",
            .enUS: "Order Block — price zone where institutions placed large orders, typically provides strong S/R",
        ],
        "SHARPE": [
            .zhCN: "夏普比率 — 衡量每单位风险的超额收益，越高越好",
            .enUS: "Sharpe Ratio — measures excess return per unit of risk, higher is better",
        ],
        "SHARPE RATIO": [
            .zhCN: "夏普比率 — 衡量每单位风险的超额收益，越高越好",
            .enUS: "Sharpe Ratio — measures excess return per unit of risk, higher is better",
        ],
        "DRAWDOWN": [
            .zhCN: "回撤 — 从峰值到谷值的最大跌幅百分比",
            .enUS: "Drawdown — maximum peak-to-trough decline in percentage",
        ],
        "PNL": [
            .zhCN: "盈亏 — Profit and Loss 的缩写，表示交易收益或损失",
            .enUS: "Profit and Loss — the net gain or loss from a trade or portfolio",
        ],
        "P&L": [
            .zhCN: "盈亏 — 表示交易收益或损失",
            .enUS: "Profit and Loss — the net gain or loss from a trade or portfolio",
        ],
        "ATR": [
            .zhCN: "平均真实波幅 — 衡量市场波动性的指标",
            .enUS: "Average True Range — measures market volatility",
        ],
        "BOLLINGER": [
            .zhCN: "布林带 — 由中轨(MA)和上下轨(标准差)组成的波动通道",
            .enUS: "Bollinger Bands — volatility channel formed by MA centerline and standard deviation bands",
        ],
        "SMA": [
            .zhCN: "简单移动平均线 — 计算一定周期内收盘价的算术平均值",
            .enUS: "Simple Moving Average — arithmetic mean of closing prices over a specified period",
        ],
        "STOP LOSS": [
            .zhCN: "止损 — 预设的最大可接受亏损价位，触及后自动平仓",
            .enUS: "Stop Loss — predetermined maximum acceptable loss level that triggers automatic position closure",
        ],
        "TAKE PROFIT": [
            .zhCN: "止盈 — 预设的目标盈利价位，触及后自动平仓锁定收益",
            .enUS: "Take Profit — predetermined target profit level that triggers automatic position closure",
        ],
        "HTF": [
            .zhCN: "高时间框架 — 如日线、周线等大周期图表",
            .enUS: "Higher Time Frame — larger period charts like daily, weekly",
        ],
        "LTF": [
            .zhCN: "低时间框架 — 如5分钟、15分钟等小周期图表",
            .enUS: "Lower Time Frame — smaller period charts like 5m, 15m",
        ],
        "DCA": [
            .zhCN: "定投/均价策略 — 分批买入以平摊成本",
            .enUS: "Dollar Cost Averaging — buying in portions to average the entry price",
        ],
        "GRID": [
            .zhCN: "网格策略 — 在固定价格区间内等距挂单赚取波动收益",
            .enUS: "Grid Strategy — placing evenly spaced orders in a range to profit from volatility",
        ],
        "SLIPPAGE": [
            .zhCN: "滑点 — 预期执行价格与实际成交价格之间的差异",
            .enUS: "Slippage — difference between expected execution price and actual fill price",
        ],
        "PROFIT FACTOR": [
            .zhCN: "盈利因子 — 总盈利除以总亏损，大于1表示策略盈利",
            .enUS: "Profit Factor — gross profit divided by gross loss, above 1 means profitable",
        ],
        "WIN RATE": [
            .zhCN: "胜率 — 盈利交易占总交易数的百分比",
            .enUS: "Win Rate — percentage of profitable trades out of total trades",
        ],
        "MCP": [
            .zhCN: "模型上下文协议 — 用于 AI 模型与外部工具通信的标准协议",
            .enUS: "Model Context Protocol — standard protocol for AI model communication with external tools",
        ],
        "DSL": [
            .zhCN: "领域特定语言 — 用于定义策略规则的专用语法",
            .enUS: "Domain Specific Language — specialized syntax for defining strategy rules",
        ],
        "API": [
            .zhCN: "应用程序接口 — 不同软件系统之间通信的标准方式",
            .enUS: "Application Programming Interface — standard way for software systems to communicate",
        ],
        "2FA": [
            .zhCN: "双因素认证 — 使用两种不同验证方式增强账户安全",
            .enUS: "Two-Factor Authentication — enhances security using two different verification methods",
        ],
    ]
}
