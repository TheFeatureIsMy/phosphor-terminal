// APIStrategyWorkspace.swift — Strategy workbench BFF API (7 endpoints).
// Spec §6.1.A–G  /  Plan 2026-06-18 Task 14

import Foundation

struct APIStrategyWorkspace {
    let client: NetworkClientProtocol

    /// GET /api/v2/strategies/{id}/workspace — full BFF aggregation.
    func getSnapshot(strategyId: String) async throws -> WorkspaceSnapshot {
        try await client.get("/api/v2/strategies/\(strategyId)/workspace") {
            MockWorkspace.snapshot(strategyId: strategyId)
        }
    }

    /// POST /api/v2/strategies/{id}/duplicate
    func duplicate(strategyId: String, name: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        return try await client.post("/api/v2/strategies/\(strategyId)/duplicate", body: AnyEncodable(body)) {
            MockWorkspace.duplicatedStrategy(name: name)
        }
    }

    /// GET /api/v2/strategies/{id}/bindings
    func listBindings(strategyId: String) async throws -> [StrategyBinding] {
        try await client.get("/api/v2/strategies/\(strategyId)/bindings") {
            MockWorkspace.bindings()
        }
    }

    /// POST /api/v2/strategies/{id}/bindings
    func createBinding(
        strategyId: String,
        versionId: String,
        policyVersionId: String,
        poolId: String,
        mode: String
    ) async throws -> StrategyBinding {
        let body: [String: Any] = [
            "strategy_version_id": versionId,
            "risk_policy_version_id": policyVersionId,
            "capital_pool_id": poolId,
            "mode": mode,
        ]
        return try await client.post("/api/v2/strategies/\(strategyId)/bindings", body: AnyEncodable(body)) {
            MockWorkspace.binding(versionId: versionId, mode: mode)
        }
    }

    /// DELETE /api/v2/strategies/{id}/bindings/{binding_id}
    func deleteBinding(strategyId: String, bindingId: String) async throws {
        try await client.delete("/api/v2/strategies/\(strategyId)/bindings/\(bindingId)") { }
    }

    /// PATCH /api/v2/strategies/{id}/archive
    func archive(strategyId: String, reason: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        return try await client.patch("/api/v2/strategies/\(strategyId)/archive", body: AnyEncodable(body)) {
            MockWorkspace.archivedStrategy(strategyId: strategyId)
        }
    }

    /// GET /api/v2/strategies/{id}/activity?limit=N
    func listActivity(strategyId: String, limit: Int = 20) async throws -> [ActivityEntry] {
        try await client.get("/api/v2/strategies/\(strategyId)/activity?limit=\(limit)") {
            MockWorkspace.activity(strategyId: strategyId)
        }
    }
}

// MARK: - Mock factories (used only by MockNetworkClient)

enum MockWorkspace {

    static func snapshot(strategyId: String) -> WorkspaceSnapshot {
        let strategy = StrategyV2(
            id: strategyId,
            name: "RSI 均值回归 v3",
            description: "RSI<30 入场，RSI>70 出场",
            strategyType: "rule_dsl",
            sourceType: "manual",
            status: "validated",
            createdAt: "2026-06-10T10:00:00Z",
            updatedAt: "2026-06-17T14:30:00Z"
        )
        let v3 = StrategyVersionV2(
            id: "00000000-0000-4000-8000-000000000003",
            strategyId: strategyId,
            versionNo: 3,
            status: "draft",
            dslVersion: "2.5",
            ruleDsl: ["entry": AnyCodable(["rules": [] as [Any]])],
            dslHash: "4f7a92c1b2090ae2",
            createdBy: "user@local",
            createdAt: "2026-06-17T12:00:00Z"
        )
        return WorkspaceSnapshot(
            strategy: strategy,
            versions: [v3],
            latestVersionId: v3.id,
            bindings: bindings(),
            recentBacktests: [
                BacktestRunSummary(
                    id: 901, startedAt: "2026-06-15T03:00:00Z", completedAt: "2026-06-15T03:18:00Z",
                    status: "completed", totalReturn: 0.082, winRate: 0.61, maxDrawdown: 0.041, sharpeRatio: 1.32
                ),
                BacktestRunSummary(
                    id: 894, startedAt: "2026-06-12T08:30:00Z", completedAt: "2026-06-12T08:51:00Z",
                    status: "completed", totalReturn: 0.064, winRate: 0.58, maxDrawdown: 0.052, sharpeRatio: 1.10
                ),
            ],
            recentDryruns: [
                StrategyRunSummary(
                    id: "00000000-0000-4000-8000-00000000d101",
                    mode: "dry_run", status: "running",
                    startedAt: "2026-06-17T10:00:00Z", stoppedAt: nil,
                    createdAt: "2026-06-17T09:55:00Z"
                ),
            ],
            readiness: readiness(),
            activity: activity(strategyId: strategyId),
            signalLogicSummary: SignalLogicSummary(
                entryText: "RSI(14) < 30 AND volume_filter > 1M",
                exitText: "RSI(14) > 70",
                filterCount: 1
            ),
            dataDependencies: DataDependencies(
                symbols: ["BTC/USDT", "ETH/USDT"],
                timeframes: ["1h"],
                indicators: ["rsi", "volume"],
                signalSources: ["price"]
            )
        )
    }

