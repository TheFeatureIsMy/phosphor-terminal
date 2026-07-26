// APISettings.swift - Settings API 封装
// GET/PUT /auth/settings - 云端持久化用户设置
// GET/PUT/DELETE /api/admin/system-settings - 系统级设置

import Foundation

struct UserSettingsResponse: Decodable, Sendable {
    let id: Int
    let userId: Int
    let theme: String
    let language: String
    let notificationsEnabled: Bool
    let defaultExchange: String
    let defaultMarket: String
    let riskTolerance: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case theme, language
        case notificationsEnabled = "notifications_enabled"
        case defaultExchange = "default_exchange"
        case defaultMarket = "default_market"
        case riskTolerance = "risk_tolerance"
    }
}

struct UserSettingsUpdateBody: Encodable, Sendable {
    let theme: String?
    let language: String?
    let notificationsEnabled: Bool?
    let defaultExchange: String?
    let defaultMarket: String?
    let riskTolerance: String?

    enum CodingKeys: String, CodingKey {
        case theme, language
        case notificationsEnabled = "notifications_enabled"
        case defaultExchange = "default_exchange"
        case defaultMarket = "default_market"
        case riskTolerance = "risk_tolerance"
    }
}

struct SystemSettingView: Codable, Identifiable {
    let id: Int
    let key: String
    let value: AnyCodable
    let category: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, key, value, category
        case updatedAt = "updated_at"
    }
}

struct SystemSettingUpsertBody: Encodable {
    let value: AnyCodable
    let category: String?
    let updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case value, category
        case updatedBy = "updated_by"
    }
}

struct APISettings {
    let client: any NetworkClientProtocol

    func fetch() async throws -> UserSettingsResponse {
        try await client.get("/auth/settings")
    }

    func update(_ body: UserSettingsUpdateBody) async throws -> UserSettingsResponse {
        try await client.put("/auth/settings", body: body)
    }

    func listSystemSettings(category: String? = nil) async throws -> [SystemSettingView] {
        let endpoint = category != nil ? "/api/admin/system-settings?category=\(category!)" : "/api/admin/system-settings"
        return try await client.get(endpoint)
    }

    func getSystemSetting(key: String) async throws -> SystemSettingView {
        try await client.get("/api/admin/system-settings/\(key)")
    }

    func upsertSystemSetting(key: String, value: AnyCodable, category: String? = nil) async throws -> SystemSettingView {
        let body = SystemSettingUpsertBody(value: value, category: category, updatedBy: "ui")
        return try await client.put("/api/admin/system-settings/\(key)", body: body)
    }

    func deleteSystemSetting(key: String) async throws {
        try await client.delete("/api/admin/system-settings/\(key)")
    }
}
