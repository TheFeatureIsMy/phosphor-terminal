// Enums.swift — 所有业务枚举，String rawValue 保证 JSON 兼容

import Foundation
import SwiftUI

// 策略状态
enum StrategyStatus: String, Codable, CaseIterable {
    case draft, backtested, active, paused, retired

    var label: String {
        switch self {
        case .draft: return L10n.zh("草稿", en: "Draft")
        case .backtested: return L10n.zh("已回测", en: "Backtested")
        case .active: return L10n.zh("运行中", en: "Live")
        case .paused: return L10n.zh("已暂停", en: "Paused")
        case .retired: return L10n.zh("已退役", en: "Retired")
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

    var label: String { self == .buy ? L10n.zh("买入", en: "Buy") : L10n.zh("卖出", en: "Sell") }
    func color(_ colors: PulseColors) -> Color { self == .buy ? colors.profit : PulseColors.loss }
}

// 订单类型
enum OrderType: String, Codable {
    case market, limit

    var label: String { self == .market ? L10n.zh("市价", en: "Market") : L10n.zh("限价", en: "Limit") }
}

// 订单状态
enum OrderStatus: String, Codable {
    case pending, filled, cancelled, failed

    var label: String {
        switch self {
        case .pending: return L10n.zh("待成交", en: "Pending")
        case .filled: return L10n.zh("已成交", en: "Filled")
        case .cancelled: return L10n.zh("已取消", en: "Cancelled")
        case .failed: return L10n.zh("失败", en: "Failed")
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

    var label: String { self == .long ? L10n.zh("多", en: "Long") : L10n.zh("空", en: "Short") }
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
        case .eastmoney: return L10n.zh("东方财富", en: "East Money")
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
        case .crypto: return L10n.zh("加密货币", en: "Crypto")
        case .usStock: return L10n.zh("美股", en: "US Equities")
        case .aShare: return L10n.zh("A股", en: "A-Shares")
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
        case .crypto: return L10n.zh("加密货币: 24/7 交易, 最低 $10", en: "Crypto: 24/7 trading, min $10")
        case .usStock: return L10n.zh("美股: 美东时间 9:30-16:00, 最低 $1", en: "US Equities: 9:30-16:00 ET, min $1")
        case .aShare: return L10n.zh("A股: 北京时间 9:30-15:00, 最低 100股", en: "A-Shares: 9:30-15:00 CST, min 100 shares")
        }
    }
}

// 交易模式
enum TradingMode: String, Codable, CaseIterable, Identifiable {
    case spot, futures, margin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spot: return L10n.zh("现货", en: "Spot")
        case .futures: return L10n.zh("合约", en: "Futures")
        case .margin: return L10n.zh("杠杆", en: "Margin")
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
        case .overview: return L10n.Nav.overview
        case .strategy: return L10n.Nav.strategy
        case .structure: return L10n.Nav.structure
        case .execution: return L10n.Nav.execution
        case .risk: return L10n.Nav.risk
        case .aiResearch: return L10n.Nav.aiResearch
        case .growth: return L10n.Nav.growth
        case .system: return L10n.Nav.system
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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .liveReadiness: return "checkmark.shield"
        case .strategyWorkspace: return "cpu"
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
        }
    }

    var label: String {
        switch self {
        case .dashboard: return L10n.Nav.dashboard
        case .liveReadiness: return L10n.Nav.liveReadiness
        case .strategyWorkspace: return L10n.Nav.strategyWorkspace
        case .backtestSimulation: return L10n.Nav.backtestSimulation
        case .marketStructure: return L10n.Nav.marketStructure
        case .structureMatrix: return L10n.Nav.structureMatrix
        case .manipulationRadar: return L10n.Nav.manipulationRadar
        case .executionCenter: return L10n.Nav.executionCenter
        case .ordersPositions: return L10n.Nav.ordersPositions
        case .reconciliationBus: return L10n.Nav.reconciliationBus
        case .riskCenter: return L10n.Nav.riskCenter
        case .stopProtection: return L10n.Nav.stopProtection
        case .circuitBreakers: return L10n.Nav.circuitBreakers
        case .aiResearchRoom: return L10n.Nav.aiStudio
        case .agentPlatform: return L10n.Nav.agentPlatform
        case .signalCenter: return L10n.Nav.signalCenter
        case .marketSentiment: return L10n.Nav.marketSentiment
        case .growthReview: return L10n.Nav.growthReview
        case .failureClustering: return L10n.Nav.failureClustering
        case .strategyOptimization: return L10n.Nav.strategyOptimization
        case .serviceManagement: return L10n.Nav.serviceManagement
        case .dataSourceManagement: return L10n.Nav.dataSourceManagement
        case .systemSettings: return L10n.Nav.systemSettings
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .liveReadiness: return .overview
        case .strategyWorkspace, .backtestSimulation: return .strategy
        case .marketStructure, .structureMatrix, .manipulationRadar: return .structure
        case .executionCenter, .ordersPositions, .reconciliationBus: return .execution
        case .riskCenter, .stopProtection, .circuitBreakers: return .risk
        case .aiResearchRoom, .agentPlatform, .signalCenter, .marketSentiment: return .aiResearch
        case .growthReview, .failureClustering, .strategyOptimization: return .growth
        case .serviceManagement, .dataSourceManagement, .systemSettings: return .system
        }
    }

