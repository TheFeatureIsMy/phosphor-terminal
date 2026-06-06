// DataSourcesViewModel.swift — 数据源管理 ViewModel

import SwiftUI

@Observable
@MainActor
final class DataSourcesViewModel {
    var data: DataSourceManagementBFFResponse?
    var isLoading = false
    var error: String?
    var selectedCategory: String? = nil
    var testingSourceId: String?

    private let api: APIDataSources

    init(client: any NetworkClientProtocol) {
        self.api = APIDataSources(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await api.getAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func testConnection(_ sourceId: String) async {
        testingSourceId = sourceId
        defer { testingSourceId = nil }
        do {
            _ = try await api.testConnection(sourceId)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleSource(_ source: DataSourceItemResponse) async {
        do {
            if source.status == "active" {
                _ = try await api.disable(source.sourceId)
            } else {
                _ = try await api.enable(source.sourceId)
            }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var sources: [DataSourceItemResponse] {
        guard let data = data else { return [] }
        if let cat = selectedCategory {
            return data.sources.filter { $0.category == cat }
        }
        return data.sources
    }

    var categories: [String] {
        let cats = Set((data?.sources ?? []).map(\.category))
        return Array(cats).sorted()
    }

    var totalActive: Int { data?.totalActive ?? 0 }
    var totalError: Int { data?.totalError ?? 0 }
}
