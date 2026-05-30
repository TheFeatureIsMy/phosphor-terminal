// DependencyState.swift — 依赖状态管理

import Foundation
import SwiftUI

@MainActor
@Observable
final class DependencyState {
    private let client: any NetworkClientProtocol
    private var refreshTimer: Timer?

    var response: DependencyResponse?
    var isLoading = false
    var lastError: String?

    var readinessScore: Double { response?.readinessScore ?? 0 }
    var showSetupWizard: Bool { readinessScore < 0.5 }

    init(client: any NetworkClientProtocol) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let api = APIDependencies(client: client)
            response = try await api.fetchDependencies()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startPeriodicRefresh(interval: TimeInterval = 300) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func isAvailable(_ key: String, in group: String) -> Bool {
        guard let response else { return false }
        let dict: [String: DependencyItem]?
        switch group {
        case "core_optional": dict = response.coreOptional
        case "ml_models": dict = response.mlModels
        case "external_services": dict = response.externalServices
        default: dict = nil
        }
        guard let item = dict?[key] else { return false }
        return ["ok", "installed", "loaded", "connected", "configured", "available"].contains(item.status)
    }

    func status(for key: String, in group: String) -> String {
        guard let response else { return "unknown" }
        let dict: [String: DependencyItem]?
        switch group {
        case "core_optional": dict = response.coreOptional
        case "ml_models": dict = response.mlModels
        case "external_services": dict = response.externalServices
        default: dict = nil
        }
        return dict?[key]?.status ?? "unknown"
    }
}

// MARK: - Environment Key
private struct DependencyStateKey: EnvironmentKey {
    static let defaultValue: DependencyState? = nil
}

extension EnvironmentValues {
    var dependencyState: DependencyState? {
        get { self[DependencyStateKey.self] }
        set { self[DependencyStateKey.self] = newValue }
    }
}
