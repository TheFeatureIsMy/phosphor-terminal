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
    // let type: StrategyType deprecated, use tags instead
    let parameters: [String: AnyCodable]
    let source: StrategySource
    let market: String
    let exchange: String
    let version: Int
    var status: StrategyStatus
    let sharpeRatio: Double?
    let maxDrawdown: Double?
    var tags: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, parameters, source, market, exchange, version, status
        case userId = "user_id"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
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
        else if let array = try? container.decode([AnyCodable].self) { value = array.map(\.value) }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues(\.value) }
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


// MARK: - Strategy v2.5

struct StrategyV2: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let strategyType: String
    let sourceType: String
    var status: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case strategyType = "strategy_type"
        case sourceType = "source_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusLabel: String {
        switch status {
        case "draft": return "草稿"
        case "active": return "运行中"
        case "paused": return "已暂停"
        case "archived": return "已归档"
        default: return status
        }
    }
}

struct StrategyVersionV2: Codable, Identifiable, Hashable {
    let id: String
    let strategyId: String
    let versionNo: Int
    let status: String
    let dslVersion: String
    let ruleDsl: [String: AnyCodable]
    let dslHash: String
    let createdBy: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case strategyId = "strategy_id"
        case versionNo = "version_no"
        case dslVersion = "dsl_version"
        case ruleDsl = "rule_dsl"
        case dslHash = "dsl_hash"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct DSLValidationError: Codable, Identifiable, Hashable {
    var id: String { "\(code):\(path)" }
    let code: String
    let path: String
    let message: String
    let severity: String
}

struct DSLValidationReport: Codable, Hashable {
    let valid: Bool
    let errorCount: Int
    let warningCount: Int
    let safeHoldRequired: Bool
    let safeHoldReasons: [String]
    let errors: [DSLValidationError]
    let warnings: [DSLValidationError]

    enum CodingKeys: String, CodingKey {
        case valid, errors, warnings
        case errorCount = "error_count"
        case warningCount = "warning_count"
        case safeHoldRequired = "safe_hold_required"
        case safeHoldReasons = "safe_hold_reasons"
    }
}

// MARK: - Backtest v2.5 strong-typed sub-models

struct BacktestEquityPoint: Codable, Identifiable, Hashable {
    let timestamp: String
    let equity: Double
    let drawdown: Double
    var id: String { timestamp }
}

struct TradeRow: Codable, Identifiable, Hashable {
    let openTime: String
    let closeTime: String
    let pair: String
    let side: String
    let openPrice: Double
    let closePrice: Double
    let quantity: Double
    let profit: Double
    let duration: String
    let mtfState: String?
    var id: String { "\(openTime)-\(pair)-\(side)" }

    enum CodingKeys: String, CodingKey {
        case openTime = "open_time"
        case closeTime = "close_time"
        case pair, side
        case openPrice = "open_price"
        case closePrice = "close_price"
        case quantity, profit, duration
        case mtfState = "mtf_state"
    }
}

struct FailureClusterSummary: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let sampleSize: Int
    let totalLoss: Double
    let avgLoss: Double
    let commonFeatures: [String]

    enum CodingKeys: String, CodingKey {
        case id, label
        case sampleSize = "sample_size"
        case totalLoss = "total_loss"
        case avgLoss = "avg_loss"
        case commonFeatures = "common_features"
    }
}

// MARK: - Backtest v2.5 (Command Bus)

struct BacktestCommandResponse: Codable, Hashable {
    let commandId: String
    let status: String
    let message: String
    let idempotencyKey: String

    enum CodingKeys: String, CodingKey {
        case status, message
        case commandId = "command_id"
        case idempotencyKey = "idempotency_key"
    }
}

struct BacktestRunV2: Codable, Identifiable, Hashable {
    let id: Int
    let strategyId: Int
    let strategyVersionId: String?
    let commandId: String?
    let dslHash: String?
    let status: String
    let startDate: String
    let endDate: String
    let initialCapital: Double
    let symbols: [String]
    let config: [String: AnyCodable]
    var result: [String: AnyCodable]
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let totalReturn: Double
    let profitFactor: Double
    let totalTrades: Int
    let errorMessage: String?
    let createdAt: String?
    let completedAt: String?
    var equityCurve: [BacktestEquityPoint] = []
    var trades: [TradeRow] = []

