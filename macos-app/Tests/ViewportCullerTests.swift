import Testing
import Foundation
@testable import AlphaLoop

struct ViewportCullerTests {

    @Test func visibleNodes_onlyReturnsViewportOverlappingNodes() {
        let nodes = [
            CanvasNode(id: UUID(), nodeType: "data.kline", position: CGPoint(x: 100, y: 100), size: CGSize(width: 200, height: 120)),
            CanvasNode(id: UUID(), nodeType: "indicator.rsi", position: CGPoint(x: 2000, y: 2000), size: CGSize(width: 200, height: 120)),
            CanvasNode(id: UUID(), nodeType: "output.buy", position: CGPoint(x: 500, y: 300), size: CGSize(width: 200, height: 120)),
        ]
        let viewport = ViewportState(scale: 1.0, offset: .zero)
        let canvasSize = CGSize(width: 800, height: 600)
        let culler = ViewportCuller()

        let visible = culler.visibleNodes(nodes, selectedIds: [], viewport: viewport, canvasSize: canvasSize)

        #expect(visible.count == 2)
        #expect(visible.contains(where: { $0.nodeType == "data.kline" }))
        #expect(visible.contains(where: { $0.nodeType == "output.buy" }))
        #expect(!visible.contains(where: { $0.nodeType == "indicator.rsi" }))
    }

    @Test func visibleNodes_alwaysIncludesSelectedNodes() {
        let farNode = CanvasNode(id: UUID(), nodeType: "indicator.rsi", position: CGPoint(x: 5000, y: 5000), size: CGSize(width: 200, height: 120))
        let nodes = [farNode]
        let viewport = ViewportState(scale: 1.0, offset: .zero)
        let canvasSize = CGSize(width: 800, height: 600)
        let culler = ViewportCuller()

        let visible = culler.visibleNodes(nodes, selectedIds: [farNode.id], viewport: viewport, canvasSize: canvasSize)

        #expect(visible.count == 1)
    }

    @Test func visibleNodes_respectsPaddingBuffer() {
        let edgeNode = CanvasNode(id: UUID(), nodeType: "data.kline", position: CGPoint(x: 750, y: 100), size: CGSize(width: 200, height: 120))
        let nodes = [edgeNode]
        let viewport = ViewportState(scale: 1.0, offset: .zero)
        let canvasSize = CGSize(width: 800, height: 600)
        let culler = ViewportCuller()

        let visible = culler.visibleNodes(nodes, selectedIds: [], viewport: viewport, canvasSize: canvasSize)

        // Node at x=750 width=200 extends to x=950; viewport width=800 + 200px buffer -> should be visible
        #expect(visible.count == 1)
    }
}
