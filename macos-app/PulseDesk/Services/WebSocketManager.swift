// WebSocketManager.swift — WebSocket 连接管理
// 自动重连、心跳、频道订阅

import Foundation
import SwiftUI

@Observable
final class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var subscribedChannels: Set<String> = []
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private let baseURL: URL

    var onMessage: ((String, [String: Any]) -> Void)?
    var connectionState: ConnectionState = .disconnected

    enum ConnectionState {
        case connected, disconnected, reconnecting
    }

    init(baseURL: URL = URL(string: "ws://localhost:8000")!) {
        self.baseURL = baseURL
        super.init()
    }

    func connect() {
        let wsURL = baseURL.appendingPathComponent("ws")
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = session?.webSocketTask(with: wsURL)
        webSocket?.resume()
        connectionState = .reconnecting
        receiveMessage()
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        connectionState = .disconnected
    }

    func subscribe(_ channels: [String]) {
        subscribedChannels.formUnion(channels)
        let msg: [String: Any] = ["action": "subscribe", "channels": channels]
        send(json: msg)
    }

    func unsubscribe(_ channels: [String]) {
        subscribedChannels.subtract(channels)
        let msg: [String: Any] = ["action": "unsubscribe", "channels": channels]
        send(json: msg)
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(str)) { _ in }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    self.handleMessage(text)
                default:
                    break
                }
                self.receiveMessage()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else { return }

        if action == "pong" { return }

        if let channel = json["channel"] as? String,
           let payload = json["data"] as? [String: Any] {
            onMessage?(channel, payload)
        }
    }

    private func handleDisconnect() {
        isConnected = false
        connectionState = .disconnected
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.connect()
        }
        connectionState = .reconnecting
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.send(json: ["action": "ping"])
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        isConnected = true
        connectionState = .connected
        startHeartbeat()

        if !subscribedChannels.isEmpty {
            subscribe(Array(subscribedChannels))
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}
