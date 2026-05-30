// APISettings.swift — Settings API 封装
// GET/PUT /auth/settings — 云端持久化用户设置

import Foundation

// MARK: - 响应模型

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

// MARK: - 请求体

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

// MARK: - API 服务

struct APISettings {
    let client: any NetworkClientProtocol

    /// GET /auth/settings — 获取当前用户设置
    func fetch() async throws -> UserSettingsResponse {
        try await client.get("/auth/settings", mock: mockSettings)
    }

    /// PUT /auth/settings — 更新用户设置（部分更新）
    func update(_ body: UserSettingsUpdateBody) async throws -> UserSettingsResponse {
        try await client.put("/auth/settings", body: body, mock: {
            UserSettingsResponse(
                id: 1,
                userId: 1,
                theme: body.theme ?? "dark",
                language: body.language ?? "zh-CN",
                notificationsEnabled: body.notificationsEnabled ?? true,
                defaultExchange: body.defaultExchange ?? "binance",
                defaultMarket: body.defaultMarket ?? "crypto",
                riskTolerance: body.riskTolerance ?? "medium"
            )
        })
    }

    // MARK: - Mock 数据

    private func mockSettings() -> UserSettingsResponse {
        UserSettingsResponse(
            id: 1,
            userId: 1,
            theme: "dark",
            language: "zh-CN",
            notificationsEnabled: true,
            defaultExchange: "binance",
            defaultMarket: "crypto",
            riskTolerance: "medium"
        )
    }
}
