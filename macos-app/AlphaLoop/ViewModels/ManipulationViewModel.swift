// ManipulationViewModel.swift — 操纵雷达视图模型
// 管理操纵评分列表、单币扫描

import SwiftUI

@Observable
@MainActor
final class ManipulationViewModel {
    var scores: [ManipulationScoreV2] = []
    var isLoading = false
    var scanSymbol = ""
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIManipulation

    init(client: NetworkClientProtocol) {
        self.api = APIManipulation(client: client)
    }

    /// 加载所有评分
    func load() async {
        isLoading = true
        error = nil
        do {
            scores = try await api.listScores()
        } catch {
            errorHandler?.handle(error, context: "加载操纵评分")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 扫描指定币种
    func scan() async {
        let symbol = scanSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { return }
        do {
            let result = try await api.scanSymbol(["symbol": symbol])
            // 替换已有同 symbol 的记录，或插入新记录
            if let index = scores.firstIndex(where: { $0.symbol == result.symbol }) {
                scores[index] = result
            } else {
                scores.insert(result, at: 0)
            }
        } catch {
            errorHandler?.handle(error, context: "扫描 \(symbol)")
        }
    }

    /// 按风险等级排序（critical > high > medium > low）
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
