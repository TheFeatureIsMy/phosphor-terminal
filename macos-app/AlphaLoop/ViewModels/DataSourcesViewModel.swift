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

    // MARK: - Create Provider

    var showAddSheet = false
    var newCategory = "market_data"
    var newProviderName = ""
    var newInstanceName = ""
    var newApiKey = ""
    var newApiSecret = ""
    var isCreating = false

    func createProvider() async {
        guard !newProviderName.isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let body = ProviderConfigPayload(
                category: newCategory,
                providerName: newProviderName,
                instanceName: newInstanceName.isEmpty ? nil : newInstanceName,
                enabled: true,
                priority: 100,
                config: [:],
                credentials: buildCredentials()
            )
            let apiProviders = APIAIProviders(client: api.client)
            _ = try await apiProviders.updateConfig(body: body)
            resetForm()
            showAddSheet = false
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func buildCredentials() -> [String: String]? {
        var creds: [String: String] = [:]
        if !newApiKey.isEmpty { creds["api_key"] = newApiKey }
        if !newApiSecret.isEmpty { creds["api_secret"] = newApiSecret }
        return creds.isEmpty ? nil : creds
    }

    func resetForm() {
        newProviderName = ""
        newInstanceName = ""
        newApiKey = ""
        newApiSecret = ""
        newCategory = "market_data"
    }
}
