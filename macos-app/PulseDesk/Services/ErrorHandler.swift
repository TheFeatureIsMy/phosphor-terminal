// ErrorHandler.swift — 统一错误处理

import Foundation
import SwiftUI

@Observable
@MainActor
final class ErrorHandler {
    var currentError: AppError?
    var showError = false

    func handle(_ error: Error, context: String = "") {
        let appError: AppError
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let code, let msg):
                if code == 401 {
                    appError = .auth(msg)
                } else if code >= 500 {
                    appError = .server(msg)
                } else {
                    appError = .business(msg)
                }
            case .networkError:
                appError = .network("网络连接失败，请检查后端服务")
            case .decodingError:
                appError = .server("数据解析错误")
            case .invalidURL:
                appError = .server("请求地址无效")
            }
        } else {
            appError = .business(error.localizedDescription)
        }

        currentError = appError
        showError = true
    }

    func dismiss() {
        currentError = nil
        showError = false
    }
}

enum AppError: Error, LocalizedError {
    case network(String)
    case auth(String)
    case business(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return msg
        case .auth(let msg): return "认证失败: \(msg)"
        case .business(let msg): return msg
        case .server(let msg): return "服务异常: \(msg)"
        }
    }

    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .auth: return "lock.shield"
        case .business: return "exclamationmark.triangle"
        case .server: return "server.rack"
        }
    }

    var color: Color {
        switch self {
        case .network: return PulseColors.warning
        case .auth: return PulseColors.danger
        case .business: return PulseColors.warning
        case .server: return PulseColors.danger
        }
    }
}
