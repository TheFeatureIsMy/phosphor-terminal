// WebSocketManager.swift — WebSocket 连接管理
// 自动重连、心跳、频道订阅、实时通知广播

import Foundation
import SwiftUI

// MARK: - WebSocket Channel Definitions
extension WebSocketManager {
    /// Well-known real-time channels
    enum Channel: String, CaseIterable {
        case kpiUpdate   = "kpi_update"    // Dashboard KPI 实时刷新
        case signalNew   = "signal_new"    // 新信号通知
        case dryrunStatus = "dryrun_status" // Dry-run 状态变更
    }
}

// MARK: - Notification Names for WebSocket Events
extension Notification.Name {
    /// Fired when a KPI update arrives. `userInfo` contains the payload dict.
    static let wsKPIUpdate    = Notification.Name("PulseDesk.ws.kpiUpdate")
    /// Fired when a new signal is received. `userInfo` contains the payload dict.
    static let wsSignalNew    = Notification.Name("PulseDesk.ws.signalNew")
    /// Fired when dry-run status changes. `userInfo` contains the payload dict.
    static let wsDryrunStatus = Notification.Name("PulseDesk.ws.dryrunStatus")
    /// Fired when WebSocket connection state changes. `userInfo["state"]` is a ConnectionState raw value.
    static let wsConnectionStateChanged = Notification.Name("PulseDesk.ws.connectionStateChanged")
}

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
    var connectionState: ConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(
                name: .wsConnectionStateChanged,
                object: self,
                userInfo: ["state": connectionState.rawValue]
            )
        }
    }

    /// Last received payload per channel (views can read on appear)
    var lastKPIPayload: [String: Any]?
    var lastSignalPayload: [String: Any]?
    var lastDryrunPayload: [String: Any]?

    enum ConnectionState: String {
        case connected, disconnected, reconnecting
    }

    init(baseURL: URL = URL(string: "ws://localhost:8000")!) {
        self.baseURL = baseURL
        super.init()
    }

    // MARK: - Auto-Connect for Live Mode

    /// Called when the app determines it is in Live mode. Connects to the
    /// WebSocket endpoint and subscribes to all well-known channels.
    func connectForLiveMode() {
        guard connectionState == .disconnected else { return }
        NSLog("[PulseDesk:WS] Connecting for live mode")
        connect()
        subscribeToDefaultChannels()
    }

    /// Subscribe to all well-known channels
    func subscribeToDefaultChannels() {
        let channels = Channel.allCases.map(\.rawValue)
        subscribe(channels)
    }

    // MARK: - Connection Lifecycle

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
        NSLog("[PulseDesk:WS] Disconnected")
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
            // Generic callback
            onMessage?(channel, payload)
            // Channel-specific NotificationCenter broadcast
            broadcastChannelEvent(channel: channel, payload: payload)
        }
    }

    // MARK: - Channel Event Broadcasting

    private func broadcastChannelEvent(channel: String, payload: [String: Any]) {
        guard let ch = Channel(rawValue: channel) else { return }
        switch ch {
        case .kpiUpdate:
            lastKPIPayload = payload
            NotificationCenter.default.post(name: .wsKPIUpdate, object: self, userInfo: payload)
        case .signalNew:
            lastSignalPayload = payload
            NotificationCenter.default.post(name: .wsSignalNew, object: self, userInfo: payload)
        case .dryrunStatus:
            lastDryrunPayload = payload
            NotificationCenter.default.post(name: .wsDryrunStatus, object: self, userInfo: payload)
        }
    }

    // MARK: - Reconnection & Heartbeat

    private func handleDisconnect() {
        isConnected = false
        connectionState = .disconnected
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            NSLog("[PulseDesk:WS] Attempting reconnect")
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
        NSLog("[PulseDesk:WS] Connected")

        if !subscribedChannels.isEmpty {
            subscribe(Array(subscribedChannels))
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}
