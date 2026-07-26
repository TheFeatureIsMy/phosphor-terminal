// APIFailureClustersTests.swift - Tests for failure-clusters API service
// Disabled: API no longer uses mock fallback; requires live backend.

import Testing
import Foundation
@testable import AlphaLoop

@Suite("APIFailureClusters Tests")
struct APIFailureClustersTests {

    let client = MockNetworkClient()

    @Test(.disabled("Requires live backend - failure clusters API no longer uses mock fallback"))
    func getFailureClustersReturnsData() async throws {
        let clusters = try await client.getFailureClusters(strategyUuid: UUID())
        #expect(clusters.isEmpty)
    }
}
