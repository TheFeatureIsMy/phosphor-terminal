import Testing
import Foundation
@testable import PulseDesk

struct EdgeRouterTests {

    @Test func portPosition_inputPort_onLeftEdge() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portKey: "kline", isInput: true)

        #expect(pos != nil)
        #expect(pos!.x == 100)
        #expect(pos!.y == 136)  // 100 + 30 (title) + 0 * 18 + 6
    }

    @Test func portPosition_outputPort_onRightEdge() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portKey: "rsiValue", isInput: false)

        #expect(pos != nil)
        #expect(pos!.x == 300)  // 100 + 200
        #expect(pos!.y == 166)  // 100 + 30 + 1*18 + 12 + 0*18 + 6
    }

    @Test func portPosition_returnsNilForUnknownPort() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portKey: "nonexistent", isInput: true)

        #expect(pos == nil)
    }
}
