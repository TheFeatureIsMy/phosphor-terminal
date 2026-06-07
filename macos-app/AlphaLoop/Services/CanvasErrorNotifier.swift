import SwiftUI

@MainActor
@Observable
final class CanvasErrorNotifier {
    var currentToast: String?
    private var toastTask: Task<Void, Never>?
    private var consecutiveErrorCount = 0

    func showToast(_ message: String, duration: TimeInterval = 3) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = message
        }
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                currentToast = nil
            }
        }
    }

    func reportSaveError() {
        consecutiveErrorCount += 1
        if consecutiveErrorCount >= 3 {
            showToast("保存连续失败 \(consecutiveErrorCount) 次，请检查网络连接", duration: 5)
        } else {
            showToast("保存失败，10s 后重试")
        }
    }

    func reportSaveSuccess() {
        consecutiveErrorCount = 0
    }
}
