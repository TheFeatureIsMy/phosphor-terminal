// APIDataSources.swift — Data Source Management BFF API
// Rewritten to proxy through /api/admin/providers

import Foundation

// MARK: - Response Types (view-compatible shape)

struct DataSourceItemResponse: Codable, Identifiable {
    var id: String { sourceId }
    let sourceId: String
    let name: String
    let category: String
    var provider: String = ""
    var status: String = "active"
    var lastFetch: String = ""
    var latencyMs: Int = 0
    var freshness: String = "fresh"
    var config: [String: String] = [:]
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case name, category, provider, status, freshness, config
        case sourceId = "source_id"
        case lastFetch = "last_fetch"
        case latencyMs = "latency_ms"
        case reasonCodes = "reason_codes"
    }
}

struct DataSourceManagementBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var sources: [DataSourceItemResponse] = []
    var totalActive: Int = 0
    var totalError: Int = 0

    enum CodingKeys: String, CodingKey {
        case state, sources
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case totalActive = "total_active"
        case totalError = "total_error"
    }
}

// MARK: - API Service

struct APIDataSources {
    let client: NetworkClientProtocol

    /// GET /api/admin/providers → convert to DataSourceManagementBFFResponse
    func getAll() async throws -> DataSourceManagementBFFResponse {
        let providers: [ProviderConfigView] = try await client.get("/api/admin/providers")
        return Self.convert(providers)
    }

    /// POST /api/admin/providers/{id}/test
    func testConnection(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/admin/providers/\(sourceId)/test", body: nil)
    }

    /// POST /api/admin/providers/{id}/enable
    func enable(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/admin/providers/\(sourceId)/enable", body: nil)
    }

    /// POST /api/admin/providers/{id}/disable
    func disable(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/admin/providers/\(sourceId)/disable", body: nil)
    }

    // MARK: - Conversion

    static func convert(_ providers: [ProviderConfigView]) -> DataSourceManagementBFFResponse {
        let sources: [DataSourceItemResponse] = providers.map { p in
            let lastFetchStr: String
            if let d = p.lastSyncAt {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastFetchStr = f.string(from: d)
            } else {
                lastFetchStr = ""
            }

            let freshness: String
            if let d = p.lastSyncAt {
                let elapsed = Date().timeIntervalSince(d)
                if elapsed < 3600 { freshness = "fresh" }
                else if elapsed < 86400 { freshness = "stale" }
                else { freshness = "expired" }
            } else {
                freshness = "stale"
            }

            var configStr: [String: String] = [:]
            for (k, v) in p.config {
                configStr[k] = "\(v.value)"
            }

            var reasons: [String] = []
            if let err = p.lastError, !err.isEmpty { reasons.append(err) }
            if p.credentialStatus == "missing" { reasons.append("credentials_missing") }
            if p.credentialStatus == "invalid" { reasons.append("credentials_invalid") }

            return DataSourceItemResponse(
                sourceId: String(p.id),
                name: p.providerName,
                category: p.category,
                provider: p.providerName,
                status: p.enabled ? p.status : "inactive",
                lastFetch: lastFetchStr,
                latencyMs: p.latencyMs ?? 0,
                freshness: freshness,
                config: configStr,
                reasonCodes: reasons
            )
        }

        let totalActive = sources.filter { $0.status == "active" }.count
        let totalError = sources.filter { $0.status == "error" }.count
        let state: String = totalError > 0 ? "warning" : (totalActive > 0 ? "healthy" : "inactive")

        var reasonCodes: [String] = []
        if totalError > 0 { reasonCodes.append("\(totalError)_source_error") }

        return DataSourceManagementBFFResponse(
            state: state,
            reasonCodes: reasonCodes,
            availableActions: [
                AvailableActionResponse(type: "test_all", enabled: true, label: "测试所有连接"),
            ],
            sources: sources,
            totalActive: totalActive,
            totalError: totalError
        )
    }
}
// MARK: - Real-time WebSocket streams

struct ProviderHealthMessage: Codable {
    let type: String
    let ts: Date
    let providers: [ProviderConfigView]?
    let providerId: Int?
    let status: String?
    let latencyMs: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, providers, status, error
        case providerId = "provider_id"
        case latencyMs = "latency_ms"
    }
}

extension APIDataSources {
    /// Connect to /api/ws/provider-health and return an AsyncStream of decoded messages.
    public func connectProviderHealthStream() -> AsyncThrowingStream<ProviderHealthMessage, Error> {
        let url = client.baseURL.appendingPathComponent("/api/ws/provider-health")
        return AsyncThrowingStream { continuation in
            let task = URLSession.shared.webSocketTask(with: url)
            task.resume()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            final class Receiver: @unchecked Sendable {
                let task: URLSessionWebSocketTask
                let decoder: JSONDecoder
                let continuation: AsyncThrowingStream<ProviderHealthMessage, Error>.Continuation

                init(task: URLSessionWebSocketTask, decoder: JSONDecoder, continuation: AsyncThrowingStream<ProviderHealthMessage, Error>.Continuation) {
                    self.task = task
                    self.decoder = decoder
                    self.continuation = continuation
                }

                func start() {
                    receive()
                }

                func receive() {
                    task.receive { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success(let message):
                            if case .string(let text) = message, let data = text.data(using: .utf8) {
                                do {
                                    let msg = try self.decoder.decode(ProviderHealthMessage.self, from: data)
                                    self.continuation.yield(msg)
                                } catch {
                                    // Skip malformed frame
                                }
                            }
                            self.receive()
                        case .failure(let error):
                            self.continuation.finish(throwing: error)
                        }
                    }
                }
            }

            let receiver = Receiver(task: task, decoder: decoder, continuation: continuation)
            receiver.start()
            continuation.onTermination = { _ in task.cancel(with: .goingAway, reason: nil) }
        }
    }
}
