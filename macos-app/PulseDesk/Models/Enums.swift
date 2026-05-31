// Enums.swift — 所有业务枚举，String rawValue 保证 JSON 兼容

import Foundation
import SwiftUI

// 策略类型
enum StrategyType: String, Codable, CaseIterable, Identifiable {
    case maCross = "ma_cross"
    case breakout
    case grid
    case meanReversion = "mean_reversion"
    case ragGenerated = "rag_generated"

    var id: String { rawValue }

    /// 中文显示名
    var label: String {
        switch self {
        case .maCross: return "均线交叉"
        case .breakout: return "突破策略"
        case .grid: return "网格交易"
        case .meanReversion: return "均值回归"
        case .ragGenerated: return "AI 生成"
        }
    }

    /// 类型颜色
    var color: Color {
        switch self {
        case .maCross: return PulseColors.info // cyan
        case .breakout: return PulseColors.warning // amber
        case .grid: return PulseColors.purple
        case .meanReversion: return PulseColors.accent // neon green
        case .ragGenerated: return PulseColors.accent
        }
    }
}

// 策略状态
enum StrategyStatus: String, Codable, CaseIterable {
    case draft, backtested, active, paused, retired

    var label: String {
        switch self {
        case .draft: return "草稿"
        case .backtested: return "已回测"
        case .active: return "运行中"
        case .paused: return "已暂停"
        case .retired: return "已退役"
        }
    }

    func color(_ colors: PulseColors) -> Color {
        switch self {
        case .draft: return colors.statusDraft
        case .backtested: return PulseColors.info
        case .active: return PulseColors.statusActive
        case .paused: return PulseColors.statusPaused
        case .retired: return PulseColors.statusError
        }
    }
}

// 策略来源
enum StrategySource: String, Codable {
    case manual, ragGenerated = "rag_generated", optimized
}

// 订单方向
enum OrderSide: String, Codable {
    case buy = "BUY"
    case sell = "SELL"

    var label: String { self == .buy ? "买入" : "卖出" }
    func color(_ colors: PulseColors) -> Color { self == .buy ? colors.profit : PulseColors.loss }
}

// 订单类型
enum OrderType: String, Codable {
    case market, limit

    var label: String { self == .market ? "市价" : "限价" }
}

// 订单状态
enum OrderStatus: String, Codable {
    case pending, filled, cancelled, failed

    var label: String {
        switch self {
        case .pending: return "待成交"
        case .filled: return "已成交"
        case .cancelled: return "已取消"
        case .failed: return "失败"
        }
    }

    func color(_ colors: PulseColors) -> Color {
        switch self {
        case .pending: return PulseColors.warning
        case .filled: return PulseColors.success
        case .cancelled: return colors.textMuted
        case .failed: return PulseColors.danger
        }
    }
}

// 持仓方向
enum PositionSide: String, Codable {
    case long, short

    var label: String { self == .long ? "多" : "空" }
    func color(_ colors: PulseColors) -> Color { self == .long ? colors.profit : PulseColors.loss }
}

// 持仓状态
enum PositionStatus: String, Codable {
    case open, closed
}

// 风险事件类型
enum RiskEventType: String, Codable {
    case stopLoss = "stop_loss"
    case circuitBreaker = "circuit_breaker"
    case apiError = "api_error"
    case dataAnomaly = "data_anomaly"
    case correlationWarning = "correlation_warning"

    var icon: String {
        switch self {
        case .stopLoss: return "shield.slash"
        case .circuitBreaker: return "bolt.circle"
        case .apiError: return "wifi.exclamationmark"
        case .dataAnomaly: return "chart.line.flattrend.xyaxis"
        case .correlationWarning: return "link.circle"
        }
    }
}

// 风险等级
enum RiskSeverity: String, Codable {
    case low, medium, high, critical

    var color: Color {
        switch self {
        case .low: return PulseColors.success
        case .medium: return PulseColors.warning
        case .high: return PulseColors.amber
        case .critical: return PulseColors.danger
        }
    }

    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.shield"
        case .critical: return "xmark.shield.fill"
        }
    }
}

// API 状态
enum APIStatus: String, Codable {
    case connected, disconnected, error

