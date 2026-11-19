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
        ])
    }

    /// POST /auth/register — JSON body
    func register(username: String, email: String, password: String) async throws -> User {
        let body = RegisterBody(username: username, email: email, password: password)
        return try await client.post("/auth/register", body: body)
    }

    /// GET /auth/me — Bearer token 认证
    func getMe() async throws -> User {
        try await client.get("/auth/me")
    }

    /// GET /auth/tenant — 当前用户所属租户
    func getTenant() async throws -> TenantInfo {
        try await client.get("/auth/tenant")
    }

    /// PUT /api/admin/tenant-plan — 超级管理员修改套餐
    func updateTenantPlan(_ plan: String) async throws -> TenantPlanInfo {
        try await client.put("/api/admin/tenant-plan", body: ["plan": plan])
    }
}

/// 当前租户（GET /auth/tenant）
struct TenantInfo: Codable {
    let id: Int
    let name: String
    let slug: String
    let role: String
    let plan: String?
}

// MARK: - 请求体

/// 注册请求体（对应后端 UserCreate schema）
struct RegisterBody: Encodable {
    let username: String
    let email: String
    let password: String
}

struct TenantPlanInfo: Codable {
    let tenantId: Int?
    let plan: String
    let limits: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case plan, limits
        case tenantId = "tenant_id"
    }
}
