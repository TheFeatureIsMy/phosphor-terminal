// APIAuth.swift — 认证相关 API
// login 使用 form-encoded（OAuth2PasswordRequestForm）
// register / getMe 使用 JSON

import Foundation

struct APIAuth {
    let client: NetworkClientProtocol

    /// POST /auth/login — form-encoded（OAuth2 Password Grant）
    func login(email: String, password: String) async throws -> TokenResponse {
        try await client.postForm("/auth/login", formFields: [
            "username": email,
            "password": password,
        ], mock: MockData.mockTokenResponse)
    }

    /// POST /auth/register — JSON body
    func register(username: String, email: String, password: String) async throws -> User {
        let body = RegisterBody(username: username, email: email, password: password)
        return try await client.post("/auth/register", body: body, mock: MockData.mockRegisterUser)
    }

    /// GET /auth/me — Bearer token 认证
    func getMe() async throws -> User {
        try await client.get("/auth/me", mock: MockData.mockRegisterUser)
    }
}

// MARK: - 请求体

/// 注册请求体（对应后端 UserCreate schema）
struct RegisterBody: Encodable {
    let username: String
    let email: String
    let password: String
}
