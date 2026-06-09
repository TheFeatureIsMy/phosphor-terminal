// APIWorkflow.swift — Daily Trading Loop Workflow API

import Foundation

struct WorkflowStep: Codable, Identifiable, Hashable {
    var id: String { step }
    let step: String
    let status: String
    let title: String
    let question: String
    let summary: String
    let count: Int?
    let blockingReasons: [String]
    let availableActions: [WorkflowAction]
    let jumpTarget: String

    enum CodingKeys: String, CodingKey {
        case step, status, title, question, summary, count
        case blockingReasons = "blocking_reasons"
        case availableActions = "available_actions"
        case jumpTarget = "jump_target"
    }
}

struct WorkflowAction: Codable, Hashable {
    let type: String
    let enabled: Bool
    let label: String
}

struct DailyWorkflow: Codable {
    let workflowId: String
    let date: String
    let globalState: String
    let currentStep: String
    let steps: [WorkflowStep]

    enum CodingKeys: String, CodingKey {
        case workflowId = "workflow_id"
        case date
        case globalState = "global_state"
        case currentStep = "current_step"
        case steps
    }
}

struct TradeSourceTrace: Codable {
    let tradeId: String
    let trace: TraceData
    let availableActions: [WorkflowAction]

    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id"
        case trace
        case availableActions = "available_actions"
    }
}

struct TraceData: Codable {
    let signal: TraceSignal?
    let strategy: TraceStrategy?
    let runtimeSnapshot: TraceSnapshot?
    let riskDecision: TraceRiskDecision?
    let execution: TraceExecution?

    enum CodingKeys: String, CodingKey {
        case signal, strategy
        case runtimeSnapshot = "runtime_snapshot"
        case riskDecision = "risk_decision"
        case execution
    }
}

struct TraceSignal: Codable {
    let signalId: String?
    let sourceType: String?
    let direction: String?
    let confidence: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case signalId = "signal_id"
        case sourceType = "source_type"
        case direction, confidence, status
    }
}

struct TraceStrategy: Codable {
    let strategyId: String?
    let strategyName: String?
    let versionId: String?
    let versionNo: Int?
    let dslVersion: String?

    enum CodingKeys: String, CodingKey {
        case strategyId = "strategy_id"
        case strategyName = "strategy_name"
        case versionId = "version_id"
        case versionNo = "version_no"
        case dslVersion = "dsl_version"
    }
}

struct TraceSnapshot: Codable {
    let snapshotId: String?
    let decision: String?
    let reasonCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case decision
        case reasonCodes = "reason_codes"
    }
}

struct TraceRiskDecision: Codable {
    let decisionType: String?
    let reasonCode: String?

    enum CodingKeys: String, CodingKey {
        case decisionType = "decision_type"
        case reasonCode = "reason_code"
    }
}

struct TraceExecution: Codable {
    let strategyRunId: String?
    let runMode: String?
    let entryPrice: Double?
    let exitPrice: Double?
    let pnlPct: Double?

    enum CodingKeys: String, CodingKey {
        case strategyRunId = "strategy_run_id"
        case runMode = "run_mode"
        case entryPrice = "entry_price"
        case exitPrice = "exit_price"
        case pnlPct = "pnl_pct"
    }
}

struct APIWorkflow {
    let client: NetworkClientProtocol

    func getDailyWorkflow() async throws -> DailyWorkflow {
        try await client.get("/api/workflow/daily", mock: Self.mockWorkflow)
    }

    func refreshWorkflow() async throws -> DailyWorkflow {
        try await client.post("/api/workflow/daily/refresh", body: nil as String?, mock: Self.mockWorkflow)
    }

    func getTradeTrace(tradeId: String) async throws -> TradeSourceTrace {
        try await client.get("/api/execution/trades/\(tradeId)/trace", mock: Self.mockTrace)
    }

    // MARK: - Mock Data

    static func mockWorkflow() -> DailyWorkflow { DailyWorkflow(
        workflowId: "daily_2026-06-08",
        date: "2026-06-08",
        globalState: "ready",
        currentStep: "opportunity",
        steps: [
            WorkflowStep(step: "mission_control", status: "passed", title: "今日状态", question: "今天能不能交易？", summary: "系统健康", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "liveReadiness"),
            WorkflowStep(step: "opportunity", status: "attention", title: "信号机会", question: "有哪些机会？", summary: "发现 3 个信号", count: 3, blockingReasons: [], availableActions: [], jumpTarget: "signalCenter"),
            WorkflowStep(step: "strategy", status: "ready", title: "策略草稿", question: "机会能不能变策略？", summary: "2 个草稿待验证", count: 2, blockingReasons: [], availableActions: [], jumpTarget: "strategyWorkspace"),
            WorkflowStep(step: "mtf_defense", status: "not_started", title: "MTF防御", question: "多周期结构是否安全？", summary: "", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "structureMatrix"),
            WorkflowStep(step: "validation", status: "not_started", title: "回测验证", question: "历史和模拟是否有效？", summary: "", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "backtestSimulation"),
            WorkflowStep(step: "risk_gate", status: "passed", title: "风控准入", question: "能不能实盘？", summary: "风控允许交易", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "riskCenter"),
            WorkflowStep(step: "execution", status: "running", title: "执行监控", question: "执行是否正常？", summary: "Freqtrade 运行中", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "executionCenter"),
            WorkflowStep(step: "review", status: "not_started", title: "交易复盘", question: "为什么赚亏？", summary: "", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "growthReview"),
            WorkflowStep(step: "evolution", status: "not_started", title: "策略进化", question: "是否生成影子策略？", summary: "", count: nil, blockingReasons: [], availableActions: [], jumpTarget: "strategyOptimization"),
        ]
    ) }

    static func mockTrace() -> TradeSourceTrace { TradeSourceTrace(
        tradeId: "trade_001",
        trace: TraceData(signal: nil, strategy: nil, runtimeSnapshot: nil, riskDecision: nil, execution: nil),
        availableActions: []
    ) }
}
