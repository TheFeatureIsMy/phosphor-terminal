// APIServiceTests.swift — Tests for all API service mock data returns
// Verifies that MockNetworkClient returns valid decodable data for every API endpoint

import Testing
import Foundation
@testable import AlphaLoop

@Suite("API Service Tests")
struct APIServiceTests {

    let client = MockNetworkClient()

    // MARK: - APIOverview

    @Test func overviewGetDashboard() async throws {
        let api = APIOverview(client: client)
        let result = try await api.getDashboard()
        #expect(!result.state.isEmpty)
        #expect(result.account.equity > 0)
        #expect(!result.account.currency.isEmpty)
    }

    @Test func overviewGetLiveReadiness() async throws {
        let api = APIOverview(client: client)
        let result = try await api.getLiveReadiness()
        #expect(result.score > 0)
        #expect(!result.state.isEmpty)
        #expect(!result.checks.isEmpty)
    }

    @Test func overviewRunReadinessCheck() async throws {
        let api = APIOverview(client: client)
        let result = try await api.runReadinessCheck()
        #expect(result.score > 0)
    }

    @Test func overviewGetGlobalStatus() async throws {
        let api = APIOverview(client: client)
        let result = try await api.getGlobalStatus()
        #expect(!result.systemState.isEmpty)
        #expect(!result.riskState.isEmpty)
        #expect(result.fastTrackLatencyMs > 0)
    }

    // MARK: - APIExecutionBFF

    @Test func executionBFFGetCenter() async throws {
        let api = APIExecutionBFF(client: client)
        let result = try await api.getCenter()
        #expect(!result.state.isEmpty)
        #expect(result.totalRunning > 0)
        #expect(!result.sessions.isEmpty)
        #expect(result.executionLatencyMs > 0)
    }

    @Test func executionBFFGetOrdersPositions() async throws {
        let api = APIExecutionBFF(client: client)
        let result = try await api.getOrdersPositions()
        #expect(!result.orders.isEmpty)
        #expect(!result.positions.isEmpty)
        #expect(result.positions[0].quantity > 0)
    }

    @Test func executionBFFGetReconciliationBus() async throws {
        let api = APIExecutionBFF(client: client)
        let result = try await api.getReconciliationBus()
        #expect(!result.recentCommands.isEmpty)
        #expect(!result.reconciliationRuns.isEmpty)
    }

    // MARK: - APIRiskBFF

    @Test func riskBFFGetOverview() async throws {
        let api = APIRiskBFF(client: client)
        let result = try await api.getOverview()
        #expect(!result.state.isEmpty)
        #expect(!result.guards.isEmpty)
        #expect(!result.availableActions.isEmpty)
    }

    @Test func riskBFFGetStopProtection() async throws {
        let api = APIRiskBFF(client: client)
        let result = try await api.getStopProtection()
        #expect(!result.state.isEmpty)
        #expect(!result.positions.isEmpty)
        #expect(result.positions[0].stops.rawStructureStop != nil)
    }

    @Test func riskBFFGetCircuitBreakers() async throws {
        let api = APIRiskBFF(client: client)
        let result = try await api.getCircuitBreakers()
        #expect(!result.records.isEmpty)
        #expect(result.totalCount > 0)
    }

    @Test func riskBFFEmergencyStop() async throws {
        let api = APIRiskBFF(client: client)
        let result = try await api.emergencyStop()
        #expect(!result.stoppedRuns.isEmpty)
        #expect(!result.message.isEmpty)
    }

    // MARK: - APIStructureBFF

    @Test func structureBFFGetMatrix() async throws {
        let api = APIStructureBFF(client: client)
        let result = try await api.getMatrix()
        #expect(!result.state.isEmpty)
        #expect(!result.rows.isEmpty)
        #expect(result.symbol == "BTC/USDT")
        #expect(!result.rows[0].cells.isEmpty)
    }

    // MARK: - APIMarketStructure

    @Test func marketStructureGetMarketView() async throws {
        let api = APIMarketStructure(client: client)
        let result = try await api.getMarketView()
        #expect(!result.state.isEmpty)
        #expect(result.symbol == "BTC/USDT")
        #expect(!result.zones.isEmpty)
        #expect(!result.liquidityPools.isEmpty)
        #expect(!result.events.isEmpty)
        #expect(result.structureScore > 0)
        #expect(!result.marketRegime.isEmpty)
    }

    // MARK: - APIFailureClustering

    @Test func failureClusteringGetSummary() async throws {
        let api = APIFailureClustering(client: client)
        let result = try await api.getSummary()
        #expect(!result.state.isEmpty)
        #expect(!result.clusters.isEmpty)
        #expect(result.totalLossTrades > 0)
        #expect(result.totalLossAmount < 0)
        #expect(!result.regimeMatrix.isEmpty)
        #expect(!result.labels.isEmpty)
    }

    @Test func failureClusteringGetLabels() async throws {
        let api = APIFailureClustering(client: client)
        let result = try await api.getLabels()
        #expect(!result.isEmpty)
    }

    // MARK: - APIDataSources

    @Test func dataSourcesGetAll() async throws {
        let api = APIDataSources(client: client)
        let result = try await api.getAll()
        #expect(!result.state.isEmpty)
        #expect(!result.sources.isEmpty)
        #expect(result.totalActive > 0)
    }

    @Test func dataSourcesTestConnection() async throws {
        let api = APIDataSources(client: client)
        let result = try await api.testConnection("ds-001")
        #expect(result["status"] == "ok")
    }

