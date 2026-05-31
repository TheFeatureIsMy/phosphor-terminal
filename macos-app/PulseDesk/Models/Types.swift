// Types.swift — 所有领域模型，1:1 对应后端 API 响应结构

import Foundation

// MARK: - 用户
// 后端 UserResponse 返回 username，Swift 侧用 name 显示
// telegramId / role / updatedAt 在 /auth/me 响应中可能不存在，设为可选
struct User: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let email: String?
    let telegramId: String?
    let role: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case name = "username"
        case telegramId = "telegram_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 自定义解码：role / telegramId / updatedAt 可能缺失，给默认值
    init(id: Int, name: String, email: String?, telegramId: String?, role: String, createdAt: String, updatedAt: String) {
        self.id = id
        self.name = name
        self.email = email
        self.telegramId = telegramId
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        telegramId = try container.decodeIfPresent(String.self, forKey: .telegramId)
        role = (try? container.decode(String.self, forKey: .role)) ?? "trader"
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = (try? container.decode(String.self, forKey: .updatedAt)) ?? createdAt
    }
}

// MARK: - 数据源状态
struct DataSourceStatus: Codable, Hashable {
    let source: String
    let simulated: Bool
    let available: Bool
    let detail: String?
}

// MARK: - 策略
struct Strategy: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let name: String
    let type: StrategyType
    let parameters: [String: AnyCodable]
    let source: StrategySource
    let market: String
    let exchange: String
    let version: Int
    var status: StrategyStatus
    let sharpeRatio: Double?
    let maxDrawdown: Double?
    let freqtradeStrategyId: String?
    var tags: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, parameters, source, market, exchange, version, status
        case userId = "user_id"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case freqtradeStrategyId = "freqtrade_strategy_id"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 订单
struct Order: Codable, Identifiable, Hashable {
    let id: Int
    let strategyId: Int
    let symbol: String
    let side: OrderSide
    let orderType: OrderType
    let quantity: Double
    let price: Double?
    let filledPrice: Double?
    let fee: Double
    let slippage: Double
    let timestamp: String
    let status: OrderStatus
    let profit: Double?
    let pnlPct: Double?
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, quantity, price, fee, slippage, timestamp, status, profit
        case strategyId = "strategy_id"
        case orderType = "order_type"
        case filledPrice = "filled_price"
        case pnlPct = "pnl_pct"
        case dataSource = "data_source"
    }
}

// MARK: - 持仓
struct Position: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let strategyId: Int?
    let symbol: String
    let side: PositionSide
    let quantity: Double
    let avgPrice: Double
    let unrealizedPnl: Double
    let stopLossPrice: Double?
    let takeProfitPrice: Double?
    let status: PositionStatus
    let openedAt: String
    let closedAt: String?
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, quantity, status
        case userId = "user_id"
        case strategyId = "strategy_id"
        case avgPrice = "avg_price"
        case unrealizedPnl = "unrealized_pnl"
        case stopLossPrice = "stop_loss_price"
        case takeProfitPrice = "take_profit_price"
        case openedAt = "opened_at"
        case closedAt = "closed_at"
        case dataSource = "data_source"
    }
}

// MARK: - 权益曲线点
struct EquityPoint: Codable, Identifiable, Hashable {
    let id = UUID()
    let date: String
    let value: Double
    let drawdown: Double
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case date, value, drawdown
        case dataSource = "data_source"
    }
}

// MARK: - 回测指标
struct BacktestMetrics: Codable, Hashable {
    let totalReturn: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let profitFactor: Double
    let totalTrades: Int
    let avgTradeDuration: String
    let bestTrade: Double
    let worstTrade: Double

    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case winRate = "win_rate"
        case profitFactor = "profit_factor"
        case totalTrades = "total_trades"
        case avgTradeDuration = "avg_trade_duration"
        case bestTrade = "best_trade"
        case worstTrade = "worst_trade"
    }
}

// MARK: - 回测配置
struct BacktestConfig: Codable, Hashable {
    let startDate: String
    let endDate: String
    let initialCapital: Double
    let symbols: [String]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case initialCapital = "initial_capital"
        case symbols
    }
}

// MARK: - 回测结果
struct BacktestResult: Codable, Hashable {
    let equityCurve: [EquityPoint]
    let trades: [Order]
    let metrics: BacktestMetrics

    enum CodingKeys: String, CodingKey {
        case equityCurve = "equity_curve"
        case trades, metrics
    }
}

// MARK: - 回测
struct Backtest: Codable, Identifiable, Hashable {
    let id: Int
    let strategyId: Int
    let config: BacktestConfig
    let result: BacktestResult
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let totalReturn: Double
    let passed: Bool
    let createdAt: String
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case id, config, result, passed
        case strategyId = "strategy_id"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case winRate = "win_rate"
        case totalReturn = "total_return"
        case createdAt = "created_at"
        case dataSource = "data_source"
    }
}

