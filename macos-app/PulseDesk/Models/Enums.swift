// Enums.swift — 所有业务枚举，String rawValue 保证 JSON 兼容

import Foundation
import SwiftUI

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
    case alpaca, ibkr         // US stocks
    case joinquant, eastmoney // A-shares

    var id: String { rawValue }

    var label: String {
        switch self {
        case .binance: return "Binance"
        case .okx: return "OKX"
        case .bybit: return "Bybit"
        case .gate: return "Gate"
        case .alpaca: return "Alpaca"
        case .ibkr: return "Interactive Brokers"
        case .joinquant: return "JoinQuant"
        case .eastmoney: return "东方财富"
        }
    }
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

// 侧边栏分组
enum SidebarSection: String, CaseIterable {
    case overview    // "OVERVIEW"
    case strategy    // "STRATEGY"
    case structure   // "STRUCTURE"
    case execution   // "EXECUTION"
    case risk        // "RISK"
    case aiResearch  // "AI RESEARCH"
    case growth      // "GROWTH"
    case system      // "SYSTEM"

    var label: String {
        switch self {
        case .overview: return "OVERVIEW"
        case .strategy: return "STRATEGY"
        case .structure: return "STRUCTURE"
        case .execution: return "EXECUTION"
        case .risk: return "RISK"
        case .aiResearch: return "AI RESEARCH"
        case .growth: return "GROWTH"
        case .system: return "SYSTEM"
        }
    }
}