    enum CodingKeys: String, CodingKey {
        case id, status, symbols, config, result
        case strategyId = "strategy_id"
        case strategyVersionId = "strategy_version_id"
        case commandId = "command_id"
        case dslHash = "dsl_hash"
        case startDate = "start_date"
        case endDate = "end_date"
        case initialCapital = "initial_capital"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case winRate = "win_rate"
        case totalReturn = "total_return"
        case profitFactor = "profit_factor"
        case totalTrades = "total_trades"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case equityCurve = "equity_curve"
        case trades
    }

    // Memberwise init for programmatic construction (e.g., mock factories)
    internal init(
        id: Int, strategyId: Int, strategyVersionId: String? = nil,
        commandId: String? = nil, dslHash: String? = nil,
        status: String, startDate: String, endDate: String,
        initialCapital: Double, symbols: [String],
        config: [String: AnyCodable] = [:],
        result: [String: AnyCodable] = [:],
        sharpeRatio: Double = 0, maxDrawdown: Double = 0,
        winRate: Double = 0, totalReturn: Double = 0,
        profitFactor: Double = 0, totalTrades: Int = 0,
        errorMessage: String? = nil, createdAt: String? = nil,
        completedAt: String? = nil,
        equityCurve: [BacktestEquityPoint] = [],
        trades: [TradeRow] = []
    ) {
        self.id = id
        self.strategyId = strategyId
        self.strategyVersionId = strategyVersionId
        self.commandId = commandId
        self.dslHash = dslHash
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.initialCapital = initialCapital
        self.symbols = symbols
        self.config = config
        self.result = result
        self.sharpeRatio = sharpeRatio
        self.maxDrawdown = maxDrawdown
        self.winRate = winRate
        self.totalReturn = totalReturn
        self.profitFactor = profitFactor
        self.totalTrades = totalTrades
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.equityCurve = equityCurve
        self.trades = trades
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        strategyId = try c.decode(Int.self, forKey: .strategyId)
        strategyVersionId = try c.decodeIfPresent(String.self, forKey: .strategyVersionId)
        commandId = try c.decodeIfPresent(String.self, forKey: .commandId)
        dslHash = try c.decodeIfPresent(String.self, forKey: .dslHash)
        status = try c.decode(String.self, forKey: .status)
        startDate = try c.decode(String.self, forKey: .startDate)
        endDate = try c.decode(String.self, forKey: .endDate)
        initialCapital = try c.decode(Double.self, forKey: .initialCapital)
        symbols = (try? c.decode([String].self, forKey: .symbols)) ?? []
        config = (try? c.decode([String: AnyCodable].self, forKey: .config)) ?? [:]
        result = (try? c.decode([String: AnyCodable].self, forKey: .result)) ?? [:]
        sharpeRatio = (try? c.decode(Double.self, forKey: .sharpeRatio)) ?? 0
        maxDrawdown = (try? c.decode(Double.self, forKey: .maxDrawdown)) ?? 0
        winRate = (try? c.decode(Double.self, forKey: .winRate)) ?? 0
        totalReturn = (try? c.decode(Double.self, forKey: .totalReturn)) ?? 0
        profitFactor = (try? c.decode(Double.self, forKey: .profitFactor)) ?? 0
        totalTrades = (try? c.decode(Int.self, forKey: .totalTrades)) ?? 0
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)

        // Try top-level equity_curve/trades first
        let topEquity = try? c.decode([BacktestEquityPoint].self, forKey: .equityCurve)
        let topTrades = try? c.decode([TradeRow].self, forKey: .trades)

        // Fallback: extract from result dict
        if let topEquity, !topEquity.isEmpty {
            equityCurve = topEquity
        } else if let raw = result["equity_curve"]?.value as? [[String: Any]] {
            equityCurve = raw.compactMap { dict in
                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return try? JSONDecoder().decode(BacktestEquityPoint.self, from: data)
            }
        }

        if let topTrades, !topTrades.isEmpty {
            trades = topTrades
        } else if let raw = result["trades"]?.value as? [[String: Any]] {
            trades = raw.compactMap { dict in
                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return try? JSONDecoder().decode(TradeRow.self, from: data)
            }
        }
    }
}

