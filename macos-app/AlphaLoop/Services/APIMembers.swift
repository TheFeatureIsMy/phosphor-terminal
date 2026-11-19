// APIMembers.swift — 租户成员管理
import Foundation

struct TenantMember: Codable, Identifiable {
    let user_id: Int
    let username: String
    let email: String
    let role: String
    let is_active: Bool

    var id: Int { user_id }
}

private struct NewMemberBody: Encodable {
    let username: String
    let email: String
    let password: String
    let role: String
}

struct APIMembers {
    let client: NetworkClientProtocol

    func list() async throws -> [TenantMember] {
        try await client.get("/auth/members")
    }

    func add(username: String, email: String, password: String, role: String) async throws -> TenantMember {
        let body = NewMemberBody(username: username, email: email, password: password, role: role)
        return try await client.post("/auth/members", body: body)
    }

    func updateRole(userId: Int, role: String) async throws -> TenantMember {
        try await client.patch("/auth/members/\(userId)", body: ["role": role])
    }

    func remove(userId: Int) async throws {
        try await client.delete("/auth/members/\(userId)")
    }
}
