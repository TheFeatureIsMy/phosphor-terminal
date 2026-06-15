// ManipulationViewModel.swift — 操纵雷达视图模型
// 管理雷达概览、案例详情、告警流、交易信号

import SwiftUI

@Observable
@MainActor
final class ManipulationViewModel {
    var radarOverview: ManipulationRadarOverview?
    var selectedCase: ManipulationCaseDetail?
    var alerts: [ManipulationAlertItem] = []
    var userProfile: String = "conservative" // "conservative" or "aggressive"
    var scanSymbol: String = ""

    // Legacy: keep scores for transition
    var scores: [ManipulationScoreV2] = []

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIManipulation
    private var pollingTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.api = APIManipulation(client: client)
    }

    /// Alias used by ManipulationRadarView
    func load() async { await loadRadar() }

    /// Scan a specific symbol
    func scan() async {
        guard !scanSymbol.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            scores = try await api.listScores(limit: 20)
        } catch {
            errorHandler?.handle(error, context: "扫描 \(scanSymbol)")
            self.error = error.localizedDescription
        }
    }

    /// 加载雷达概览 + 告警 + 传统评分
    func loadRadar() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let overviewTask = api.getRadarOverview()
            async let alertsTask = api.getAlerts()
            async let scoresTask = api.listScores(limit: 20)
            radarOverview = try await overviewTask
            alerts = try await alertsTask
            scores = (try? await scoresTask) ?? []
        } catch {
            errorHandler?.handle(error, context: "加载操纵雷达")
            self.error = error.localizedDescription
        }
    }

    /// 加载单个案例详情
    func loadCaseDetail(_ caseId: String) async {
        do {
            selectedCase = try await api.getCaseDetail(caseId)
        } catch {
            errorHandler?.handle(error, context: "加载案例详情")
            self.error = error.localizedDescription
        }
    }

    /// 切换用户风险偏好
    func toggleUserProfile() {
        userProfile = userProfile == "conservative" ? "aggressive" : "conservative"
    }

    /// 启动 30s 轮询
    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await loadRadar() // silent refresh
            }
        }
    }

    /// 停止轮询
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 按风险等级排序（critical > high > medium > low）— legacy helper
    var sortedScores: [ManipulationScoreV2] {
        scores.sorted { riskOrder($0.riskLevel) > riskOrder($1.riskLevel) }
    }

    private func riskOrder(_ level: String) -> Int {
        switch level {
        case "critical": return 4
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 0
        }
    }
}
