// DryrunMonitorViewModel.swift — 模拟监控视图模型
// 加载 dryrun 模式运行列表，停止运行

import SwiftUI

@Observable
@MainActor
final class DryrunMonitorViewModel {
    var runs: [StrategyRunV2] = []
    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let runsApi: APIStrategyRuns
    private let dryrunApi: APIDryrunV2

    init(client: NetworkClientProtocol) {
        self.runsApi = APIStrategyRuns(client: client)
        self.dryrunApi = APIDryrunV2(client: client)
    }

    /// 加载 dryrun 模式运行
    func load() async {
        isLoading = true
        error = nil
        do {
            runs = try await runsApi.listRuns(mode: "dryrun", limit: 50)
        } catch {
            errorHandler?.handle(error, context: "加载模拟监控")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 停止指定 dryrun
    func stopDryrun(_ id: String) async {
        do {
            _ = try await dryrunApi.stopDryrun(id)
            // 刷新列表
            await load()
        } catch {
            errorHandler?.handle(error, context: "停止模拟运行")
        }
    }

    /// 运行中的 runs
    var activeRuns: [StrategyRunV2] {
        runs.filter { ["running", "starting", "degraded"].contains($0.status) }
    }

    /// 已完成的 runs
    var completedRuns: [StrategyRunV2] {
        runs.filter { !["running", "starting", "degraded"].contains($0.status) }
    }

    /// 平均运行时长（秒）
    var avgDurationSeconds: Double {
        let finished = runs.compactMap { run -> Double? in
            guard let start = run.startedAt, let stop = run.stoppedAt else { return nil }
            let fmt = ISO8601DateFormatter()
            guard let s = fmt.date(from: start), let e = fmt.date(from: stop) else { return nil }
            return e.timeIntervalSince(s)
        }
        guard !finished.isEmpty else { return 0 }
        return finished.reduce(0, +) / Double(finished.count)
    }
}
