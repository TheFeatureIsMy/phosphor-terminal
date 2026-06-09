// APIShadowStrategy.swift — Shadow Strategy API

import Foundation

struct ShadowStrategyDraftResponse: Codable, Identifiable, Hashable {
    let id: String
    let sourceType: String
    let sourceFailureClusterId: String?
    let targetStrategyId: String
    let targetStrategyVersionId: String
    let title: String
    let summary: String?
    let status: String
    let failurePattern: FailurePatternInfo?
    let dslPatch: [[String: AnyCodable]]
    let validationState: [String: AnyCodable]
    let backtestId: String?
    let createdBy: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case sourceType = "source_type"
        case sourceFailureClusterId = "source_failure_cluster_id"
        case targetStrategyId = "target_strategy_id"
        case targetStrategyVersionId = "target_strategy_version_id"
        case title, summary, status
        case failurePattern = "failure_pattern"
        case dslPatch = "dsl_patch"
        case validationState = "validation_state"
        case backtestId = "backtest_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    var statusLabel: String {
        switch status {
        case "generated": L10n.zh("已生成", en: "Generated")
        case "validated": L10n.zh("已校验", en: "Validated")
        case "backtested": L10n.zh("已回测", en: "Backtested")
        case "dryrun_pending": L10n.zh("Dry-run中", en: "Dry-running")
        case "dryrun_passed": L10n.zh("Dry-run通过", en: "Dry-run Passed")
        case "human_review": L10n.zh("待审批", en: "Pending Review")
        case "approved": L10n.zh("已批准", en: "Approved")
        case "rejected": L10n.zh("已拒绝", en: "Rejected")
        case "merged_to_strategy_version": L10n.zh("已合并", en: "Merged")
        default: status
        }
    }
}

struct FailurePatternInfo: Codable, Hashable {
    let label: String?
    let sampleSize: Int?
    let lossSum: Double?
    let commonFeatures: [String]?

    enum CodingKeys: String, CodingKey {
        case label
        case sampleSize = "sample_size"
        case lossSum = "loss_sum"
        case commonFeatures = "common_features"
    }
}

struct UpgradeRequestResponse: Codable, Identifiable, Hashable {
    let id: String
    let strategyId: String
    let fromVersionId: String
    let shadowStrategyDraftId: String?
    let proposedVersionName: String?
    let diffSummary: String?
    let approvalStatus: String
    let approvedBy: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case strategyId = "strategy_id"
        case fromVersionId = "from_version_id"
        case shadowStrategyDraftId = "shadow_strategy_draft_id"
        case proposedVersionName = "proposed_version_name"
        case diffSummary = "diff_summary"
        case approvalStatus = "approval_status"
        case approvedBy = "approved_by"
        case createdAt = "created_at"
    }
}

struct APIShadowStrategy {
    let client: NetworkClientProtocol

    func generateFromCluster(clusterId: String) async throws -> ShadowStrategyDraftResponse {
        try await client.post(
            "/api/growth/failure-clusters/\(clusterId)/generate-shadow-strategy",
            body: nil as String?,
            mock: Self.mockDraft
        )
    }

    func listDrafts(strategyId: String? = nil) async throws -> [ShadowStrategyDraftResponse] {
        let path = strategyId != nil
            ? "/api/shadow-strategies?strategy_id=\(strategyId!)"
            : "/api/shadow-strategies"
        return try await client.get(path, mock: { [Self.mockDraft()] })
    }

    func getDraft(id: String) async throws -> ShadowStrategyDraftResponse {
        try await client.get("/api/shadow-strategies/\(id)", mock: Self.mockDraft)
    }

    func validateDraft(id: String) async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/shadow-strategies/\(id)/validate",
            body: nil as String?,
            mock: { ["status": AnyCodable("valid"), "errors": AnyCodable(0)] }
        )
    }

    func requestUpgrade(id: String) async throws -> UpgradeRequestResponse {
        try await client.post(
            "/api/shadow-strategies/\(id)/request-upgrade",
            body: nil as String?,
            mock: Self.mockUpgradeRequest
        )
    }

    func listUpgradeRequests(strategyId: String) async throws -> [UpgradeRequestResponse] {
        try await client.get(
            "/api/v2/strategies/\(strategyId)/upgrade-requests",
            mock: { [Self.mockUpgradeRequest()] }
        )
    }

    func approveUpgrade(strategyId: String, requestId: String) async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/v2/strategies/\(strategyId)/upgrade-requests/\(requestId)/approve",
            body: ["approved_by": "user"],
            mock: { ["result": AnyCodable("approved")] }
        )
    }

    func rejectUpgrade(strategyId: String, requestId: String, reason: String) async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/v2/strategies/\(strategyId)/upgrade-requests/\(requestId)/reject",
            body: ["reason": reason],
            mock: { ["result": AnyCodable("rejected")] }
        )
    }

    // MARK: - Mock Data

    static func mockDraft() -> ShadowStrategyDraftResponse {
        ShadowStrategyDraftResponse(
            id: "shadow_001",
            sourceType: "failure_cluster",
            sourceFailureClusterId: "fc_001",
            targetStrategyId: "str_001",
            targetStrategyVersionId: "v1_2",
            title: "防止接飞刀失败的 Reclaim Confirmation 补丁",
            summary: "要求在 sell-side sweep 后等待 reclaim confirmation",
            status: "generated",
            failurePattern: FailurePatternInfo(
                label: "entered_before_reclaim_confirmation",
                sampleSize: 18,
                lossSum: -1240.52,
                commonFeatures: ["volume_zscore_gt_2_5", "low_tf_breached_htf_ob", "reclaim_not_confirmed"]
            ),
            dslPatch: [
                ["op": AnyCodable("add"), "path": AnyCodable("/entry_logic/conditions/-"), "value": AnyCodable(["type": "reclaim_confirmation", "required": true])],
            ],
            validationState: [:],
            backtestId: nil,
            createdBy: "growth_engine",
            createdAt: "2026-06-08T12:00:00Z"
        )
    }

    static func mockUpgradeRequest() -> UpgradeRequestResponse {
        UpgradeRequestResponse(
            id: "req_001",
            strategyId: "str_001",
            fromVersionId: "v1_2",
            shadowStrategyDraftId: "shadow_001",
            proposedVersionName: "v1.3-shadow-patch",
            diffSummary: "+reclaim_confirmation, +volume_zscore_block",
            approvalStatus: "pending",
            approvedBy: nil,
            createdAt: "2026-06-08T14:00:00Z"
        )
    }
}
