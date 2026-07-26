// GrowthViewModel.swift - 增长引擎视图模型
// 管理报告列表、候选策略列表、日报触发、候选确认

import SwiftUI

@Observable
@MainActor
final class GrowthViewModel {
    var reports: [GrowthReport] = []
    var candidates: [StrategyCandidate] = []
    var isLoading = false
    var selectedTab = 0
    var error: String?
    var errorHandler: ErrorHandler?

    var shapFeatures: [(name: String, value: Double)] = []
    var shapState: String = "healthy"
    var signalSources: [(name: String, accuracy: Double, total: Int)] = []
    var signalState: String = "healthy"

    private let api: APIGrowth

    init(client: NetworkClientProtocol) {
        self.api = APIGrowth(client: client)
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let reportsTask = api.listReports()
            async let candidatesTask = api.listCandidates()
            reports = try await reportsTask
            candidates = try await candidatesTask
        } catch {
            errorHandler?.handle(error, context: L10n.zh("加载增长引擎数据", en: "Loading growth data"))
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func runDailyReview() async {
        do {
            let report = try await api.runDailyReview(days: 1)
            reports.insert(report, at: 0)
        } catch {
            errorHandler?.handle(error, context: L10n.zh("运行日报分析", en: "Running daily review"))
        }
    }

    func confirmCandidate(_ id: String) async {
        do {
            _ = try await api.confirmCandidate(id)
            await load()
        } catch {
            errorHandler?.handle(error, context: L10n.zh("确认候选策略", en: "Confirming candidate"))
        }
    }

    func loadShapFeatures() async {
        do {
            let response: ShapFeaturesResponse = try await api.getShapFeatures()
            shapFeatures = response.features.map { (name: $0.name, value: $0.value) }
            shapState = response.state
        } catch {
            shapFeatures = []
            shapState = "data_source_unavailable"
        }
    }

    func loadSignalValidity() async {
        do {
            let response: SignalValidityResponse = try await api.getSignalValidity()
            signalSources = response.sources.map { (name: $0.name, accuracy: $0.accuracy, total: $0.total) }
            signalState = response.state
        } catch {
            signalSources = []
            signalState = "data_source_unavailable"
        }
    }

    var totalSignals: Int { signalSources.reduce(0) { $0 + $1.total } }
    var avgAccuracy: Double {
        guard !signalSources.isEmpty else { return 0 }
        return signalSources.reduce(0.0) { $0 + $1.accuracy } / Double(signalSources.count)
    }
    var bestSource: String { signalSources.max(by: { $0.accuracy < $1.accuracy })?.name ?? "-" }
    var worstSource: String { signalSources.min(by: { $0.accuracy < $1.accuracy })?.name ?? "-" }
}
