// APISessions.swift — 登录设备会话
import Foundation

private struct RevokeSessionResponse: Codable {
    let status: String
    let session_id: String
}

struct DeviceSessionInfo: Codable, Identifiable {
    let id: String
    let device_name: String?
    let ip_address: String?
    let created_at: String
    let last_seen_at: String
    let revoked: Bool
}

struct APISessions {
    let client: NetworkClientProtocol

    func list() async throws -> [DeviceSessionInfo] {
        try await client.get("/auth/sessions")
    }

    func revoke(id: String) async throws {
        let _: RevokeSessionResponse = try await client.post(
            "/auth/sessions/\(id)/revoke", body: Optional<Int>.none,
        )
    }

    static func currentSessionID() -> String? {
        guard let token = KeychainService.accessToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["sid"] as? String
    }
}