    @Test func dataSourcesEnable() async throws {
        let api = APIDataSources(client: client)
        let result = try await api.enable("ds-001")
        #expect(result["status"] == "enabled")
    }

    @Test func dataSourcesDisable() async throws {
        let api = APIDataSources(client: client)
        let result = try await api.disable("ds-001")
        #expect(result["status"] == "disabled")
    }

    // MARK: - APIStrategiesV2

    @Test func strategiesV2List() async throws {
        let api = APIStrategiesV2(client: client)
        let result = try await api.list()
        #expect(!result.isEmpty)
        #expect(!result[0].name.isEmpty)
    }

    @Test func strategiesV2Create() async throws {
        let api = APIStrategiesV2(client: client)
        let result = try await api.create(name: "Test Strategy")
        #expect(result.name == "Test Strategy")
        #expect(result.status == "draft")
    }

    @Test func strategiesV2ValidateDSL() async throws {
        let api = APIStrategiesV2(client: client)
        let result = try await api.validateDSL(["entry": "rsi < 30"])
        #expect(result.valid == true)
        #expect(result.errorCount == 0)
    }

    // MARK: - APIGrowth

    @Test func growthListReports() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.listReports()
        #expect(!result.isEmpty)
        #expect(!result[0].reportType.isEmpty)
    }

    @Test func growthListCandidates() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.listCandidates()
        #expect(!result.isEmpty)
        #expect(result[0].confidence != nil)
    }

    @Test func growthConfirmCandidate() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.confirmCandidate("test-id")
        #expect(result.status == "confirmed")
    }

    @Test func growthRunDailyReview() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.runDailyReview(["trigger": "manual"])
        #expect(result.reportType == "daily_review")
        #expect(result.status == "completed")
    }

    @Test func growthGetShapFeatures() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.getShapFeatures()
        #expect(result.state == "healthy")
        #expect(!result.features.isEmpty)
        #expect(result.features[0].value > 0)
    }

    @Test func growthGetSignalValidity() async throws {
        let api = APIGrowth(client: client)
        let result = try await api.getSignalValidity()
        #expect(result.state == "healthy")
        #expect(!result.sources.isEmpty)
        #expect(result.sources[0].accuracy > 0)
    }

    // MARK: - APISignalsV2

    @Test func signalsV2ListSignals() async throws {
        let api = APISignalsV2(client: client)
        let result = try await api.listSignals()
        #expect(!result.isEmpty)
        #expect(!result[0].symbol.isEmpty)
        #expect(result[0].confidence != nil)
    }

    @Test func signalsV2CreateSignal() async throws {
        let api = APISignalsV2(client: client)
        let result = try await api.createSignal(["symbol": "BTC/USDT", "direction": "long"])
        #expect(!result.id.isEmpty)
        #expect(result.symbol == "BTC/USDT")
    }

    @Test func signalsV2TransitionSignal() async throws {
        let api = APISignalsV2(client: client)
        let result = try await api.transitionSignal("test-id", targetStatus: "active")
        #expect(result.status == "active")
    }

    @Test func signalsV2ArchiveSignal() async throws {
        let api = APISignalsV2(client: client)
        let result = try await api.archiveSignal("test-id")
        #expect(result.status == "archived")
    }

    @Test func signalsV2ConflictCheck() async throws {
        let api = APISignalsV2(client: client)
        let result = try await api.conflictCheck(symbol: "BTC/USDT", direction: "long")
        #expect(result.hasConflict == false)
    }

    // MARK: - APISentiment

    @Test func sentimentGetSummary() async throws {
        let api = APISentiment(client: client)
        let result = try await api.getSummary()
        #expect(result.fearGreedIndex > 0)
        #expect(!result.fearGreedLabel.isEmpty)
        #expect(!result.marketOverview.isEmpty)
    }

    @Test func sentimentAnalyzeText() async throws {
        let api = APISentiment(client: client)
        let result = try await api.analyzeText("BTC is going up!")
        #expect(result.positive > 0)
    }

    // MARK: - APIManipulation

    @Test func manipulationListScores() async throws {
        let api = APIManipulation(client: client)
        let result = try await api.listScores()
        #expect(!result.isEmpty)
        #expect(!result[0].symbol.isEmpty)
        #expect(!result[0].riskLevel.isEmpty)
    }

    @Test func manipulationScanSymbol() async throws {
        let api = APIManipulation(client: client)
        let result = try await api.scanSymbol(["symbol": "BTC/USDT"])
        #expect(!result.symbol.isEmpty)
        #expect(result.manipulationScore >= 0)
        #expect(!result.riskLevel.isEmpty)
    }

    // MARK: - APIDashboard

    @Test func dashboardGetEquityCurve() async throws {
        let api = APIDashboard(client: client)
        let result = try await api.getEquityCurve()
        #expect(!result.isEmpty)
    }

    @Test func dashboardGetRiskEvents() async throws {
        let api = APIDashboard(client: client)
        let _ = try await api.getRiskEvents()
        // Should not throw
    }

    // MARK: - NetworkClientProtocol extensions (Agent profiles/signals)

    @Test func listAgentProfiles() async throws {
        let result = try await client.listAgentProfiles()
        #expect(!result.isEmpty)
        #expect(!result[0].name.isEmpty)
    }

    @Test func listAgentSignals() async throws {
        let result = try await client.listAgentSignals()
        #expect(!result.isEmpty)
        #expect(!result[0].symbol.isEmpty)
    }
}
