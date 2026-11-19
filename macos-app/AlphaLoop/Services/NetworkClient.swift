// NetworkClient.swift — 双模式网络客户端
// MockNetworkClient: 模拟数据 + 随机延迟
// LiveNetworkClient: 真实 URLSession 请求

import Foundation
import Security
import SwiftUI

// MARK: - Environment Key for NetworkClient
private struct NetworkClientKey: EnvironmentKey {
    static let defaultValue: any NetworkClientProtocol = LiveNetworkClient()
}

extension EnvironmentValues {
    var networkClient: any NetworkClientProtocol {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }
}


// MARK: - Default mock-free overloads (for real API calls that never fall back to mock data)

extension NetworkClientProtocol {
    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        try await get(endpoint) { () -> T in fatalError("MockNetworkClient has no mock for \(endpoint). Real API calls require LiveNetworkClient.") }
    }

    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?) async throws -> T {
        try await post(endpoint, body: body) { () -> T in fatalError("MockNetworkClient has no mock for \(endpoint). Real API calls require LiveNetworkClient.") }
    }

    func postForm<T: Decodable>(_ endpoint: String, formFields: [String: String]) async throws -> T {
        try await postForm(endpoint, formFields: formFields) { () -> T in fatalError("MockNetworkClient has no mock for \(endpoint). Real API calls require LiveNetworkClient.") }
    }

    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?) async throws -> T {
        try await put(endpoint, body: body) { () -> T in fatalError("MockNetworkClient has no mock for \(endpoint). Real API calls require LiveNetworkClient.") }
    }

    func patch<T: Decodable>(_ endpoint: String, body: (any Encodable)?) async throws -> T {
        try await patch(endpoint, body: body) { () -> T in fatalError("MockNetworkClient has no mock for \(endpoint). Real API calls require LiveNetworkClient.") }
    }

    func delete(_ endpoint: String) async throws {
        try await delete(endpoint) {}
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
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let err): return "Decode error: \(err.localizedDescription)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - 网络客户端协议
protocol NetworkClientProtocol: Sendable {
    var baseURL: URL { get }
    func get<T: Decodable>(_ endpoint: String, mock: @escaping @Sendable () -> T) async throws -> T
    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T
    func postForm<T: Decodable>(_ endpoint: String, formFields: [String: String], mock: @escaping @Sendable () -> T) async throws -> T
    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T
    func patch<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T
    func delete(_ endpoint: String, mock: @escaping @Sendable () -> Void) async throws
}

// MARK: - 模拟网络客户端
final class MockNetworkClient: NetworkClientProtocol, @unchecked Sendable {
    let baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL
    }

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

    func patch<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
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

    /// Synchronous-ish health check — returns true if backend responds within given timeout
    static func isBackendReachable(baseURL: URL = URL(string: "http://localhost:8000")!, timeout: TimeInterval = 2) async -> Bool {
        let url = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 400 {
                return true
            }
            return false
        } catch {
            return false
        }
    }

    private func buildURL(_ endpoint: String) -> URL {
        if endpoint.contains("?") {
            let parts = endpoint.split(separator: "?", maxSplits: 1)
            let path = String(parts[0])
            let query = parts.count > 1 ? String(parts[1]) : ""
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            components.path += path.hasPrefix("/") ? path : "/\(path)"
            // endpoint 的 query 段调用方已百分号编码，用 percentEncodedQuery 直接赋值，
            // 避免 .query setter 再编码一次（%2F → %252F）
            components.percentEncodedQuery = query.isEmpty ? nil : query
            return components.url!
        }
        return baseURL.appendingPathComponent(endpoint)
    }

    func get<T: Decodable>(_ endpoint: String, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = buildURL(endpoint)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        return try await performRequest(request)
    }

    func post<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = buildURL(endpoint)
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
        let url = buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // x-www-form-urlencoded 需转义 + & = 等；.urlQueryAllowed 会漏掉它们导致 body 被截断/误解析
        let bodyString = formFields
            .map { key, value in
                "\(key.formURLEncoded)=\(value.formURLEncoded)"
            }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        return try await performRequest(request)
    }

    func put<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = buildURL(endpoint)
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

    func patch<T: Decodable>(_ endpoint: String, body: (any Encodable)?, mock: @escaping @Sendable () -> T) async throws -> T {
        let url = buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await performRequest(request)
    }

    func delete(_ endpoint: String, mock: @escaping @Sendable () -> Void) async throws {
        let url = buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")

        var (data, response) = try await URLSession.shared.data(for: request)
        var httpResponse = response as? HTTPURLResponse

        if httpResponse?.statusCode == 401, KeychainService.refreshToken != nil {
            try await refreshTokenIfNeeded()
            request.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
            httpResponse = response as? HTTPURLResponse
        }

        guard let code = httpResponse?.statusCode, code < 400 else {
            let code = httpResponse?.statusCode ?? 0
            let message = String(data: data, encoding: .utf8) ?? "Delete failed"
            throw APIError.httpError(statusCode: code, message: message)
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

        let (data, response) = try await URLSession.shared.data(for: currentRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401, KeychainService.refreshToken != nil {
            try await refreshTokenIfNeeded()

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

// MARK: - Token storage
// iOS: real Keychain so a relaunch keeps the session.
// macOS: in-memory (login is bypassed and unsigned SPM builds trigger prompts).
enum KeychainService {
#if os(iOS)
    private static let service = "com.alphaloop.auth"
    private static let accessAccount = "accessToken"
    private static let refreshAccount = "refreshToken"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _accessToken: String?
    nonisolated(unsafe) private static var _refreshToken: String?
    nonisolated(unsafe) private static var _loaded = false

    static var accessToken: String? {
        get { _read(accessAccount) }
        set { _write(newValue, account: accessAccount) }
    }

    static var refreshToken: String? {
        get { _read(refreshAccount) }
        set { _write(newValue, account: refreshAccount) }
    }

    static func clear() {
        accessToken = nil
        refreshToken = nil
    }

    private static func _read(_ account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeededLocked()
        return account == accessAccount ? _accessToken : _refreshToken
    }

    private static func _write(_ value: String?, account: String) {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeededLocked()
        if account == accessAccount { _accessToken = value } else { _refreshToken = value }
        if let value, !value.isEmpty {
            writeKeychain(value, account: account)
        } else {
            deleteKeychain(account: account)
        }
    }

    private static func loadIfNeededLocked() {
        guard !_loaded else { return }
        _loaded = true
        _accessToken = readKeychain(accessAccount)
        _refreshToken = readKeychain(refreshAccount)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func readKeychain(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeKeychain(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private static func deleteKeychain(account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
#else
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _accessToken: String?
    nonisolated(unsafe) private static var _refreshToken: String?

    static var accessToken: String? {
        get { lock.lock(); defer { lock.unlock() }; return _accessToken }
        set { lock.lock(); defer { lock.unlock() }; _accessToken = newValue }
    }

    static var refreshToken: String? {
        get { lock.lock(); defer { lock.unlock() }; return _refreshToken }
        set { lock.lock(); defer { lock.unlock() }; _refreshToken = newValue }
    }

    static func clear() {
        accessToken = nil
        refreshToken = nil
    }
#endif
}

// MARK: - x-www-form-urlencoded 编码
private extension String {
    /// 按 application/x-www-form-urlencoded 规则转义：仅保留 unreserved 字符（A-Z a-z 0-9 - . _ ~），
    /// 其余（含 + & = / 空格）全部百分号编码，避免凭据里的特殊字符破坏 body。
    var formURLEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
