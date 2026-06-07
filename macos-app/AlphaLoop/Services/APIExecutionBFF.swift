// APIExecutionBFF.swift — Execution BFF API

import Foundation

// MARK: - Response Types

struct ExecutionSessionResponse: Codable, Identifiable {
    var id: String { runId }
    let runId: String
    var strategyName: String = ""
    var mode: String = ""
    var status: String = "stopped"
    var symbol: String = ""
    var openPositions: Int = 0
    var pendingOrders: Int = 0
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case mode, status, symbol
        case runId = "run_id"
        case strategyName = "strategy_name"
        case openPositions = "open_positions"
        case pendingOrders = "pending_orders"
        case reasonCodes = "reason_codes"
    }
}

struct ExecutionCenterBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var sessions: [ExecutionSessionResponse] = []
    var totalRunning: Int = 0
    var totalOpenPositions: Int = 0
    var totalPendingOrders: Int = 0
    var freqtradeHeartbeat: String = "unknown"
    var executionLatencyMs: Int = 0

    enum CodingKeys: String, CodingKey {
        case state, sessions
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case totalRunning = "total_running"
        case totalOpenPositions = "total_open_positions"
        case totalPendingOrders = "total_pending_orders"
        case freqtradeHeartbeat = "freqtrade_heartbeat"
        case executionLatencyMs = "execution_latency_ms"
    }
}

struct OrderBFFResponse: Codable, Identifiable {
    let id: String
    let symbol: String
    let side: String
    let type: String
    var quantity: Double = 0
    var price: Double?
    var status: String = "pending"
    var exchangeOrderId: String?
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, type, quantity, price, status
        case exchangeOrderId = "exchange_order_id"
        case reasonCodes = "reason_codes"
    }
}

struct PositionBFFResponse: Codable, Identifiable {
    let id: String
    let symbol: String
    let side: String
    var avgEntryPrice: Double = 0
    var currentPrice: Double = 0
    var quantity: Double = 0
    var unrealizedPnl: Double = 0
    var unrealizedPnlPct: Double = 0
    var stopLoss: Double?
    var stateDifference: String?
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, quantity
        case avgEntryPrice = "avg_entry_price"
        case currentPrice = "current_price"
        case unrealizedPnl = "unrealized_pnl"
        case unrealizedPnlPct = "unrealized_pnl_pct"
        case stopLoss = "stop_loss"
        case stateDifference = "state_difference"
        case reasonCodes = "reason_codes"
    }
}

struct OrdersPositionsBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var orders: [OrderBFFResponse] = []
    var positions: [PositionBFFResponse] = []

    enum CodingKeys: String, CodingKey {
        case state, orders, positions
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
    }
}

struct ReconciliationBusBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var recentCommands: [CommandBusEventResponse] = []
    var reconciliationRuns: [ReconciliationRunResponse] = []

    enum CodingKeys: String, CodingKey {
        case state
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case recentCommands = "recent_commands"
        case reconciliationRuns = "reconciliation_runs"
    }
}

struct CommandBusEventResponse: Codable, Identifiable {
    let id: String
    var commandType: String = ""
    var status: String = ""

    enum CodingKeys: String, CodingKey {
        case id, status
        case commandType = "command_type"
    }
}

struct ReconciliationRunResponse: Codable, Identifiable {
    let id: String
    var status: String = "pending"
    var discrepancies: Int = 0
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, status, discrepancies
        case reasonCodes = "reason_codes"
    }
}

// MARK: - API Service

struct APIExecutionBFF {
    let client: NetworkClientProtocol

    func getCenter() async throws -> ExecutionCenterBFFResponse {
        try await client.get("/api/execution/center", mock: MockExecutionBFF.center)
    }

    func getOrdersPositions() async throws -> OrdersPositionsBFFResponse {
        try await client.get("/api/execution/orders", mock: MockExecutionBFF.ordersPositions)
    }

    func getReconciliationBus() async throws -> ReconciliationBusBFFResponse {
        try await client.get("/api/reconciliation/bus", mock: MockExecutionBFF.reconciliationBus)
    }
}

// MARK: - Mock

enum MockExecutionBFF {
    static func center() -> ExecutionCenterBFFResponse {
        ExecutionCenterBFFResponse(
            state: "running",
            availableActions: [AvailableActionResponse(type: "emergency_stop", enabled: true, label: "紧急停止", confirmRequired: true)],
            sessions: [
                ExecutionSessionResponse(runId: "run-001", strategyName: "BTC Structure Scalp", mode: "live_small", status: "running", symbol: "BTC/USDT", openPositions: 2, pendingOrders: 1),
                ExecutionSessionResponse(runId: "run-002", strategyName: "ETH FVG Hunter", mode: "dryrun", status: "running", symbol: "ETH/USDT", openPositions: 1),
            ],
            totalRunning: 2, totalOpenPositions: 3, totalPendingOrders: 1,
            freqtradeHeartbeat: "healthy", executionLatencyMs: 45
        )
    }

    static func ordersPositions() -> OrdersPositionsBFFResponse {
        OrdersPositionsBFFResponse(
            orders: [OrderBFFResponse(id: "ord-001", symbol: "BTC/USDT", side: "buy", type: "limit", quantity: 0.01, price: 61500, status: "pending", exchangeOrderId: "ex-12345")],
            positions: [
                PositionBFFResponse(id: "pos-001", symbol: "BTC/USDT", side: "long", avgEntryPrice: 62100, currentPrice: 62450, quantity: 0.05, unrealizedPnl: 17.5, unrealizedPnlPct: 0.56, stopLoss: 61200),
                PositionBFFResponse(id: "pos-002", symbol: "ETH/USDT", side: "long", avgEntryPrice: 3380, currentPrice: 3410, quantity: 1.0, unrealizedPnl: 30, unrealizedPnlPct: 0.89, stopLoss: 3320),
            ]
        )
    }

    static func reconciliationBus() -> ReconciliationBusBFFResponse {
        ReconciliationBusBFFResponse(
            availableActions: [
                AvailableActionResponse(type: "refresh_exchange_state", enabled: true, label: "刷新交易所状态"),
            ],
            recentCommands: [
                CommandBusEventResponse(id: "cmd-001", commandType: "start_dryrun", status: "completed"),
                CommandBusEventResponse(id: "cmd-002", commandType: "place_order", status: "completed"),
            ],
            reconciliationRuns: [
                ReconciliationRunResponse(id: "recon-001", status: "completed", discrepancies: 0),
            ]
        )
    }
}
