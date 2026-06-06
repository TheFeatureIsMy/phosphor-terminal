// APIMcp.swift — MCP (Model Context Protocol) status, audit logs, token rotation

import Foundation

final class APIMcp: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Status

    func getStatus() async throws -> McpStatusInfo {
        try await client.get("/api/v2/mcp/status", mock: {
            McpStatusInfo(
                enabled: true,
                bindAddress: "127.0.0.1:8080",
                totalRequests: 1_247,
                lastRequestAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }

    // MARK: - Audit Logs

    func listAuditLogs(limit: Int = 50) async throws -> [McpAuditLogEntry] {
        try await client.get("/api/v2/mcp/audit-logs?limit=\(limit)", mock: {
            MockMcpData.auditLogs()
        })
    }

    // MARK: - Token Rotation

    func rotateToken(reason: String? = nil) async throws -> McpTokenRotateResult {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        return try await client.post("/api/v2/mcp/rotate-token", body: body.isEmpty ? nil : AnyEncodable(body), mock: {
            McpTokenRotateResult(
                newToken: "mcp_sk_new_token_7f2a",
                oldTokenRevoked: true
            )
        })
    }
}

// MARK: - Mock data

enum MockMcpData {
    static func auditLogs() -> [McpAuditLogEntry] {
        [
            McpAuditLogEntry(
                id: "log-001",
                toolName: "get_market_data",
                responseStatus: 200,
                latencyMs: 145,
                createdAt: "2026-06-05T03:12:45Z"
            ),
            McpAuditLogEntry(
                id: "log-002",
                toolName: "resource_read",
                responseStatus: 200,
                latencyMs: 32,
                createdAt: "2026-06-05T03:11:20Z"
            ),
            McpAuditLogEntry(
                id: "log-003",
                toolName: "execute_trade",
                responseStatus: 500,
                latencyMs: 890,
                createdAt: "2026-06-05T03:10:05Z"
            ),
            McpAuditLogEntry(
                id: "log-004",
                toolName: "analyze_sentiment",
                responseStatus: 200,
                latencyMs: 2340,
                createdAt: "2026-06-05T03:08:30Z"
            ),
        ]
    }
}
