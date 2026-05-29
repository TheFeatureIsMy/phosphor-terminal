// ToastManager.swift — Toast 通知管理器

import SwiftUI

@Observable
@MainActor
final class ToastManager {
    var currentToast: ToastData?

    func show(_ type: ToastType, message: String, duration: TimeInterval = 3) {
        currentToast = ToastData(type: type, message: message)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if currentToast?.message == message {
                withAnimation { currentToast = nil }
            }
        }
    }
}

struct ToastData: Equatable {
    let type: ToastType
    let message: String
}