// MARK: - 仪表盘 KPI
struct DashboardKPIs: Codable, Hashable {
    let totalPnl: Double
    let pnlChangePct: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let activeStrategies: Int
    let todaysTrades: Int
    let openPositions: Int
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case totalPnl = "total_pnl"
        case pnlChangePct = "pnl_change_pct"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case winRate = "win_rate"
        case activeStrategies = "active_strategies"
        case todaysTrades = "todays_trades"
        case openPositions = "open_positions"
        case dataSource = "data_source"
    }
}

// MARK: - 系统状态
struct SystemStatus: Codable, Hashable {
    let uptime: String
    let activeStrategies: Int
    let openPositions: Int
    let pendingOrders: Int
    let lastDataUpdate: String
    let apiStatus: APIStatus
    let dataSource: DataSourceStatus?

    enum CodingKeys: String, CodingKey {
        case uptime
        case activeStrategies = "active_strategies"
        case openPositions = "open_positions"
        case pendingOrders = "pending_orders"
        case lastDataUpdate = "last_data_update"
        case apiStatus = "api_status"
        case dataSource = "data_source"
    }
}

// MARK: - 系统指标
struct SystemMetrics: Codable, Hashable {
    let cpuPercent: Double
    let memoryPercent: Double
    let networkLatencyMs: Double
    let uptime: String
    let activeStrategies: Int
    let openPositions: Int

    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memoryPercent = "memory_percent"
        case networkLatencyMs = "network_latency_ms"
        case uptime
        case activeStrategies = "active_strategies"
        case openPositions = "open_positions"
    }
}

// MARK: - 风险事件
struct RiskEvent: Codable, Identifiable, Hashable {
    let id: Int
    let eventType: RiskEventType
    let strategyId: Int?
    let severity: RiskSeverity
    let description: String?
    let actionTaken: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, severity, description
        case eventType = "event_type"
        case strategyId = "strategy_id"
        case actionTaken = "action_taken"
        case createdAt = "created_at"
    }
}

// MARK: - 相关性快照
struct CorrelationSnapshot: Codable, Identifiable, Hashable {
    let id: Int
    let symbolA: String
    let symbolB: String
    let correlation: Double
    let windowDays: Int
    let alertLevel: AlertLevel?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, correlation
        case symbolA = "symbol_a"
        case symbolB = "symbol_b"
        case windowDays = "window_days"
        case alertLevel = "alert_level"
        case createdAt = "created_at"
    }
}

// MARK: - 用户设置
struct UserSettings: Codable, Hashable {
    let id: Int?
    let userId: Int?
    var theme: String?
    var language: String?
    var notificationsEnabled: Bool?
    var defaultExchange: String?
    var defaultMarket: String?
    var riskTolerance: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case theme, language
        case notificationsEnabled = "notifications_enabled"
        case defaultExchange = "default_exchange"
        case defaultMarket = "default_market"
        case riskTolerance = "risk_tolerance"
    }
}

// MARK: - 认证响应
struct TokenResponse: Codable, Hashable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

// MARK: - AI 研究运行
struct AIResearchRun: Codable, Identifiable, Hashable {
    let id: Int
    let symbol: String
    let assetType: String
    let analysisDate: String
    let provider: String
    let status: String
    let rating: String?
    let finalDecision: String?
    let marketReport: String?
    let sentimentReport: String?
    let newsReport: String?
    let fundamentalsReport: String?
    let errorMessage: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, symbol, provider, status, rating
        case assetType = "asset_type"
        case analysisDate = "analysis_date"
        case finalDecision = "final_decision"
        case marketReport = "market_report"
        case sentimentReport = "sentiment_report"
        case newsReport = "news_report"
        case fundamentalsReport = "fundamentals_report"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}

// MARK: - Agent Profile
struct AgentProfile: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let kind: String
    let status: String
    let description: String?
    let lastHeartbeatAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, kind, status, description
        case lastHeartbeatAt = "last_heartbeat_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Agent Signal
struct AgentSignal: Codable, Identifiable, Hashable {
    let id: Int
    let agentId: Int
    let source: String
    let messageType: String
    let symbol: String
    let market: String
    let direction: String?
    let rating: String?
    let confidence: Double?
    let targetPrice: Double?
    let stopLoss: Double?
    let content: String
    let overallScore: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, symbol, market, direction, rating, confidence, content
        case agentId = "agent_id"
        case messageType = "message_type"
        case source
        case targetPrice = "target_price"
        case stopLoss = "stop_loss"
        case overallScore = "overall_score"
        case createdAt = "created_at"
    }
}

// MARK: - AnyCodable 包装器（处理 JSON 中的任意值）
struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value as? Int { try container.encode(v) }
        else if let v = value as? Double { try container.encode(v) }
        else if let v = value as? String { try container.encode(v) }
        else if let v = value as? Bool { try container.encode(v) }
    }

    func hash(into hasher: inout Hasher) {
        if let v = value as? AnyHashable { hasher.combine(v) }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        guard let l = lhs.value as? AnyHashable, let r = rhs.value as? AnyHashable else { return false }
        return l == r
    }
}