struct BacktestStatusV2: Codable, Hashable {
    let commandId: String
    let commandStatus: String
    let backtestRun: BacktestRunV2?
    let errorCode: String?
    let errorMessage: String?

    // Memberwise init for programmatic construction (e.g., mock factories)
    internal init(
        commandId: String,
        commandStatus: String,
        backtestRun: BacktestRunV2? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.commandId = commandId
        self.commandStatus = commandStatus
        self.backtestRun = backtestRun
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    enum CodingKeys: String, CodingKey {
        case backtestRun
        case commandId = "command_id"
        case commandStatus = "command_status"
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }

    // workaround: backend sends backtest_run as snake_case
    private enum AlternateKeys: String, CodingKey {
        case backtestRun = "backtest_run"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandId = try container.decode(String.self, forKey: .commandId)
        commandStatus = try container.decode(String.self, forKey: .commandStatus)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)

        // Try camelCase first, then snake_case
        if let run = try? container.decodeIfPresent(BacktestRunV2.self, forKey: .backtestRun) {
            backtestRun = run
        } else {
            let alt = try decoder.container(keyedBy: AlternateKeys.self)
            backtestRun = try alt.decodeIfPresent(BacktestRunV2.self, forKey: .backtestRun)
        }
    }
}

// MARK: - Signal Center v2

struct SignalV2: Codable, Identifiable, Hashable {
    let id: String
    let sourceType: String
    let symbol: String
    let direction: String
    let confidence: Double
    let score: Double?
    let riskLevel: String
    let status: String
    let expiresAt: String
    let createdAt: String
    var reasoning: String?
    var canLiveTrade: Bool?
    var triggerCondition: AnyCodable?
    var currentState: AnyCodable?
    var evidence: [AnyCodable]?
    var lifecycleEvents: [AnyCodable]?
    var providerTrace: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case id, symbol, direction, confidence, score, status, reasoning, evidence
        case sourceType = "source_type"
        case riskLevel = "risk_level"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case canLiveTrade = "can_live_trade"
        case triggerCondition = "trigger_condition"
        case currentState = "current_state"
        case lifecycleEvents = "lifecycle_events"
        case providerTrace = "provider_trace"
    }
}

struct SignalConflictResult: Codable {
    let hasConflict: Bool
    let conflictingSignals: [SignalV2]

    enum CodingKeys: String, CodingKey {
        case hasConflict = "has_conflict"
        case conflictingSignals = "conflicting_signals"
    }
}

struct SignalAggregateResult: Codable {
    let groups: [AnyCodable]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case groups
        case totalCount = "total_count"
    }
}

// MARK: - Strategy Runs

struct StrategyRunV2: Codable, Identifiable, Hashable {
    let id: String
    let strategyVersionId: String
    let mode: String
    let status: String
    let startedAt: String?
    let stoppedAt: String?
    let createdAt: String
    var configSnapshot: AnyCodable?
    var resultSummary: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case id, mode, status
        case strategyVersionId = "strategy_version_id"
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case createdAt = "created_at"
        case configSnapshot = "config_snapshot"
        case resultSummary = "result_summary"
    }
}

// MARK: - Dry-run

struct DryRunCommandResponse: Codable {
    let commandId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case status
    }
}

struct DryRunStatusV2: Codable {
    let commandId: String
    let status: String
    let result: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case status, result
    }
}

// MARK: - Inference

struct InferenceJob: Codable, Identifiable, Hashable {
    let id: String
    let jobType: String
    let modelName: String
    let status: String
    let submittedAt: String
    let startedAt: String?
    let completedAt: String?
    let errorMessage: String?
    let estimatedCostUsd: Double?
    let actualCostUsd: Double?

    enum CodingKeys: String, CodingKey {
        case id, status
        case jobType = "job_type"
        case modelName = "model_name"
        case submittedAt = "submitted_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case errorMessage = "error_message"
        case estimatedCostUsd = "estimated_cost_usd"
        case actualCostUsd = "actual_cost_usd"
    }
}

struct RuntimeStateInfo: Codable {
    let modelName: String
    let provider: String
    let state: String
    let gpuMemoryMb: Int?
    let lastHeartbeatAt: String?

