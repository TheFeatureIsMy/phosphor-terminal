import Testing
import Foundation
@testable import PulseDesk

struct EdgeValidatorTests {

    @Test func isTypeCompatible_indicatorToSignal_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .indicator, target: .signal))
    }

    @Test func isTypeCompatible_klineToIndicator_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .kline, target: .indicator))
    }

    @Test func isTypeCompatible_booleanToSignal_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .boolean, target: .signal))
    }

    @Test func isTypeCompatible_signalToTicker_isIncompatible() {
        let validator = EdgeValidator()
        #expect(!validator.isTypeCompatible(source: .signal, target: .ticker))
    }

    @Test func isTypeCompatible_llmOutputToText_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .llmOutput, target: .text))
    }

    @Test func isTypeCompatible_sameType_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .number, target: .number))
    }

    @Test func wouldCreateCycle_withValidEdge_returnsFalse() {
        let n1 = UUID(); let n2 = UUID(); let n3 = UUID()
        let edges = [
            CanvasEdge(id: UUID(), sourceNodeId: n1, sourcePort: "out", targetNodeId: n2, targetPort: "in1", dataType: .indicator),
            CanvasEdge(id: UUID(), sourceNodeId: n2, sourcePort: "out", targetNodeId: n3, targetPort: "in1", dataType: .signal),
        ]
        let validator = EdgeValidator()
        // Adding edge from n1 straight to n3 — already reachable but no back-edge, so no cycle
        #expect(!validator.wouldCreateCycle(source: n1, target: n3, edges: edges))
    }

    @Test func wouldCreateCycle_withBackEdge_returnsTrue() {
        let n1 = UUID(); let n2 = UUID(); let n3 = UUID()
        let edges = [
            CanvasEdge(id: UUID(), sourceNodeId: n1, sourcePort: "out", targetNodeId: n2, targetPort: "in1", dataType: .indicator),
            CanvasEdge(id: UUID(), sourceNodeId: n2, sourcePort: "out", targetNodeId: n3, targetPort: "in1", dataType: .signal),
        ]
        let validator = EdgeValidator()
        // Adding edge from n3 back to n1 creates cycle: n3 → n1 → n2 → n3
        #expect(validator.wouldCreateCycle(source: n3, target: n1, edges: edges))
    }
}
