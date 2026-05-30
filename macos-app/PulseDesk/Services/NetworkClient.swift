// NetworkClient.swift — 双模式网络客户端
// MockNetworkClient: 模拟数据 + 随机延迟
// LiveNetworkClient: 真实 URLSession 请求

import Foundation
import SwiftUI

// MARK: - Environment Key for NetworkClient
private struct NetworkClientKey: EnvironmentKey {
    static let defaultValue: any NetworkClientProtocol = MockNetworkClient()
}

extension EnvironmentValues {
    var networkClient: any NetworkClientProtocol {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }
}

// MARK: - API 错误
enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let err): return "解码错误: \(err.localizedDescription)"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        }
    }
}

// MARK: - 网络客户端协议
protocol NetworkClientProtocol: Sendable {
    func get<T: Decodable>(_ endpoint: String, mock: @escaping @Sendable () -> T) async throws -> T
    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T
    func postForm<T: Decodable>(_ endpoint: String, formFields: [String: String], mock: @escaping @Sendable () -> T) async throws -> T
    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T
    func delete(_ endpoint: String, mock: @escaping @Sendable () -> Void) async throws
}

// MARK: - 模拟网络客户端
final class MockNetworkClient: NetworkClientProtocol, @unchecked Sendable {
    func get<T: Decodable>(_ endpoint: String, mock: @escaping @Sendable () -> T) async throws -> T {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        return mock()
    }

    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        return mock()
    }

    func postForm<T: Decodable>(_ endpoint: String, formFields: [String: String], mock: @escaping @Sendable () -> T) async throws -> T {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        return mock()
    }

    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        return mock()
    }

    func delete(_ endpoint: String, mock: @escaping @Sendable () -> Void) async throws {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        mock()
    }
}

// MARK: - 真实网络客户端
final class LiveNetworkClient: NetworkClientProtocol, @unchecked Sendable {
    let baseURL: URL
    let timeout: TimeInterval = 15

    init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL
    }

    func get<T: Decodable>(_ endpoint: String, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        return try await performRequest(request)
    }

    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await performRequest(request)
    }

    func postForm<T: Decodable>(_ endpoint: String, formFields: [String: String], mock: @escaping @Sendable () -> T) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = formFields
            .map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        return try await performRequest(request)
    }

    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await performRequest(request)
    }

    func delete(_ endpoint: String, mock: @escaping @Sendable () -> Void) async throws {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(statusCode: code, message: "Delete failed")
        }
    }

    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = KeychainService.refreshToken else { return }

        let url = baseURL.appendingPathComponent("auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            KeychainService.accessToken = nil
            KeychainService.refreshToken = nil
            throw APIError.httpError(statusCode: 401, message: "Token refresh failed")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainService.accessToken = tokenResponse.accessToken
        KeychainService.refreshToken = tokenResponse.refreshToken
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        var currentRequest = request

        // First attempt
        let (data, response) = try await URLSession.shared.data(for: currentRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        // If 401, try refreshing token once
        if httpResponse.statusCode == 401, KeychainService.refreshToken != nil {
            try await refreshTokenIfNeeded()

            // Retry with new token
            currentRequest.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: currentRequest)
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse, retryHttpResponse.statusCode < 400 else {
                let code = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0
                let message = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(statusCode: code, message: message)
            }
            do {
                return try JSONDecoder().decode(T.self, from: retryData)
            } catch {
                throw APIError.decodingError(error)
            }
        }

        guard httpResponse.statusCode < 400 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Keychain 服务（简化版）
enum KeychainService {
    nonisolated(unsafe) static var accessToken: String?
    nonisolated(unsafe) static var refreshToken: String?
}
