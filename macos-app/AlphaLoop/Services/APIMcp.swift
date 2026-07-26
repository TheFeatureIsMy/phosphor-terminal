// APIMcp.swift - MCP (Model Context Protocol) status, audit logs, token rotation

import Foundation

final class APIMcp: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func getStatus() async throws -> McpStatusInfo {
        try await client.get("/api/mcp/status")
    }

    func listAuditLogs(limit: Int = 50) async throws -> [McpAuditLogEntry] {
        try await client.get("/api/mcp/audit-logs?limit=\(limit)")
    }

    func rotateToken(reason: String? = nil) async throws -> McpTokenRotateResult {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        return try await client.post("/api/mcp/rotate-token", body: body.isEmpty ? nil : AnyEncodable(body))
    }
}
