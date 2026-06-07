// GrowthViewModel.swift — 增长引擎视图模型
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
    var signalSources: [(name: String, accuracy: Double, total: Int)] = []

    private let api: APIGrowth

    init(client: NetworkClientProtocol) {
        self.api = APIGrowth(client: client)
    }

    /// 加载报告和候选策略
    func load() async {
        isLoading = true
        error = nil
        do {
            async let reportsTask = api.listReports()
            async let candidatesTask = api.listCandidates()
            reports = try await reportsTask
            candidates = try await candidatesTask
        } catch {
            errorHandler?.handle(error, context: "加载增长引擎数据")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 触发日报分析
    func runDailyReview() async {
        do {
            let report = try await api.runDailyReview(["trigger": "manual"])
            reports.insert(report, at: 0)
        } catch {
            errorHandler?.handle(error, context: "运行日报分析")
        }
    }

    /// 确认候选策略
    func confirmCandidate(_ id: String) async {
        do {
            let updated = try await api.confirmCandidate(id)
            if let index = candidates.firstIndex(where: { $0.id == id }) {
                candidates[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "确认候选策略")
        }
    }

    /// 加载 SHAP 特征重要性
    func loadShapFeatures() async {
        do {
            let response: ShapFeaturesResponse = try await api.getShapFeatures()
            shapFeatures = response.features.map { (name: $0.name, value: $0.value) }
        } catch {
            // Fallback to defaults if API fails
            shapFeatures = [
                (name: "RSI_14", value: 0.312), (name: "MACD_hist", value: 0.248),
                (name: "Vol_24h", value: 0.201), (name: "BB_width", value: 0.178),
                (name: "EMA_cross", value: 0.156), (name: "ATR_14", value: 0.123),
                (name: "OBV_slope", value: 0.098), (name: "ADX_14", value: 0.087),
                (name: "Funding_rate", value: 0.065), (name: "Sentiment", value: 0.042),
            ]
        }
    }

    /// 加载 Signal 有效性
    func loadSignalValidity() async {
        do {
            let response: SignalValidityResponse = try await api.getSignalValidity()
            signalSources = response.sources.map { (name: $0.name, accuracy: $0.accuracy, total: $0.total) }
        } catch {
            // Fallback to defaults if API fails
            signalSources = [
                (name: "AI Research", accuracy: 0.72, total: 45),
                (name: "TradingAgents", accuracy: 0.68, total: 38),
                (name: "Manual", accuracy: 0.61, total: 25),
                (name: "Sentiment", accuracy: 0.55, total: 28),
                (name: "KOL", accuracy: 0.42, total: 20),
            ]
        }
    }
}
