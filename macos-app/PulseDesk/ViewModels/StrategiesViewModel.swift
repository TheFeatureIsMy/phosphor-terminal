// StrategiesViewModel.swift — 策略列表视图模型 (v2.5)

import SwiftUI

@Observable
@MainActor
final class StrategiesViewModel {
    var strategies: [StrategyV2] = []
    var isLoading = true
    var error: String?
    var errorHandler: ErrorHandler?
    var showCreateSheet = false

    // MARK: - Delete / Rename state
    var showDeleteConfirm = false
    var showRenameSheet = false
    var targetStrategy: StrategyV2?
    var newName: String = ""

    private let api: APIStrategiesV2

    init(client: NetworkClientProtocol) {
        self.api = APIStrategiesV2(client: client)
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            strategies = try await api.list()
        } catch {
            errorHandler?.handle(error, context: "加载策略列表")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(name: String) async {
        do {
            let strategy = try await api.create(name: name)
            strategies.insert(strategy, at: 0)
        } catch {
            errorHandler?.handle(error, context: "创建策略")
            self.error = error.localizedDescription
        }
    }

    func delete(strategyId: String) async {
        do {
            try await api.deleteStrategy(id: strategyId)
            strategies.removeAll { $0.id == strategyId }
        } catch {
            errorHandler?.handle(error, context: "删除策略")
            self.error = error.localizedDescription
        }
    }

    func rename(strategyId: String, newName: String) async {
        do {
            let updated = try await api.updateStrategy(id: strategyId, name: newName)
            if let idx = strategies.firstIndex(where: { $0.id == strategyId }) {
                strategies[idx] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "重命名策略")
            self.error = error.localizedDescription
        }
    }

    var draftCount: Int { strategies.filter { $0.status == "draft" }.count }
    var activeCount: Int { strategies.filter { $0.status == "active" }.count }
}
