// APIServiceManagement.swift - Unified service health API

import Foundation

struct ServiceStatusItem: Identifiable {
    var id: String { name }
    let name: String
    let status: String
    var detail: String?
    var error: String?
    var version: String?
    var usedMemoryMb: Double?
    var connectedClients: Int?
    var openPositions: Int?
    var models: [String]?
}

struct ServiceStatusResponse {
    let state: String
    let services: [ServiceStatusItem]
    let checkedAt: String
}

extension ServiceStatusResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case state, services
        case checkedAt = "checked_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(String.self, forKey: .state)
        checkedAt = try container.decode(String.self, forKey: .checkedAt)

        let servicesDict = try container.decode([String: [String: AnyCodable]].self, forKey: .services)
        services = servicesDict.map { key, value in
            ServiceStatusItem(
                name: key,
                status: (value["status"]?.value as? String) ?? "unknown",
                detail: value["detail"]?.value as? String,
                error: value["error"]?.value as? String,
                version: value["version"]?.value as? String,
                usedMemoryMb: (value["used_memory_mb"]?.value as? Double),
                connectedClients: (value["connected_clients"]?.value as? Int),
                openPositions: (value["open_positions"]?.value as? Int),
                models: (value["models"]?.value as? [String])
            )
        }.sorted { $0.name < $1.name }
    }
}

struct APIServiceManagement {
    let client: NetworkClientProtocol

    func getServiceStatus() async throws -> ServiceStatusResponse {
        try await client.get("/api/system/services")
    }

    func getDependencies() async throws -> [String: AnyCodable] {
        try await client.get("/api/system/dependencies")
    }
}
