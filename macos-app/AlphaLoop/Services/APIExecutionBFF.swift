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

// MARK: - Action Response Types

struct CancelActionResponse: Codable {
    let cancelledOrderId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case cancelledOrderId = "cancelled_order_id"
        case status
    }
}

struct CloseActionResponse: Codable {
    let closedPositionId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case closedPositionId = "closed_position_id"
        case status
    }
}

struct BatchActionResponse: Codable {
    let affectedCount: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case affectedCount = "affected_count"
        case status
    }
}

struct RetryActionResponse: Codable {
    let status: String
    let runId: String?
    let affectedCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case runId = "run_id"
        case affectedCount = "affected_count"
    }
}

// MARK: - API Service

struct APIExecutionBFF {
    let client: NetworkClientProtocol

    func getCenter() async throws -> ExecutionCenterBFFResponse {
        try await client.get("/api/execution/center")
    }

    func getOrdersPositions() async throws -> OrdersPositionsBFFResponse {
        try await client.get("/api/execution/orders")
    }

    func getReconciliationBus() async throws -> ReconciliationBusBFFResponse {
        try await client.get("/api/reconciliation/bus")
    }

    func cancelOrder(id: String) async throws -> CancelActionResponse {
        try await client.post("/api/execution/orders/\(id)/cancel", body: nil)
    }

    func closePosition(id: String) async throws -> CloseActionResponse {
        try await client.post("/api/execution/positions/\(id)/close", body: nil)
    }

    func cancelAllOrders() async throws -> BatchActionResponse {
        try await client.post("/api/execution/orders/cancel-all", body: nil)
    }

    func forceCloseAllPositions() async throws -> BatchActionResponse {
        try await client.post("/api/execution/positions/force-close-all", body: nil)
    }

    func retryReconciliationRun(id: String) async throws -> RetryActionResponse {
        try await client.post("/api/reconciliation/runs/\(id)/retry", body: nil)
    }

    func retryReconciliationBatch() async throws -> RetryActionResponse {
        try await client.post("/api/reconciliation/retry", body: nil)
    }
}

// MARK: - Mock

