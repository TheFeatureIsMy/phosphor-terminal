// BacktestViewModel.swift — 回测视图模型

import SwiftUI

@Observable
@MainActor
final class BacktestViewModel {
    // 配置
    var selectedStrategyId: Int?
    var startDate = "2025-01-01"
    var endDate = "2025-12-31"
    var initialCapital: Double = 10000
    var selectedSymbols: Set<String> = ["BTC/USDT"]

    // 结果
    var result: Backtest?
    var history: [Backtest] = []
    var isRunning = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIBacktest

    init(client: NetworkClientProtocol) {
        self.api = APIBacktest(client: client)
    }

    var canRun: Bool {
        selectedStrategyId != nil && !selectedSymbols.isEmpty
    }

    func run() async {
        guard let strategyId = selectedStrategyId else { return }
        isRunning = true
        error = nil
        do {
            result = try await api.run(
                strategyId: strategyId, startDate: startDate, endDate: endDate,
                capital: initialCapital, symbols: Array(selectedSymbols)
            )
        } catch {
            errorHandler?.handle(error, context: "运行回测")
            self.error = error.localizedDescription
        }
        isRunning = false
    }

    func loadHistory() async {
        do {
            history = try await api.list()
        } catch {}
    }
}