// 侧边栏导航路由
enum AppRoute: String, CaseIterable, Identifiable {
    // OVERVIEW
    case dashboard
    case liveReadiness
    // STRATEGY
    case strategyWorkspace
    case strategyCanvas
    case backtestSimulation
    // STRUCTURE
    case marketStructure
    case structureMatrix
    case manipulationRadar
    // EXECUTION
    case executionCenter
    case ordersPositions
    case reconciliationBus
    // RISK
    case riskCenter
    case stopProtection
    case circuitBreakers
    // AI RESEARCH
    case aiResearchRoom
    case agentPlatform
    case signalCenter
    case marketSentiment
    // GROWTH
    case growthReview
    case failureClustering
    case strategyOptimization
    // SYSTEM
    case serviceManagement
    case dataSourceManagement
    case systemSettings
    // Internal
    case strategyDetail

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .liveReadiness: return "checkmark.shield"
        case .strategyWorkspace: return "cpu"
        case .strategyCanvas: return "paintbrush.pointed"
        case .backtestSimulation: return "clock.arrow.circlepath"
        case .marketStructure: return "chart.bar.xaxis"
        case .structureMatrix: return "tablecells"
        case .manipulationRadar: return "exclamationmark.shield"
        case .executionCenter: return "play.circle"
        case .ordersPositions: return "list.bullet.rectangle"
        case .reconciliationBus: return "arrow.triangle.2.circlepath"
        case .riskCenter: return "shield.checkered"
        case .stopProtection: return "hand.raised"
        case .circuitBreakers: return "bolt.circle"
        case .aiResearchRoom: return "brain.head.profile"
        case .agentPlatform: return "person.3.sequence"
        case .signalCenter: return "antenna.radiowaves.left.and.right"
        case .marketSentiment: return "waveform.path.ecg"
        case .growthReview: return "chart.line.uptrend.xyaxis.circle"
        case .failureClustering: return "xmark.circle.fill"
        case .strategyOptimization: return "wand.and.stars"
        case .serviceManagement: return "server.rack"
        case .dataSourceManagement: return "externaldrive.connected.to.line.below"
        case .systemSettings: return "gearshape"
        case .strategyDetail: return "doc.text"
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "总览 Dashboard"
        case .liveReadiness: return "实盘准入"
        case .strategyWorkspace: return "策略工作台"
        case .strategyCanvas: return "策略画布"
        case .backtestSimulation: return "回测 / 模拟"
        case .marketStructure: return "市场结构"
        case .structureMatrix: return "结构矩阵"
        case .manipulationRadar: return "操纵雷达"
        case .executionCenter: return "执行中心"
        case .ordersPositions: return "订单 / 持仓"
        case .reconciliationBus: return "对账总线"
        case .riskCenter: return "风控中心"
        case .stopProtection: return "止损保护"
        case .circuitBreakers: return "熔断记录"
        case .aiResearchRoom: return "AI 投研室"
        case .agentPlatform: return "Agent 平台"
        case .signalCenter: return "信号中心"
        case .marketSentiment: return "市场情绪"
        case .growthReview: return "复盘成长"
        case .failureClustering: return "失败聚类"
        case .strategyOptimization: return "策略优化"
        case .serviceManagement: return "服务管理"
        case .dataSourceManagement: return "数据源管理"
        case .systemSettings: return "系统设置"
        case .strategyDetail: return "策略详情"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .liveReadiness: return .overview
        case .strategyWorkspace, .strategyCanvas, .backtestSimulation: return .strategy
        case .marketStructure, .structureMatrix, .manipulationRadar: return .structure
        case .executionCenter, .ordersPositions, .reconciliationBus: return .execution
        case .riskCenter, .stopProtection, .circuitBreakers: return .risk
        case .aiResearchRoom, .agentPlatform, .signalCenter, .marketSentiment: return .aiResearch
        case .growthReview, .failureClustering, .strategyOptimization: return .growth
        case .serviceManagement, .dataSourceManagement, .systemSettings: return .system
        case .strategyDetail: return .strategy
        }
    }

    var sidebarVisible: Bool {
        self != .strategyDetail
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

// MARK: - 统一状态模型
enum UnifiedState: String, Codable {
    case healthy, warning, blocked, locked, running, stopped, failed, reconciling, stale, unknown

    var label: String {
        switch self {
        case .healthy: return "健康"
        case .warning: return "警告"
        case .blocked: return "已阻断"
        case .locked: return "已锁定"
        case .running: return "运行中"
        case .stopped: return "已停止"
        case .failed: return "失败"
        case .reconciling: return "对账中"
        case .stale: return "过期"
        case .unknown: return "未知"
        }
    }

    var color: Color {
        switch self {
        case .healthy, .running: return PulseColors.StateColors.green
        case .warning: return PulseColors.StateColors.yellow
        case .blocked, .failed: return PulseColors.StateColors.red
        case .locked: return PulseColors.StateColors.orangeRed
        case .stopped: return PulseColors.StateColors.gray
        case .reconciling: return PulseColors.StateColors.purple
        case .stale, .unknown: return PulseColors.StateColors.mutedYellow
        }
    }

    var isBlocking: Bool {
        switch self {
        case .blocked, .failed, .locked: return true
        default: return false
        }
    }
}

// MARK: - 实盘准入状态
enum LiveReadinessState: String, Codable {
    case liveReady = "LIVE_READY"
    case liveSmallReady = "LIVE_SMALL_READY"
    case paperOnly = "PAPER_ONLY"
    case riskLocked = "RISK_LOCKED"
    case emergencyLocked = "EMERGENCY_LOCKED"
    case notReady = "NOT_READY"

    var label: String {
        switch self {
        case .liveReady: return "实盘就绪"
        case .liveSmallReady: return "小仓就绪"
        case .paperOnly: return "仅模拟"
        case .riskLocked: return "风控锁定"
        case .emergencyLocked: return "紧急锁定"
        case .notReady: return "未就绪"
        }
    }

    var color: Color {
        switch self {
        case .liveReady: return PulseColors.StateColors.green
        case .liveSmallReady: return PulseColors.StateColors.orange
        case .paperOnly: return PulseColors.StateColors.yellow
        case .riskLocked, .emergencyLocked: return PulseColors.StateColors.red
        case .notReady: return PulseColors.StateColors.gray
        }
    }

    var canStartPaper: Bool {
        self != .emergencyLocked
    }

    var canStartLiveSmall: Bool {
        self == .liveReady || self == .liveSmallReady
    }
}

