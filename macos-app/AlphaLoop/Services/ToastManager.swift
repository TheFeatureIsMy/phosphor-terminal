// ToastManager.swift — 全局 Toast 通知管理器（支持多条同时显示）

import SwiftUI

@Observable
@MainActor
final class ToastManager {
    var toasts: [Toast] = []

    func show(_ message: String, type: ToastType = .info, duration: TimeInterval = 3) {
        let toast = Toast(message: message, type: type)
        toasts.append(toast)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            toasts.removeAll { $0.id == toast.id }
        }
    }

    func success(_ message: String) { show(message, type: .success) }
    func error(_ message: String) { show(message, type: .error, duration: 5) }
    func warning(_ message: String) { show(message, type: .warning, duration: 4) }
    func info(_ message: String) { show(message, type: .info) }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}
