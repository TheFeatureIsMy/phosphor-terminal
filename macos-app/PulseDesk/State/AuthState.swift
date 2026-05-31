// AuthState.swift — 认证状态
// 替代 Zustand auth-store.ts

import SwiftUI

@Observable
final class AuthState {
    var user: User?
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    /// Mock 用户（开发模式）
    static let mockUser = User(
        id: 1, name: "Trader", email: "trader@pulsedesk.io",
        telegramId: nil, role: "trader",
        createdAt: ISO8601DateFormatter().string(from: Date()),
        updatedAt: ISO8601DateFormatter().string(from: Date())
    )

    /// 使用 mock 数据登录
    func mockLogin() {
        user = Self.mockUser
        isAuthenticated = true
        errorMessage = nil
    }

    /// 真实登录：POST /auth/login（form-encoded）
    @MainActor
    func login(email: String, password: String, client: any NetworkClientProtocol) async {
        isLoading = true
        errorMessage = nil
        do {
            let api = APIAuth(client: client)
            let tokenResponse = try await api.login(email: email, password: password)
            KeychainService.accessToken = tokenResponse.accessToken
            KeychainService.refreshToken = tokenResponse.refreshToken
            // 获取当前用户信息
            let fetchedUser = try await api.getMe()
            user = fetchedUser
            isAuthenticated = true
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    /// 注册：POST /auth/register
    @MainActor
    func register(username: String, email: String, password: String, client: any NetworkClientProtocol) async {
        isLoading = true
        errorMessage = nil
        do {
            let api = APIAuth(client: client)
            _ = try await api.register(username: username, email: email, password: password)
            // 注册成功后自动登录
            await login(email: email, password: password, client: client)
        } catch {
            errorMessage = mapAuthError(error)
            isLoading = false
        }
    }

    /// 登出
    func logout() {
        user = nil
        isAuthenticated = false
        errorMessage = nil
        KeychainService.accessToken = nil
        KeychainService.refreshToken = nil
    }

    // MARK: - 错误映射
    private func mapAuthError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let code, _):
                if code == 401 { return "邮箱或密码错误" }
                if code == 400 { return "请求参数无效" }
                if code == 409 { return "用户名或邮箱已被注册" }
                return "服务器错误 (\(code))"
            case .networkError:
                return "网络连接失败，请检查后端服务"
            case .decodingError:
                return "响应解析失败"
            case .invalidURL:
                return "请求地址无效"
            }
        }
        return "登录失败: \(error.localizedDescription)"
    }
}
