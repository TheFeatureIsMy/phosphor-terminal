// ManipulationStreamClient.swift — WebSocket client for /api/v2/manipulation/stream
// Wraps URLSessionWebSocketTask.receive() into AsyncStream<ManipulationEvent>.
// Mock mode (baseURL == nil) → no-op stream that never yields.

import Foundation

actor ManipulationStreamClient {
    private var task: URLSessionWebSocketTask?
    private var continuation: AsyncStream<ManipulationEvent>.Continuation?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Connect to ws://<host>/api/v2/manipulation/stream. Pass nil for mock mode (no-op).
    func connect(baseURL: URL?) {
        disconnect()
        guard let baseURL else { return }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard let wsURL = components?.url?.appendingPathComponent("api/v2/manipulation/stream") else { return }
        task = session.webSocketTask(with: wsURL)
        task?.resume()
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation?.finish()
        continuation = nil
    }

    /// Live event stream. Cancellation stops the receive loop.
    func events() -> AsyncStream<ManipulationEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.disconnect() }
            }
        }
    }

    private func receiveLoop() {
        guard let task else { return }
        Task {
            while !Task.isCancelled {
                do {
                    let msg = try await task.receive()
                    switch msg {
                    case .data(let data):
                        if let event = try? JSONDecoder().decode(ManipulationEvent.self, from: data) {
                            continuation?.yield(event)
                        }
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let event = try? JSONDecoder().decode(ManipulationEvent.self, from: data) {
                            continuation?.yield(event)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    continuation?.finish()
                    break
                }
            }
        }
    }
}