    enum CodingKeys: String, CodingKey {
        case provider, state
        case modelName = "model_name"
        case gpuMemoryMb = "gpu_memory_mb"
        case lastHeartbeatAt = "last_heartbeat_at"
    }
}

// MARK: - Growth Engine

struct GrowthReport: Codable, Identifiable, Hashable {
    let id: String
    let reportType: String
    let status: String
    let summary: AnyCodable?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, summary
        case reportType = "report_type"
        case createdAt = "created_at"
    }
}

struct StrategyCandidate: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let confidence: Double?
    let createdAt: String
    var dsl: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case id, status, confidence, dsl
        case createdAt = "created_at"
    }
}

// MARK: - Manipulation Radar

struct ManipulationScoreV2: Codable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let manipulationScore: Double
    let stopHuntScore: Double?
    let holderConcentrationScore: Double?
    let liquidityTrapScore: Double?
    let pumpDumpScore: Double?
    let fundingSqueezeScore: Double?
    let riskLevel: String
    let suggestion: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, symbol, suggestion
        case manipulationScore = "manipulation_score"
        case stopHuntScore = "stop_hunt_score"
        case holderConcentrationScore = "holder_concentration_score"
        case liquidityTrapScore = "liquidity_trap_score"
        case pumpDumpScore = "pump_dump_score"
        case fundingSqueezeScore = "funding_squeeze_score"
        case riskLevel = "risk_level"
        case updatedAt = "updated_at"
    }
}

// MARK: - MCP

struct McpStatusInfo: Codable {
    let enabled: Bool
    let bindAddress: String
    let totalRequests: Int
    let lastRequestAt: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case bindAddress = "bind_address"
        case totalRequests = "total_requests"
        case lastRequestAt = "last_request_at"
    }
}

struct McpAuditLogEntry: Codable, Identifiable, Hashable {
    let id: String
    let toolName: String
    let responseStatus: Int
    let latencyMs: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case toolName = "tool_name"
        case responseStatus = "response_status"
        case latencyMs = "latency_ms"
        case createdAt = "created_at"
    }
}

struct McpTokenRotateResult: Codable {
    let newToken: String
    let oldTokenRevoked: Bool

    enum CodingKeys: String, CodingKey {
        case newToken = "new_token"
        case oldTokenRevoked = "old_token_revoked"
    }
}

// MARK: - Emergency

struct EmergencyStopResult: Codable {
    let stoppedRuns: [String]
    let message: String

    enum CodingKeys: String, CodingKey {
        case stoppedRuns = "stopped_runs"
        case message
    }
}

// MARK: - Live Small

struct LiveSmallPrecondition: Codable, Hashable {
    let gateName: String
    let passed: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case passed, message
        case gateName = "gate_name"
    }
}

struct LiveSmallEvaluation: Codable {
    let canExecute: Bool
    let requiresHumanConfirm: Bool
    let preconditions: [LiveSmallPrecondition]?
    let riskSummary: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case preconditions
        case canExecute = "can_execute"
        case requiresHumanConfirm = "requires_human_confirm"
        case riskSummary = "risk_summary"
    }
}

// MARK: - Data Vacuum

struct DataVacuumJob: Codable, Identifiable {
    let id: String
    let status: String
    let signalsScanned: Int?
    let signalsArchived: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case signalsScanned = "signals_scanned"
        case signalsArchived = "signals_archived"
        case createdAt = "created_at"
    }
}

// MARK: - Strategy Workbench (canvas-first)
// 1:1 with backend app/schemas/strategy_workspace.py + per_strategy_readiness.py + strategy_binding.py
// Spec §6.1.A / §6.4

struct RiskPolicySummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let versionNo: Int
    let policyJsonSummary: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case id, name
        case versionNo = "version_no"
        case policyJsonSummary = "policy_json_summary"
    }
}

struct CapitalPoolSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let poolType: String
    let totalBudget: Double
    let currency: String
    let remainingBudget: Double

    enum CodingKeys: String, CodingKey {
        case id, name, currency
        case poolType = "pool_type"
        case totalBudget = "total_budget"
        case remainingBudget = "remaining_budget"
    }
}