    var sidebarVisible: Bool { true }

    var primaryWorkspace: PrimaryWorkspace {
        switch self {
        case .dashboard, .liveReadiness,
             .marketStructure, .structureMatrix, .manipulationRadar,
             .executionCenter, .ordersPositions, .reconciliationBus,
             .riskCenter, .stopProtection, .circuitBreakers:
            return .tradingConsole
        case .strategyWorkspace, .backtestSimulation,
             .aiResearchRoom, .signalCenter, .marketSentiment,
             .growthReview, .failureClustering, .strategyOptimization:
            return .strategyLab
        case .agentPlatform,
             .serviceManagement, .dataSourceManagement, .systemSettings:
            return .operations
        }
    }
}

// MARK: - Strategy Workbench Panels (⌘1–⌘6 floating panels)
enum WorkbenchPanel: String, CaseIterable, Identifiable {
    case list, node, version, risk, backtest, readiness

    var id: String { rawValue }

    var shortcut: KeyEquivalent {
        switch self {
        case .list: return "1"
        case .node: return "2"
        case .version: return "3"
        case .risk: return "4"
        case .backtest: return "5"
        case .readiness: return "6"
        }
    }

    var icon: String {
        switch self {
        case .list: return "list.bullet.rectangle"
        case .node: return "rectangle.connected.to.line.below"
        case .version: return "clock.arrow.circlepath"
        case .risk: return "shield.lefthalf.filled"
        case .backtest: return "play.rectangle.on.rectangle"
        case .readiness: return "checkmark.seal"
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
        case .riskAlert: return L10n.zh("风险告警", en: "Risk Alert")
        case .tradeExecuted: return L10n.zh("交易执行", en: "Trade Executed")
        case .strategyUpdate: return L10n.zh("策略更新", en: "Strategy Update")
        case .systemAlert: return L10n.zh("系统告警", en: "System Alert")
        case .aiInsight: return L10n.zh("AI 洞察", en: "AI Insight")
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
        case .info: return L10n.zh("信息", en: "Info")
        case .warning: return L10n.zh("警告", en: "Warning")
        case .critical: return L10n.zh("严重", en: "Critical")
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
        case .healthy: return L10n.zh("健康", en: "Healthy")
        case .warning: return L10n.zh("警告", en: "Warning")
        case .blocked: return L10n.zh("已阻断", en: "Blocked")
        case .locked: return L10n.zh("已锁定", en: "Locked")
        case .running: return L10n.zh("运行中", en: "Running")
        case .stopped: return L10n.zh("已停止", en: "Stopped")
        case .failed: return L10n.zh("失败", en: "Failed")
        case .reconciling: return L10n.zh("对账中", en: "Reconciling")
        case .stale: return L10n.zh("过期", en: "Stale")
        case .unknown: return L10n.zh("未知", en: "Unknown")
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
        case .liveReady: return L10n.zh("实盘就绪", en: "Live Ready")
        case .liveSmallReady: return L10n.zh("小仓就绪", en: "Small-Size Ready")
        case .paperOnly: return L10n.zh("仅模拟", en: "Paper Only")
        case .riskLocked: return L10n.zh("风控锁定", en: "Risk Locked")
        case .emergencyLocked: return L10n.zh("紧急锁定", en: "Emergency Locked")
        case .notReady: return L10n.zh("未就绪", en: "Not Ready")
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

