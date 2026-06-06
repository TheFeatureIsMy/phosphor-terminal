// StrategyOptimizationViewModel.swift — 策略优化视图模型
// 管理 AI 驱动的策略改进候选建议

import SwiftUI

@Observable
@MainActor
final class StrategyOptimizationViewModel {
    var suggestions: [StrategyCandidate] = []
    var isLoading = false
    var error: String?
    var selectedTab = 0  // 0=pending, 1=confirmed, 2=rejected

    private let growthApi: APIGrowth

    init(client: any NetworkClientProtocol) {
        self.growthApi = APIGrowth(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            suggestions = try await growthApi.listCandidates()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func confirmCandidate(_ id: String) async {
        do {
            _ = try await growthApi.confirmCandidate(id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var pendingCandidates: [StrategyCandidate] {
        suggestions.filter { $0.status == "pending_review" }
    }

    var confirmedCandidates: [StrategyCandidate] {
        suggestions.filter { $0.status == "confirmed" }
    }

    var rejectedCandidates: [StrategyCandidate] {
        suggestions.filter { $0.status == "rejected" }
    }
}
