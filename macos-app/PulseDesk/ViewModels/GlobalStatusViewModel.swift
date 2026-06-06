// GlobalStatusViewModel.swift — 全局状态栏 ViewModel

import SwiftUI

@Observable
@MainActor
final class GlobalStatusViewModel {
    var status: GlobalStatusBFFResponse?
    var isLoading = false
    var error: String?

    private let api: APIOverview
    private var refreshTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.api = APIOverview(client: client)
    }

    func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await loadStatus()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stopPolling() {
        refreshTask?.cancel()
    }

    func loadStatus() async {
        do {
            status = try await api.getGlobalStatus()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
