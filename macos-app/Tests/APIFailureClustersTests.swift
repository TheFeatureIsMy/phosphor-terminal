// APIFailureClustersTests.swift — Tests for failure-clusters API service
// Verifies mock mode returns empty array (no fake history per spec)

import Testing
import Foundation
@testable import AlphaLoop

@Suite("APIFailureClusters Tests")
struct APIFailureClustersTests {

    let client = MockNetworkClient()

    @Test func getFailureClustersMockReturnsEmpty() async throws {
        let clusters = try await client.getFailureClusters(strategyUuid: UUID())
        #expect(clusters.isEmpty)
    }
}
