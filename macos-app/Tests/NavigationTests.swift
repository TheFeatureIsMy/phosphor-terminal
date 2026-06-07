// NavigationTests.swift — Tests for AppRoute navigation metadata
// Verifies all routes have proper labels, icons, sections, and visibility settings

import Testing
import Foundation
@testable import AlphaLoop

@Suite("Navigation Tests")
struct NavigationTests {

    @Test func allRoutesHaveLabels() {
        for route in AppRoute.allCases {
            #expect(!route.label.isEmpty, "Route \(route.rawValue) has empty label")
        }
    }

    @Test func allRoutesHaveIcons() {
        for route in AppRoute.allCases {
            #expect(!route.icon.isEmpty, "Route \(route.rawValue) has empty icon")
        }
    }

    @Test func allRoutesHaveSections() {
        for route in AppRoute.allCases {
            let section = route.section
            #expect(!section.rawValue.isEmpty, "Route \(route.rawValue) has empty section")
        }
    }

    @Test func allRoutesHaveIds() {
        for route in AppRoute.allCases {
            #expect(!route.id.isEmpty, "Route \(route.rawValue) has empty id")
            #expect(route.id == route.rawValue)
        }
    }

    @Test func sidebarVisibleRoutesCount() {
        let visible = AppRoute.allCases.filter(\.sidebarVisible)
        #expect(visible.count == 24)
    }

    @Test func strategyDetailIsNotSidebarVisible() {
        #expect(AppRoute.strategyDetail.sidebarVisible == false)
    }

    @Test func totalRouteCount() {
        #expect(AppRoute.allCases.count == 25)
    }

    @Test func overviewSectionRoutes() {
        let overviewRoutes = AppRoute.allCases.filter { $0.section == .overview }
        #expect(overviewRoutes.count == 2)
        #expect(overviewRoutes.contains(.dashboard))
        #expect(overviewRoutes.contains(.liveReadiness))
    }

    @Test func strategySectionRoutes() {
        let strategyRoutes = AppRoute.allCases.filter { $0.section == .strategy }
        #expect(strategyRoutes.count == 4)
        #expect(strategyRoutes.contains(.strategyWorkspace))
        #expect(strategyRoutes.contains(.strategyCanvas))
        #expect(strategyRoutes.contains(.backtestSimulation))
        #expect(strategyRoutes.contains(.strategyDetail))
    }

    @Test func structureSectionRoutes() {
        let structureRoutes = AppRoute.allCases.filter { $0.section == .structure }
        #expect(structureRoutes.count == 3)
        #expect(structureRoutes.contains(.marketStructure))
        #expect(structureRoutes.contains(.structureMatrix))
        #expect(structureRoutes.contains(.manipulationRadar))
    }

    @Test func executionSectionRoutes() {
        let executionRoutes = AppRoute.allCases.filter { $0.section == .execution }
        #expect(executionRoutes.count == 3)
        #expect(executionRoutes.contains(.executionCenter))
        #expect(executionRoutes.contains(.ordersPositions))
        #expect(executionRoutes.contains(.reconciliationBus))
    }

    @Test func riskSectionRoutes() {
        let riskRoutes = AppRoute.allCases.filter { $0.section == .risk }
        #expect(riskRoutes.count == 3)
        #expect(riskRoutes.contains(.riskCenter))
        #expect(riskRoutes.contains(.stopProtection))
        #expect(riskRoutes.contains(.circuitBreakers))
    }

    @Test func aiResearchSectionRoutes() {
        let aiRoutes = AppRoute.allCases.filter { $0.section == .aiResearch }
        #expect(aiRoutes.count == 4)
        #expect(aiRoutes.contains(.aiResearchRoom))
        #expect(aiRoutes.contains(.agentPlatform))
        #expect(aiRoutes.contains(.signalCenter))
        #expect(aiRoutes.contains(.marketSentiment))
    }

    @Test func growthSectionRoutes() {
        let growthRoutes = AppRoute.allCases.filter { $0.section == .growth }
        #expect(growthRoutes.count == 3)
        #expect(growthRoutes.contains(.growthReview))
        #expect(growthRoutes.contains(.failureClustering))
        #expect(growthRoutes.contains(.strategyOptimization))
    }

    @Test func systemSectionRoutes() {
        let systemRoutes = AppRoute.allCases.filter { $0.section == .system }
        #expect(systemRoutes.count == 3)
        #expect(systemRoutes.contains(.serviceManagement))
        #expect(systemRoutes.contains(.dataSourceManagement))
        #expect(systemRoutes.contains(.systemSettings))
    }

    @Test func uniqueLabels() {
        let labels = AppRoute.allCases.map(\.label)
        let uniqueLabels = Set(labels)
        #expect(labels.count == uniqueLabels.count, "All routes should have unique labels")
    }

    @Test func uniqueRawValues() {
        let rawValues = AppRoute.allCases.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count, "All routes should have unique rawValues")
    }
}
