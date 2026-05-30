// StrategiesViewModel.swift — 策略列表视图模型
// 管理策略 CRUD、部署/停止操作

import SwiftUI

@Observable
@MainActor
final class StrategiesViewModel {
    var strategies: [Strategy] = []
    var isLoading = true
    var error: String?
    var errorHandler: ErrorHandler?
    var showCreateSheet = false

    private let api: APIStrategies

    init(client: NetworkClientProtocol) {
        self.api = APIStrategies(client: client)
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

    func create(name: String, type: StrategyType, market: String, exchange: String) async {
        do {
            let strategy = try await api.create(name: name, type: type, market: market, exchange: exchange)
            strategies.insert(strategy, at: 0)
        } catch {
            errorHandler?.handle(error, context: "创建策略")
            self.error = error.localizedDescription
        }
    }

    func delete(id: Int) async {
        do {
            try await api.delete(id: id)
            strategies.removeAll { $0.id == id }
        } catch {
            errorHandler?.handle(error, context: "删除策略")
            self.error = error.localizedDescription
        }
    }

    func deploy(id: Int) async {
        do {
            let updated = try await api.deploy(id: id)
            if let index = strategies.firstIndex(where: { $0.id == id }) {
                strategies[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "部署策略")
            self.error = error.localizedDescription
        }
    }

    func stop(id: Int) async {
        do {
            let updated = try await api.stop(id: id)
            if let index = strategies.firstIndex(where: { $0.id == id }) {
                strategies[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "停止策略")
            self.error = error.localizedDescription
        }
    }

    func update(id: Int, name: String? = nil, type: StrategyType? = nil, market: String? = nil) async {
        do {
            let updated = try await api.update(id: id, name: name, type: type, market: market)
            if let index = strategies.firstIndex(where: { $0.id == id }) {
                strategies[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "更新策略")
            self.error = error.localizedDescription
        }
    }

    /// 按状态分组的统计
    var activeCount: Int { strategies.filter { $0.status == .active }.count }
    var averageSharpe: Double {
        let sharpes = strategies.compactMap(\.sharpeRatio)
        return sharpes.isEmpty ? 0 : sharpes.reduce(0, +) / Double(sharpes.count)
    }
}
