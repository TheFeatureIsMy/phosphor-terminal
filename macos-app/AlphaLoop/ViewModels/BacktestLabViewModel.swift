// BacktestLabViewModel.swift — 回测实验室聚合 ViewModel

import SwiftUI

@Observable
@MainActor
final class BacktestLabViewModel {
    // MARK: - State

    /// 所有可选策略（左侧选择器 + 默认锁定当前选中）
    var strategies: [StrategyV2] = []
    var selectedStrategyId: String?

    /// 当前策略下的全部回测 run
    var runs: [BacktestRunV2] = []

    /// 多选对比：最多 3 个
    var comparedRunIds: Set<Int> = []
    /// Inspector 显示的 run；默认 = comparedRunIds 最后一个 / runs[0]
    var inspectedRunId: Int?

    var isLoading = false
    var loadError: String?

    var showNewRunSheet = false

    // MARK: - Deps

    private let client: NetworkClientProtocol
    private let strategiesAPI: APIStrategiesV2

    init(client: NetworkClientProtocol) {
        self.client = client
        self.strategiesAPI = APIStrategiesV2(client: client)
    }

    // MARK: - Derived

    var selectedStrategy: StrategyV2? {
        guard let id = selectedStrategyId else { return nil }
        return strategies.first { $0.id == id }
    }

    var inspectedRun: BacktestRunV2? {
        guard let id = inspectedRunId else { return nil }
        return runs.first { $0.id == id }
    }

    var comparedRuns: [BacktestRunV2] {
        runs.filter { comparedRunIds.contains($0.id) }
            .sorted { ($0.completedAt ?? "") > ($1.completedAt ?? "") }
    }

    /// 冠军：completed 中 Sharpe 最高且 maxDD > -25 的 run
    var championRun: BacktestRunV2? {
        let pool = runs.filter { $0.status == "completed" && $0.maxDrawdown > -25 }
        return pool.max { $0.sharpeRatio < $1.sharpeRatio }
    }

    // MARK: - Load

    func bootstrap() async {
        isLoading = true
        loadError = nil
        do {
            strategies = try await strategiesAPI.list()
            // 默认选中：app state 里 strategyV2Id > 列表第一个
            if selectedStrategyId == nil {
                selectedStrategyId = strategies.first?.id
            }
            await loadRuns()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func selectStrategy(_ id: String) async {
        selectedStrategyId = id
        comparedRunIds = []
        inspectedRunId = nil
        await loadRuns()
    }

    func loadRuns() async {
        guard selectedStrategyId != nil else { runs = []; return }
        do {
            // 后端 listBacktests 走 Int strategyId；v2 strategy 没有 int id，先取全量再按 createdAt 排序
            let all = try await strategiesAPI.listBacktests(limit: 25)
            runs = all.sorted { ($0.completedAt ?? $0.createdAt ?? "") > ($1.completedAt ?? $1.createdAt ?? "") }
            // 默认勾选第一个 + Inspect
            if comparedRunIds.isEmpty, let first = runs.first {
                comparedRunIds.insert(first.id)
                inspectedRunId = first.id
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Compare / inspect actions

    func toggleCompare(_ runId: Int) {
        if comparedRunIds.contains(runId) {
            comparedRunIds.remove(runId)
            if inspectedRunId == runId {
                inspectedRunId = comparedRunIds.first
            }
        } else {
            if comparedRunIds.count >= 3 {
                // 替换最早加入的
                if let first = comparedRunIds.first { comparedRunIds.remove(first) }
            }
            comparedRunIds.insert(runId)
            inspectedRunId = runId
        }
    }

    func inspect(_ runId: Int) {
        inspectedRunId = runId
        comparedRunIds.insert(runId)
    }

    // MARK: - New run submission

    func submitNewRun(
        versionId: String?,
        start: String,
        end: String,
        capital: Double,
        symbols: [String]
    ) async -> Bool {
        guard let _ = selectedStrategyId else { return false }
        do {
            _ = try await strategiesAPI.startBacktest(
                dsl: [:],
                timerange: "\(start)-\(end)",
                symbols: symbols,
                initialCapital: capital,
                strategyVersionId: versionId
            )
            // 刷新列表（mock 模式下立刻拿到新 run）
            await loadRuns()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }
}
