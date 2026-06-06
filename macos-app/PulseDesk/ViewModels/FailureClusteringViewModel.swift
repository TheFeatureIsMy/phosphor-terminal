// FailureClusteringViewModel.swift — 失败聚类视图模型
// 管理失败模式分析数据：聚类、Regime 矩阵、拒单原因

import SwiftUI

@Observable
@MainActor
final class FailureClusteringViewModel {
    var data: FailureClusteringSummaryResponse?
    var isLoading = false
    var error: String?
    var selectedTab = 0  // 0=clusters, 1=regime matrix, 2=reject reasons

    private let api: APIFailureClustering

    init(client: any NetworkClientProtocol) {
        self.api = APIFailureClustering(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await api.getSummary()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var clusters: [FailureClusterBFFResponse] { data?.clusters ?? [] }
    var regimeMatrix: [RegimeFailureCellResponse] { data?.regimeMatrix ?? [] }
    var totalLossTrades: Int { data?.totalLossTrades ?? 0 }
    var totalLossAmount: Double { data?.totalLossAmount ?? 0 }
    var labels: [String] { data?.labels ?? [] }
    var commonRejectReasons: [[String: String]] { data?.commonRejectReasons ?? [] }

    var maxClusterLoss: Double {
        clusters.map { abs($0.totalLoss) }.max() ?? 1.0
    }

    var uniqueRegimes: [String] {
        Array(Set(regimeMatrix.map(\.regime))).sorted()
    }

    var uniqueFailureTypes: [String] {
        Array(Set(regimeMatrix.map(\.failureType))).sorted()
    }

    func regimeCell(regime: String, failureType: String) -> RegimeFailureCellResponse? {
        regimeMatrix.first { $0.regime == regime && $0.failureType == failureType }
    }
}
