// BacktestTypes.swift — Backtest/dryrun response models (extracted from Types.swift)

import Foundation

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