struct StrategyBinding: Codable, Identifiable, Hashable {
    let id: String
    let strategyVersionId: String
    let versionNo: Int
    let riskPolicy: RiskPolicySummary
    let capitalPool: CapitalPoolSummary
    let mode: String                // backtest | dry_run | shadow | live_small
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, mode
        case strategyVersionId = "strategy_version_id"
        case versionNo = "version_no"
        case riskPolicy = "risk_policy"
        case capitalPool = "capital_pool"
        case createdAt = "created_at"
    }
}

struct BacktestRunSummary: Codable, Identifiable, Hashable {
    let id: Int
    let startedAt: String?
    let completedAt: String?
    let status: String
    let totalReturn: Double?
    let winRate: Double?
    let maxDrawdown: Double?
    let sharpeRatio: Double?

    enum CodingKeys: String, CodingKey {
        case id, status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case totalReturn = "total_return"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
    }
}

struct StrategyRunSummary: Codable, Identifiable, Hashable {
    let id: String
    let mode: String
    let status: String
    let startedAt: String?
    let stoppedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, mode, status
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case createdAt = "created_at"
    }
}

struct ActivityEntryRef: Codable, Hashable {
    let kind: String                // version | binding | run | backtest
    let id: String
}

struct ActivityEntry: Codable, Identifiable, Hashable {
    let id: String
    let kind: String                // version_created | version_status_changed | binding_added | …
    let occurredAt: String
    let actor: String?
    let summary: String
    let delta: [String: AnyCodable]?
    let ref: ActivityEntryRef?

    enum CodingKeys: String, CodingKey {
        case id, kind, actor, summary, delta, ref
        case occurredAt = "occurred_at"
    }
}

struct ReadinessGate: Codable, Identifiable, Hashable {
    var id: String { key }
    let key: String
    let status: String              // healthy | warning | failed | unknown
    let value: String
    let threshold: String
    let detail: String
    let reasonCodes: [String]

    enum CodingKeys: String, CodingKey {
        case key, status, value, threshold, detail
        case reasonCodes = "reason_codes"
    }
}

struct ReadinessNextAction: Codable, Hashable {
    let code: String                // gate-specific code
    let label: String
    let targetPanel: String?        // "risk" | "backtest" | "readiness" | nil

    enum CodingKeys: String, CodingKey {
        case code, label
        case targetPanel = "target_panel"
    }
}

struct PerStrategyReadiness: Codable, Hashable {
    let passedCount: Int
    let total: Int
    let grandStatus: String         // not_live | needs_config | needs_validation | paper_passed | ready_for_live
    let nextAction: ReadinessNextAction
    let strategyGates: [ReadinessGate]
    let systemGates: [ReadinessGate]

    enum CodingKeys: String, CodingKey {
        case total
        case passedCount = "passed_count"
        case grandStatus = "grand_status"
        case nextAction = "next_action"
        case strategyGates = "strategy_gates"
        case systemGates = "system_gates"
    }
}

struct SignalLogicSummary: Codable, Hashable {
    let entryText: String
    let exitText: String
    let filterCount: Int

    enum CodingKeys: String, CodingKey {
        case entryText = "entry_text"
        case exitText = "exit_text"
        case filterCount = "filter_count"
    }
}

struct DataDependencies: Codable, Hashable {
    let symbols: [String]
    let timeframes: [String]
    let indicators: [String]
    let signalSources: [String]

    enum CodingKeys: String, CodingKey {
        case symbols, timeframes, indicators
        case signalSources = "signal_sources"
    }
}

struct WorkspaceSnapshot: Codable, Hashable {
    let strategy: StrategyV2
    let versions: [StrategyVersionV2]
    let latestVersionId: String?
    let bindings: [StrategyBinding]
    let recentBacktests: [BacktestRunSummary]
    let recentDryruns: [StrategyRunSummary]
    let readiness: PerStrategyReadiness
    let activity: [ActivityEntry]
    let signalLogicSummary: SignalLogicSummary
    let dataDependencies: DataDependencies

    enum CodingKeys: String, CodingKey {
        case strategy, versions, bindings, readiness, activity
        case latestVersionId = "latest_version_id"
        case recentBacktests = "recent_backtests"
        case recentDryruns = "recent_dryruns"
        case signalLogicSummary = "signal_logic_summary"
        case dataDependencies = "data_dependencies"
    }
}