    var color: Color {
        switch self {
        case .connected: return PulseColors.statusActive
        case .disconnected: return PulseColors.statusPaused
        case .error: return PulseColors.danger
        }
    }
}

// 交易所
enum Exchange: String, Codable, CaseIterable, Identifiable {
    case binance, okx, bybit, gate

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

// 交易市场
enum MarketType: String, Codable, CaseIterable, Identifiable {
    case crypto
    case usStock = "us_stock"
    case aShare = "a_share"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crypto: return "加密货币"
        case .usStock: return "美股"
        case .aShare: return "A股"
        }
    }

    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle"
        case .usStock: return "dollarsign.circle"
        case .aShare: return "yensign.circle"
        }
    }

    var constraintNote: String {
        switch self {
        case .crypto: return "加密货币: 24/7 交易, 最低 $10"
        case .usStock: return "美股: 美东时间 9:30-16:00, 最低 $1"
        case .aShare: return "A股: 北京时间 9:30-15:00, 最低 100股"
        }
    }
}

// 交易模式
enum TradingMode: String, Codable, CaseIterable, Identifiable {
    case spot, futures, margin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spot: return "现货"
        case .futures: return "合约"
        case .margin: return "杠杆"
        }
    }
}


// 相关性告警级别
enum AlertLevel: String, Codable {
    case normal, yellow, red

    var color: Color {
        switch self {
        case .normal: return PulseColors.success
        case .yellow: return PulseColors.warning
        case .red: return PulseColors.danger
        }
    }
}

// 侧边栏导航路由
enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard, strategies, backtest, trades
    case aiStudio
    case sentiment, attribution, aiProviders, risk
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .strategies: return "cpu"
        case .backtest: return "clock.arrow.circlepath"
        case .trades: return "list.bullet.rectangle"
        case .aiStudio: return "brain.head.profile"
        case .sentiment: return "waveform.path.ecg"
        case .attribution: return "chart.bar.doc.horizontal"
        case .aiProviders: return "server.rack"
        case .risk: return "shield.checkered"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "仪表盘"
        case .strategies: return "策略管理"
        case .backtest: return "回测中心"
        case .trades: return "交易记录"
        case .aiStudio: return "AI 工作室"
        case .sentiment: return "市场情绪"
        case .attribution: return "归因分析"
        case .aiProviders: return "AI 服务"
        case .risk: return "风险管理"
        case .settings: return "系统设置"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .trades, .risk: return .trading
        case .strategies, .backtest: return .strategy
        case .aiStudio, .sentiment, .attribution, .aiProviders: return .ai
        case .settings: return .system
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case trading, strategy, ai, system

    var label: String {
        switch self {
        case .trading: return "交易"
        case .strategy: return "策略"
        case .ai: return "AI"
        case .system: return "系统"
        }
    }
}

// MARK: - 通知类型
enum NotificationType: String, Codable, CaseIterable {
    case riskAlert = "risk_alert"
    case tradeExecuted = "trade_executed"
    case strategyUpdate = "strategy_update"
    case systemAlert = "system_alert"
    case aiInsight = "ai_insight"

    var label: String {
        switch self {
        case .riskAlert: return "风险告警"
        case .tradeExecuted: return "交易执行"
        case .strategyUpdate: return "策略更新"
        case .systemAlert: return "系统告警"
        case .aiInsight: return "AI 洞察"
        }
    }

    var icon: String {
        switch self {
        case .riskAlert: return "shield.slash"
        case .tradeExecuted: return "arrow.left.arrow.right"
        case .strategyUpdate: return "cpu"
        case .systemAlert: return "exclamationmark.triangle"
        case .aiInsight: return "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .riskAlert: return PulseColors.danger
        case .tradeExecuted: return PulseColors.accent
        case .strategyUpdate: return PulseColors.info
        case .systemAlert: return PulseColors.warning
        case .aiInsight: return PulseColors.purple
        }
    }
}

// MARK: - 通知严重程度
enum NotificationSeverity: String, Codable {
    case info, warning, critical

    var label: String {
        switch self {
        case .info: return "信息"
        case .warning: return "警告"
        case .critical: return "严重"
        }
    }

    var color: Color {
        switch self {
        case .info: return PulseColors.info
        case .warning: return PulseColors.warning
        case .critical: return PulseColors.danger
        }
    }
}