    static func duplicatedStrategy(name: String?) -> StrategyV2 {
        StrategyV2(
            id: UUID().uuidString,
            name: name ?? "RSI 均值回归 v3 copy",
            description: "Duplicated",
            strategyType: "rule_dsl",
            sourceType: "manual",
            status: "draft",
            createdAt: "2026-06-19T09:00:00Z",
            updatedAt: "2026-06-19T09:00:00Z"
        )
    }

    static func archivedStrategy(strategyId: String) -> StrategyV2 {
        StrategyV2(
            id: strategyId,
            name: "RSI 均值回归 v3",
            description: nil,
            strategyType: "rule_dsl",
            sourceType: "manual",
            status: "archived",
            createdAt: "2026-06-10T10:00:00Z",
            updatedAt: "2026-06-19T09:30:00Z"
        )
    }

    static func bindings() -> [StrategyBinding] {
        [
            binding(
                versionId: "00000000-0000-4000-8000-000000000003",
                mode: "dry_run"
            )
        ]
    }

    static func binding(versionId: String, mode: String) -> StrategyBinding {
        StrategyBinding(
            id: UUID().uuidString,
            strategyVersionId: versionId,
            versionNo: 3,
            riskPolicy: RiskPolicySummary(
                id: "00000000-0000-4000-8000-0000000000a1",
                name: "Conservative v2",
                versionNo: 2,
                policyJsonSummary: [
                    "max_daily_loss": AnyCodable(0.03),
                    "max_position_pct": AnyCodable(0.05),
                ]
            ),
            capitalPool: CapitalPoolSummary(
                id: "00000000-0000-4000-8000-0000000000b1",
                name: "Paper Pool A",
                poolType: mode == "live_small" ? "live_small" : "paper",
                totalBudget: 10_000,
                currency: "USDT",
                remainingBudget: 9_840
            ),
            mode: mode,
            createdAt: "2026-06-17T12:30:00Z"
        )
    }

    static func activity(strategyId: String) -> [ActivityEntry] {
        _ = strategyId
        return [
            ActivityEntry(
                id: UUID().uuidString,
                kind: "version_created",
                occurredAt: "2026-06-17T12:00:00Z",
                actor: "user@local",
                summary: "v3 created from canvas",
                delta: ["node_count_change": AnyCodable(2), "edge_count_change": AnyCodable(2)],
                ref: ActivityEntryRef(kind: "version", id: "00000000-0000-4000-8000-000000000003")
            ),
            ActivityEntry(
                id: UUID().uuidString,
                kind: "binding_added",
                occurredAt: "2026-06-17T12:30:00Z",
                actor: "user@local",
                summary: "bound dry_run mode → Conservative v2 / Paper Pool A",
                delta: nil,
                ref: ActivityEntryRef(kind: "binding", id: UUID().uuidString)
            ),
        ]
    }

    static func readiness() -> PerStrategyReadiness {
        PerStrategyReadiness(
            passedCount: 8,
            total: 11,
            grandStatus: "needs_validation",
            nextAction: ReadinessNextAction(
                code: "run_dryrun",
                label: "运行 24h dry-run 验证",
                targetPanel: "backtest"
            ),
            strategyGates: [
                ReadinessGate(key: "validation", status: "healthy", value: "valid", threshold: "valid", detail: "DSL 校验通过", reasonCodes: []),
                ReadinessGate(key: "backtest", status: "healthy", value: "1.32", threshold: ">=1.0", detail: "Sharpe 1.32", reasonCodes: []),
                ReadinessGate(key: "dryrun", status: "warning", value: "running 4h", threshold: ">=24h", detail: "需要运行至少 24h", reasonCodes: ["DRYRUN_NOT_ENOUGH_RUNTIME"]),
                ReadinessGate(key: "risk_config", status: "healthy", value: "Conservative v2", threshold: "bound", detail: "风控策略已绑定", reasonCodes: []),
                ReadinessGate(key: "capital", status: "healthy", value: "9840 / 10000", threshold: "remaining > 0", detail: "Paper Pool A 充足", reasonCodes: []),
                ReadinessGate(key: "strategy", status: "warning", value: "draft", threshold: "paper_passed", detail: "策略状态需要 paper_passed", reasonCodes: ["STRATEGY_NEEDS_VALIDATION"]),
            ],
            systemGates: [
                ReadinessGate(key: "exchange", status: "healthy", value: "binance", threshold: "connected", detail: "已连接", reasonCodes: []),
                ReadinessGate(key: "data_source", status: "healthy", value: "live", threshold: "fresh", detail: "数据流正常", reasonCodes: []),
                ReadinessGate(key: "notification", status: "healthy", value: "telegram", threshold: "any", detail: "telegram 配置中", reasonCodes: []),
                ReadinessGate(key: "emergency_stop", status: "healthy", value: "armed", threshold: "armed", detail: "紧急停止已就绪", reasonCodes: []),
                ReadinessGate(key: "mode", status: "warning", value: "paper", threshold: "live", detail: "当前为 paper 模式", reasonCodes: ["ACCOUNT_MODE_NOT_LIVE"]),
            ]
        )
    }
}
