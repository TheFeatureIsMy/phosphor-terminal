// LiveReadinessViewModel.swift — 实盘准入 ViewModel

import SwiftUI

@Observable
@MainActor
final class LiveReadinessViewModel {
    var data: LiveReadinessResponse?
    var isLoading = false
    var isChecking = false
    var error: String?

    private let api: APIOverview

    init(client: NetworkClientProtocol) {
        self.api = APIOverview(client: client)
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await api.getLiveReadiness()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runCheck() async {
        isChecking = true
        defer { isChecking = false }
        do {
            data = try await api.runReadinessCheck()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
