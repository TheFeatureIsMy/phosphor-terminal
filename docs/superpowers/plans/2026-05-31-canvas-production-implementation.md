# Canvas Production Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate the StrategyCanvasTab from functional prototype to production-ready visual strategy editor handling 200+ nodes at 60fps.

**Architecture:** Four-layer Z-stack rendering (background → edges → viewport-culled nodes → interaction overlays). New services for edge routing, validation, clipboard, snap-to-grid, and error notification. Palette and config panel fully rewritten. CodeGenerator expanded from 20 to 55 node types via dictionary-driven template registry.

**Tech Stack:** Swift 5.9, SwiftUI (Canvas 2D + native Views), macOS 26, ProofAlpha DesignSystem, no external dependencies

---

## File Structure

```
Create:
  macos-app/PulseDesk/Views/Canvas/ViewportCuller.swift       — Visible node filter
  macos-app/PulseDesk/Views/Canvas/SnapGuidesView.swift       — Alignment guide overlay
  macos-app/PulseDesk/Views/Canvas/NodeBadges.swift           — Status badge component
  macos-app/PulseDesk/Views/Canvas/CanvasSearchOverlay.swift  — ⌘F search overlay
  macos-app/PulseDesk/Views/Canvas/ConnectionPreview.swift    — Port snap preview
  macos-app/PulseDesk/Services/EdgeRouter.swift               — Port → screen coord calculator
  macos-app/PulseDesk/Services/EdgeValidator.swift            — Type matrix + cycle detection
  macos-app/PulseDesk/Services/ClipboardManager.swift         — NSPasteboard copy/paste
  macos-app/PulseDesk/Services/SnapEngine.swift               — Snap-to-grid math
  macos-app/PulseDesk/Services/CanvasErrorNotifier.swift      — Toast notification service

Modify:
  macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift   — Integration hub
  macos-app/PulseDesk/Views/Canvas/CanvasEdges.swift             — Port precision + particles
  macos-app/PulseDesk/Views/Canvas/NodeView.swift                — Badges + port hover
  macos-app/PulseDesk/Views/Canvas/NodePalette.swift             — Full rewrite
  macos-app/PulseDesk/Views/Canvas/NodeConfigPanel.swift         — Full rewrite
  macos-app/PulseDesk/Views/Canvas/MiniMapView.swift             — Resize + animation
  macos-app/PulseDesk/ViewModels/CanvasViewModel.swift           — Undo coalesce + clipboard
  macos-app/PulseDesk/Models/CanvasModels.swift                  — CachedPortPosition, SaveStatus
  macos-app/PulseDesk/Services/CodeGenerator.swift               — Template registry
  macos-app/Package.swift                                        — Add test target
```

---

## Phase 1: Core Performance + Edge Fixes

### Task 1: Add test target to Package.swift

**Files:**
- Modify: `macos-app/Package.swift`

- [ ] **Step 1: Add test target to Package.swift**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseDesk",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "PulseDesk",
            path: "PulseDesk",
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
        .testTarget(
            name: "PulseDeskTests",
            dependencies: ["PulseDesk"],
            path: "Tests"
        ),
    ]
)
```

- [ ] **Step 2: Create Tests directory structure**

Run: `mkdir -p /Users/novspace/workspace/phosphor-terminal/macos-app/Tests`

- [ ] **Step 3: Verify test target builds**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build --build-tests 2>&1 | tail -3`
Expected: Build succeeds (no test files yet, but target exists)

- [ ] **Step 4: Commit**

```bash
git add macos-app/Package.swift macos-app/Tests/
git commit -m "build: add PulseDeskTests target for canvas unit tests"
```

---

### Task 2: Define new model types in CanvasModels.swift

**Files:**
- Modify: `macos-app/PulseDesk/Models/CanvasModels.swift` (append at end)

- [ ] **Step 1: Add CachedPortPosition and SaveStatus types**

Open CanvasModels.swift, append after the last closing brace of the existing types:

```swift
// MARK: - Cached port position (for edge rendering)
struct CachedPortPosition {
    let nodeId: UUID
    let portName: String
    let worldPosition: CGPoint
}

// MARK: - Save status for auto-save feedback
enum SaveStatus {
    case saved
    case saving
    case error(String)
    case dirty
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Models/CanvasModels.swift
git commit -m "feat(canvas): add CachedPortPosition and SaveStatus model types"
```

---

### Task 3: Implement ViewportCuller with tests

**Files:**
- Create: `macos-app/PulseDesk/Views/Canvas/ViewportCuller.swift`
- Create: `macos-app/Tests/ViewportCullerTests.swift`

- [ ] **Step 1: Write failing test**

Create `macos-app/Tests/ViewportCullerTests.swift`:

```swift
import Testing
import Foundation
@testable import PulseDesk

struct ViewportCullerTests {

    @Test func visibleNodes_onlyReturnsViewportOverlappingNodes() {
        // Arrange: 3 nodes, only 1 in viewport
        let nodes = [
            CanvasNode(id: UUID(), nodeType: "data.kline", position: CGPoint(x: 100, y: 100), size: CGSize(width: 200, height: 120)),
            CanvasNode(id: UUID(), nodeType: "indicator.rsi", position: CGPoint(x: 2000, y: 2000), size: CGSize(width: 200, height: 120)),
            CanvasNode(id: UUID(), nodeType: "output.buy", position: CGPoint(x: 500, y: 300), size: CGSize(width: 200, height: 120)),
        ]
        let viewport = ViewportState(scale: 1.0, offset: .zero)
        let canvasSize = CGSize(width: 800, height: 600)
        let culler = ViewportCuller()

        // Act
        let visible = culler.visibleNodes(nodes, selectedIds: [], viewport: viewport, canvasSize: canvasSize)

        // Assert: only node 0 and node 2 are in (or near) viewport; node 1 is far away
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
        // Node is just outside viewport but within 200px padding
        let edgeNode = CanvasNode(id: UUID(), nodeType: "data.kline", position: CGPoint(x: 750, y: 100), size: CGSize(width: 200, height: 120))
        let nodes = [edgeNode]
        let viewport = ViewportState(scale: 1.0, offset: .zero)
        let canvasSize = CGSize(width: 800, height: 600)
        let culler = ViewportCuller()

        let visible = culler.visibleNodes(nodes, selectedIds: [], viewport: viewport, canvasSize: canvasSize)

        // Node at x=750 width=200 extends to x=950; viewport width=800 + 200px buffer → should be visible
        #expect(visible.count == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter ViewportCullerTests 2>&1 | tail -10`
Expected: Build failure (ViewportCuller not found)

- [ ] **Step 3: Implement ViewportCuller**

Create `macos-app/PulseDesk/Views/Canvas/ViewportCuller.swift`:

```swift
import Foundation

struct ViewportCuller {
    let padding: CGFloat = 200

    func visibleNodes(
        _ nodes: [CanvasNode],
        selectedIds: Set<UUID>,
        viewport: ViewportState,
        canvasSize: CGSize
    ) -> [CanvasNode] {
        let visibleRect = worldVisibleRect(viewport: viewport, canvasSize: canvasSize)
            .insetBy(dx: -padding, dy: -padding)

        var result = nodes.filter { node in
            let nodeRect = CGRect(
                x: node.position.x,
                y: node.position.y,
                width: node.size.width,
                height: node.size.height
            )
            return visibleRect.intersects(nodeRect)
        }

        // Always include selected nodes even if outside visible rect
        for node in nodes {
            if selectedIds.contains(node.id) && !result.contains(where: { $0.id == node.id }) {
                result.append(node)
            }
        }

        return result
    }

    private func worldVisibleRect(viewport: ViewportState, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: -viewport.offset.x / viewport.scale,
            y: -viewport.offset.y / viewport.scale,
            width: canvasSize.width / viewport.scale,
            height: canvasSize.height / viewport.scale
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter ViewportCullerTests 2>&1 | tail -10`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/ViewportCuller.swift macos-app/Tests/ViewportCullerTests.swift
git commit -m "feat(canvas): add ViewportCuller with viewport-aware node filtering"
```

---

### Task 4: Implement EdgeRouter with tests — port-to-world-coordinate calculation

**Files:**
- Create: `macos-app/PulseDesk/Services/EdgeRouter.swift`
- Create: `macos-app/Tests/EdgeRouterTests.swift`

- [ ] **Step 1: Write failing test**

Create `macos-app/Tests/EdgeRouterTests.swift`:

```swift
import Testing
import Foundation
@testable import PulseDesk

struct EdgeRouterTests {

    @Test func portPosition_inputPort_onLeftEdge() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        // RSI has 1 input port "data" and 1 output port "signal"
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portName: "data", isInput: true)

        // x should be at left edge
        #expect(pos.x == 100)
        // y = 100 + 30 (title) + 0 * 18 + 6 = 136
        #expect(pos.y == 136)
    }

    @Test func portPosition_outputPort_onRightEdge() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portName: "signal", isInput: false)

        // x should be at right edge
        #expect(pos.x == 300)
        // y = 100 + 30 + 1 * 18 + 12 + 0 * 18 + 6 = 166
        #expect(pos.y == 166)
    }

    @Test func portPosition_returnsNilForUnknownPort() {
        let node = CanvasNode(id: UUID(), nodeType: "indicator.rsi",
                              position: CGPoint(x: 100, y: 100),
                              size: CGSize(width: 200, height: 120))
        let def = NodeRegistry.definition(for: "indicator.rsi")!
        let router = EdgeRouter()

        let pos = router.portPosition(node: node, definition: def, portName: "nonexistent", isInput: true)

        #expect(pos == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter EdgeRouterTests 2>&1 | tail -10`
Expected: Build failure (EdgeRouter not found)

- [ ] **Step 3: Implement EdgeRouter**

Create `macos-app/PulseDesk/Services/EdgeRouter.swift`:

```swift
import Foundation

struct EdgeRouter {
    private let titleBarHeight: CGFloat = 30
    private let portSpacing: CGFloat = 18
    private let portGap: CGFloat = 12
    private let halfPortSize: CGFloat = 6

    func portPosition(
        node: CanvasNode,
        definition: NodeDefinition,
        portName: String,
        isInput: Bool
    ) -> CGPoint? {
        if isInput {
            guard let index = definition.inputPorts.firstIndex(where: { $0.name == portName }) else {
                return nil
            }
            return CGPoint(
                x: node.position.x,
                y: node.position.y + titleBarHeight + CGFloat(index) * portSpacing + halfPortSize
            )
        } else {
            guard let index = definition.outputPorts.firstIndex(where: { $0.name == portName }) else {
                return nil
            }
            let inputCount = CGFloat(definition.inputPorts.count)
            return CGPoint(
                x: node.position.x + node.size.width,
                y: node.position.y + titleBarHeight + inputCount * portSpacing + portGap + CGFloat(index) * portSpacing + halfPortSize
            )
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter EdgeRouterTests 2>&1 | tail -10`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Services/EdgeRouter.swift macos-app/Tests/EdgeRouterTests.swift
git commit -m "feat(canvas): add EdgeRouter for precise port-to-coordinate positioning"
```

---

### Task 5: Implement EdgeValidator with tests — type compatibility + cycle detection

**Files:**
- Create: `macos-app/PulseDesk/Services/EdgeValidator.swift`
- Create: `macos-app/Tests/EdgeValidatorTests.swift`

- [ ] **Step 1: Write failing test**

Create `macos-app/Tests/EdgeValidatorTests.swift`:

```swift
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

    @Test func isTypeCompatible_booleanToOutput_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .boolean, target: .signal))
    }

    @Test func isTypeCompatible_signalToTicker_isIncompatible() {
        let validator = EdgeValidator()
        #expect(!validator.isTypeCompatible(source: .signal, target: .kline))
    }

    @Test func isTypeCompatible_llmOutputToText_isCompatible() {
        let validator = EdgeValidator()
        #expect(validator.isTypeCompatible(source: .llmOutput, target: .text))
    }

    @Test func wouldCreateCycle_withValidEdge_returnsFalse() {
        let n1 = UUID(); let n2 = UUID(); let n3 = UUID()
        let edges = [
            CanvasEdge(id: UUID(), sourceNodeId: n1, sourcePort: "out", targetNodeId: n2, targetPort: "in1", dataType: .indicator),
            CanvasEdge(id: UUID(), sourceNodeId: n2, sourcePort: "out", targetNodeId: n3, targetPort: "in1", dataType: .signal),
        ]
        let validator = EdgeValidator()
        #expect(!validator.wouldCreateCycle(source: n3, target: n1, edges: edges))
    }

    @Test func wouldCreateCycle_withBackEdge_returnsTrue() {
        let n1 = UUID(); let n2 = UUID(); let n3 = UUID()
        let edges = [
            CanvasEdge(id: UUID(), sourceNodeId: n1, sourcePort: "out", targetNodeId: n2, targetPort: "in1", dataType: .indicator),
            CanvasEdge(id: UUID(), sourceNodeId: n2, sourcePort: "out", targetNodeId: n3, targetPort: "in1", dataType: .signal),
        ]
        let validator = EdgeValidator()
        #expect(validator.wouldCreateCycle(source: n3, target: n1, edges: edges))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter EdgeValidatorTests 2>&1 | tail -10`
Expected: Build failure

- [ ] **Step 3: Implement EdgeValidator**

Create `macos-app/PulseDesk/Services/EdgeValidator.swift`:

```swift
import Foundation

struct EdgeValidator {
    // Downward-compatible type chain: kline → indicator → signal → boolean → output
    private let compatiblePairs: Set<String> = [
        "kline→indicator", "orderbook→indicator", "ticker→indicator",
        "indicator→signal", "indicator→indicator",
        "signal→boolean", "signal→signal",
        "boolean→boolean", "boolean→output",
        "text→text", "text→number", "text→boolean", "text→array", "text→object",
        "number→text", "number→number", "number→boolean",
        "array→array", "array→object",
        "object→object",
        "llmOutput→text",
        "sentiment→signal",
        "riskMetric→number",
        "onchain→indicator", "fundingRate→indicator", "liquidation→indicator",
        "macro→signal", "macro→indicator",
        "position→signal", "position→number",
    ]

    func isTypeCompatible(source: PortDataType, target: PortDataType) -> Bool {
        if source == target { return true }
        return compatiblePairs.contains("\(source.rawValue)→\(target.rawValue)")
    }

    func wouldCreateCycle(source: UUID, target: UUID, edges: [CanvasEdge]) -> Bool {
        var adj: [UUID: [UUID]] = [:]
        for edge in edges {
            adj[edge.sourceNodeId, default: []].append(edge.targetNodeId)
        }
        // Add the proposed edge
        adj[source, default: []].append(target)

        // DFS from source — if we reach source again, cycle exists
        var visited = Set<UUID>()
        var stack: [UUID] = [source]
        while let current = stack.popLast() {
            if current == source && !visited.isEmpty { return true }
            if !visited.insert(current).inserted { continue }
            for neighbor in adj[current] ?? [] {
                stack.append(neighbor)
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test --filter EdgeValidatorTests 2>&1 | tail -10`
Expected: All 7 tests pass

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Services/EdgeValidator.swift macos-app/Tests/EdgeValidatorTests.swift
git commit -m "feat(canvas): add EdgeValidator with type compatibility matrix and cycle detection"
```

---

### Task 6: Rewrite CanvasEdges — port-precise endpoints + data-flow particles

**Files:**
- Modify: `macos-app/PulseDesk/Views/Canvas/CanvasEdges.swift`

- [ ] **Step 1: Rewrite CanvasEdges with port precision and particle animation**

Replace the entire contents of `CanvasEdges.swift`:

```swift
import SwiftUI

struct CanvasEdges: View {
    @Environment(PulseColors.self) private var colors
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    let selectedEdgeIds: Set<UUID>
    let scale: CGFloat
    let offset: CGPoint

    private let router = EdgeRouter()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
                let now = timeline.date.timeIntervalSinceReferenceDate

                for edge in edges {
                    guard let sourceNode = nodeMap[edge.sourceNodeId],
                          let targetNode = nodeMap[edge.targetNodeId],
                          let sourceDef = NodeRegistry.definition(for: sourceNode.nodeType),
                          let targetDef = NodeRegistry.definition(for: targetNode.nodeType),
                          let from = router.portPosition(node: sourceNode, definition: sourceDef, portName: edge.sourcePort, isInput: false),
                          let to = router.portPosition(node: targetNode, definition: targetDef, portName: edge.targetPort, isInput: true)
                    else { continue }

                    // Viewport transform
                    let screenFrom = CGPoint(x: from.x * scale + offset.x, y: from.y * scale + offset.y)
                    let screenTo = CGPoint(x: to.x * scale + offset.x, y: to.y * scale + offset.y)

                    let isSelected = selectedEdgeIds.contains(edge.id)
                    let lineWidth: CGFloat = isSelected ? 3 : 2
                    let color = edge.dataType.color(colors)
                    let opacity: CGFloat = sourceNode.isDisabled ? 0.3 : 0.7

                    drawBezierWire(context: context, from: screenFrom, to: screenTo,
                                   color: color.opacity(opacity), lineWidth: lineWidth)

                    if isSelected {
                        drawBezierWire(context: context, from: screenFrom, to: screenTo,
                                       color: color.opacity(0.3), lineWidth: 6)
                    }

                    // Data-flow particles (only when zoomed in enough)
                    if scale > 0.3 {
                        drawParticles(context: context, from: screenFrom, to: screenTo,
                                      color: color, now: now, edgeId: edge.id)
                    }
                }
            }
        }
    }

    private func drawBezierWire(context: GraphicsContext, from: CGPoint, to: CGPoint,
                                 color: Color, lineWidth: CGFloat) {
        let dx = abs(to.x - from.x) * 0.5
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to,
                      control1: CGPoint(x: from.x + max(dx, 40), y: from.y),
                      control2: CGPoint(x: to.x - max(dx, 40), y: to.y))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawParticles(context: GraphicsContext, from: CGPoint, to: CGPoint,
                                color: Color, now: TimeInterval, edgeId: UUID) {
        let distance = hypot(to.x - from.x, to.y - from.y)
        let spacing: CGFloat = 80
        let count = max(1, Int(distance / spacing))
        let seed = edgeId.hashValue
        let speed: CGFloat = 0.3

        for i in 0..<count {
            let baseT = CGFloat(i) / CGFloat(count)
            let particleT = (baseT + CGFloat(now) * speed).truncatingRemainder(dividingBy: 1.0)
            let dx = abs(to.x - from.x) * 0.5
            let cp1 = CGPoint(x: from.x + max(dx, 40), y: from.y)
            let cp2 = CGPoint(x: to.x - max(dx, 40), y: to.y)

            let p1 = cubicBezierPoint(t: particleT, p0: from, p1: cp1, p2: cp2, p3: to)
            let dotSize: CGFloat = 3
            let dotRect = CGRect(x: p1.x - dotSize/2, y: p1.y - dotSize/2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.6)))
        }
    }

    private func cubicBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/CanvasEdges.swift
git commit -m "feat(canvas): rewrite CanvasEdges with port-precise endpoints and data-flow particles"
```

---

### Task 7: Wire ViewportCuller into StrategyCanvasTab

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift`

- [ ] **Step 1: Add GeometryReader and viewport culling to the node layer**

In `StrategyCanvasTab.swift`, find the `ForEach(viewModel.graph.nodes)` block inside the ZStack (around line 40). Replace the content section with:

```swift
// Replace the if/else emptyState check + ForEach block with:
GeometryReader { geo in
    let culler = ViewportCuller()
    let visible = culler.visibleNodes(
        viewModel.graph.nodes,
        selectedIds: viewModel.selectedNodeIds,
        viewport: viewModel.viewport,
        canvasSize: geo.size
    )

    if viewModel.graph.nodes.isEmpty {
        emptyState
    } else {
        ForEach(visible) { node in
            NodeDragWrapper(viewModel: viewModel, node: node,
                onWireStart: { nid, port in startWire(nid, port) },
                onWireEnd: { tid, port in endWire(tid, port) }
            )
        }
    }
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

- [ ] **Step 2: Verify build and test visually**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift
git commit -m "feat(canvas): wire ViewportCuller into StrategyCanvasTab for large-scale performance"
```

---

### Task 8: Wire EdgeValidator into StrategyCanvasTab for real-time validation during wire drag

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift`

- [ ] **Step 1: Add validation to wire drag connection flow**

In `StrategyCanvasTab.swift`, add an `edgeValidator` property and modify the `nearestPort` method to filter by type compatibility:

```swift
// Add property at top of struct:
private let edgeValidator = EdgeValidator()

// Replace nearestPort function with:
private func nearestPort(to point: CGPoint, sourceType: PortDataType? = nil) -> (nid: UUID, port: String)? {
    for node in viewModel.graph.nodes {
        guard let def = NodeRegistry.definition(for: node.nodeType) else { continue }
        for (i, port) in def.inputPorts.enumerated() {
            if let srcType = sourceType, !edgeValidator.isTypeCompatible(source: srcType, target: port.dataType) {
                continue // silently skip incompatible ports
            }
            let pp = CGPoint(x: node.position.x + 16, y: node.position.y + 30 + CGFloat(i) * 18 + 9)
            if hypot(point.x - pp.x, point.y - pp.y) < 30 { return (node.id, port.name) }
        }
    }
    return nil
}
```

Then update the `wireDragGesture`'s `.onEnded` to pass the source type for filtering:

```swift
// In wireDragGesture, change the .onEnded closure:
.onEnded { v in
    let wp = worldPos(v.location)
    let srcType = viewModel.wireDragSource.flatMap { src in
        NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
            .outputPorts.first(where: { $0.name == src.port })?.dataType
    }
    if let t = nearestPort(to: wp, sourceType: srcType) {
        endWire(t.nid, t.port)
    } else { viewModel.endWireDrag() }
}
```

Also update `endWire` to validate for cycles before adding:

```swift
private func endWire(_ tid: UUID, _ port: String) {
    guard let src = viewModel.wireDragSource else { return }
    // Check for cycle
    if edgeValidator.wouldCreateCycle(source: src.nodeId, target: tid, edges: viewModel.graph.edges) {
        // Brief error feedback — could add a toast/shake here later
        viewModel.endWireDrag()
        return
    }
    let dt = NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
        .outputPorts.first(where: { $0.name == src.port })?.dataType ?? .signal
    viewModel.addEdge(CanvasEdge(sourceNodeId: src.nodeId, sourcePort: src.port,
                                 targetNodeId: tid, targetPort: port, dataType: dt))
    viewModel.endWireDrag()
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift
git commit -m "feat(canvas): add real-time type validation and cycle detection during wire drag"
```

---

## Phase 2: Interaction Efficiency

### Task 9: Implement ClipboardManager

**Files:**
- Create: `macos-app/PulseDesk/Services/ClipboardManager.swift`

- [ ] **Step 1: Implement ClipboardManager**

Create `macos-app/PulseDesk/Services/ClipboardManager.swift`:

```swift
import AppKit
import Foundation

struct ClipboardManager {
    private let pasteboard = NSPasteboard.general
    private let serializer = GraphSerializer()

    func copy(nodes: [CanvasNode], edges: [CanvasEdge], from graph: WorkflowGraph) {
        // Filter edges whose both endpoints are in the copied nodes
        let nodeIds = Set(nodes.map(\.id))
        let subEdges = edges.filter { nodeIds.contains($0.sourceNodeId) && nodeIds.contains($0.targetNodeId) }
        let subGraph = WorkflowGraph(nodes: nodes, edges: subEdges, groups: [], viewport: ViewportState())
        guard let data = try? serializer.serialize(subGraph),
              let json = String(data: data, encoding: .utf8) else { return }
        pasteboard.clearContents()
        pasteboard.setString(json, forType: .string)
    }

    func paste(offset: CGPoint = CGPoint(x: 50, y: 50)) -> (nodes: [CanvasNode], edges: [CanvasEdge])? {
        guard let json = pasteboard.string(forType: .string),
              let data = json.data(using: .utf8),
              let subGraph = try? serializer.deserialize(data) else { return nil }

        // Re-key UUIDs
        var idMap: [UUID: UUID] = [:]
        let newNodes = subGraph.nodes.map { node -> CanvasNode in
            let newId = UUID()
            idMap[node.id] = newId
            return CanvasNode(id: newId, nodeType: node.nodeType,
                              position: CGPoint(x: node.position.x + offset.x, y: node.position.y + offset.y),
                              size: node.size, config: node.config, widgetValues: node.widgetValues,
                              isCollapsed: node.isCollapsed, isDisabled: node.isDisabled)
        }
        let newEdges = subGraph.edges.map { edge -> CanvasEdge in
            CanvasEdge(id: UUID(),
                       sourceNodeId: idMap[edge.sourceNodeId] ?? edge.sourceNodeId,
                       sourcePort: edge.sourcePort,
                       targetNodeId: idMap[edge.targetNodeId] ?? edge.targetNodeId,
                       targetPort: edge.targetPort,
                       dataType: edge.dataType)
        }
        return (newNodes, newEdges)
    }
}
```

- [ ] **Step 2: Add copy/paste/duplicate methods to CanvasViewModel**

In `CanvasViewModel.swift`, add:

```swift
// Add property at top:
private let clipboard = ClipboardManager()

// Add methods:
func copySelected() {
    let selNodes = graph.nodes.filter { selectedNodeIds.contains($0.id) }
    guard !selNodes.isEmpty else { return }
    clipboard.copy(nodes: selNodes, edges: graph.edges, from: graph)
}

func paste() {
    guard let (newNodes, newEdges) = clipboard.paste() else { return }
    for node in newNodes { graph.nodes.append(node); record(.addNode(node)) }
    for edge in newEdges { graph.edges.append(edge); record(.addEdge(edge)) }
    selectedNodeIds = Set(newNodes.map(\.id))
    scheduleSave()
}

func duplicateSelected() {
    copySelected()
    paste()
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/ClipboardManager.swift macos-app/PulseDesk/ViewModels/CanvasViewModel.swift
git commit -m "feat(canvas): add ClipboardManager for copy/paste/duplicate of nodes and edges"
```

---

### Task 10: Implement SnapEngine

**Files:**
- Create: `macos-app/PulseDesk/Services/SnapEngine.swift`

- [ ] **Step 1: Implement SnapEngine**

Create `macos-app/PulseDesk/Services/SnapEngine.swift`:

```swift
import Foundation

struct SnapResult {
    let snappedPosition: CGPoint
    let guides: [SnapGuide]
}

struct SnapGuide {
    let position: CGFloat       // world coordinate of the guide line
    let orientation: Orientation
    enum Orientation { case horizontal, vertical }
}

struct SnapEngine {
    let threshold: CGFloat = 8
    let gridSize: CGFloat = 20

    func snap(
        position: CGPoint,
        size: CGSize,
        otherNodes: [CanvasNode],
        excludeId: UUID? = nil,
        useGrid: Bool = false
    ) -> SnapResult {
        var pos = position
        var guides: [SnapGuide] = []

        // Center snap
        let cx = pos.x + size.width / 2
        let cy = pos.y + size.height / 2

        // Left edge
        let left = pos.x
        let right = pos.x + size.width
        let top = pos.y
        let bottom = pos.y + size.height

        for other in otherNodes {
            if let excludeId, other.id == excludeId { continue }

            checkSnap(value: left, against: other.position.x, threshold: threshold) { snapped in
                pos.x = snapped; guides.append(SnapGuide(position: other.position.x, orientation: .vertical))
            }
            checkSnap(value: right, against: other.position.x + other.size.width, threshold: threshold) { snapped in
                pos.x = snapped - size.width; guides.append(SnapGuide(position: other.position.x + other.size.width, orientation: .vertical))
            }
            checkSnap(value: top, against: other.position.y, threshold: threshold) { snapped in
                pos.y = snapped; guides.append(SnapGuide(position: other.position.y, orientation: .horizontal))
            }
            checkSnap(value: bottom, against: other.position.y + other.size.height, threshold: threshold) { snapped in
                pos.y = snapped - size.height; guides.append(SnapGuide(position: other.position.y + other.size.height, orientation: .horizontal))
            }
            checkSnap(value: cx, against: other.position.x + other.size.width / 2, threshold: threshold) { snapped in
                pos.x = snapped - size.width / 2; guides.append(SnapGuide(position: other.position.x + other.size.width / 2, orientation: .vertical))
            }
            checkSnap(value: cy, against: other.position.y + other.size.height / 2, threshold: threshold) { snapped in
                pos.y = snapped - size.height / 2; guides.append(SnapGuide(position: other.position.y + other.size.height / 2, orientation: .horizontal))
            }
        }

        // Grid snap if enabled
        if useGrid {
            let gridX = round(pos.x / gridSize) * gridSize
            let gridY = round(pos.y / gridSize) * gridSize
            if abs(pos.x - gridX) < threshold { pos.x = gridX }
            if abs(pos.y - gridY) < threshold { pos.y = gridY }
        }

        return SnapResult(snappedPosition: pos, guides: guides)
    }

    private func checkSnap(value: CGFloat, against target: CGFloat, threshold: CGFloat, onSnap: (CGFloat) -> Void) {
        if abs(value - target) < threshold {
            onSnap(target)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Services/SnapEngine.swift
git commit -m "feat(canvas): add SnapEngine for edge/center alignment and grid snapping"
```

---

### Task 11: Implement SnapGuidesView and NodeBadges

**Files:**
- Create: `macos-app/PulseDesk/Views/Canvas/SnapGuidesView.swift`
- Create: `macos-app/PulseDesk/Views/Canvas/NodeBadges.swift`

- [ ] **Step 1: Create SnapGuidesView**

Create `macos-app/PulseDesk/Views/Canvas/SnapGuidesView.swift`:

```swift
import SwiftUI

struct SnapGuidesView: View {
    @Environment(PulseColors.self) private var colors
    let guides: [SnapGuide]
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            for guide in guides {
                let screenPos = guide.position * scale + (guide.orientation == .horizontal ? offset.y : offset.x)
                var path = Path()

                switch guide.orientation {
                case .horizontal:
                    path.move(to: CGPoint(x: 0, y: screenPos))
                    path.addLine(to: CGPoint(x: size.width, y: screenPos))
                case .vertical:
                    path.move(to: CGPoint(x: screenPos, y: 0))
                    path.addLine(to: CGPoint(x: screenPos, y: size.height))
                }

                context.stroke(path, with: .color(PulseColors.accent.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2: Create NodeBadges**

Create `macos-app/PulseDesk/Views/Canvas/NodeBadges.swift`:

```swift
import SwiftUI

struct NodeBadge: View {
    enum Kind { case warning, error, connected }

    let kind: Kind

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundStyle(color)
            .frame(width: 14, height: 14)
            .background(Circle().fill(color.opacity(0.15)))
    }

    private var icon: String {
        switch kind {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .connected: return "arrow.triangle.pull"
        }
    }

    private var color: Color {
        switch kind {
        case .warning: return PulseColors.amber
        case .error: return PulseColors.danger
        case .connected: return PulseColors.accent
        }
    }
}

struct NodeBadgesView: View {
    let node: CanvasNode
    let definition: NodeDefinition?
    let connectedEdgeCount: Int

    var body: some View {
        HStack(spacing: 2) {
            if hasMissingRequiredInput {
                NodeBadge(kind: .warning)
            }
            if hasInvalidConfig {
                NodeBadge(kind: .error)
            }
            if connectedEdgeCount > 0 {
                NodeBadge(kind: .connected)
            }
        }
    }

    private var hasMissingRequiredInput: Bool {
        guard let def = definition else { return false }
        // For now, flag if any required input has no config value
        return def.inputPorts.contains { $0.isRequired && node.config[$0.name] == nil }
    }

    private var hasInvalidConfig: Bool {
        // Check config values against schema min/max
        guard let def = definition else { return false }
        for field in def.configSchema {
            if let val = node.config[field.key]?.value as? Double {
                if let min = field.min, val < min { return true }
                if let max = field.max, val > max { return true }
            }
        }
        return false
    }
}
```

- [ ] **Step 3: Add badges to NodeView title bar**

In `NodeView.swift`, add badges to the `titleBar` HStack, before the Spacer:

```swift
// Add after the Text(name) line, before Spacer:
NodeBadgesView(node: node, definition: definition, connectedEdgeCount: 0) // connectedEdgeCount to be wired later
```

Also add port hover effect — in the `inputPorts` and `outputPorts` blocks, add `.onHover` to the Circle:

```swift
// For input port circles, add:
.scaleEffect(portHovered == port.name ? 1.3 : 1.0)
.animation(.spring(response: 0.2), value: portHovered)
.onHover { hovering in
    portHovered = hovering ? port.name : nil
}

// Add @State to NodeView:
@State private var portHovered: String?
```

- [ ] **Step 4: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/SnapGuidesView.swift macos-app/PulseDesk/Views/Canvas/NodeBadges.swift macos-app/PulseDesk/Views/Canvas/NodeView.swift
git commit -m "feat(canvas): add SnapGuidesView, NodeBadges, and port hover animations"
```

---

### Task 12: Implement CanvasSearchOverlay

**Files:**
- Create: `macos-app/PulseDesk/Views/Canvas/CanvasSearchOverlay.swift`

- [ ] **Step 1: Create CanvasSearchOverlay**

Create `macos-app/PulseDesk/Views/Canvas/CanvasSearchOverlay.swift`:

```swift
import SwiftUI

struct CanvasSearchOverlay: View {
    @Environment(PulseColors.self) private var colors
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let matchCount: Int
    let currentMatchIndex: Int
    let onNavigate: (Bool) -> Void // true = next, false = prev

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textMuted)

                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .focused($isFocused)

                if !searchText.isEmpty {
                    Text("\(currentMatchIndex + 1)/\(matchCount)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(matchCount > 0 ? colors.textSecondary : PulseColors.danger)
                        .monospacedDigit()

                    Button { onNavigate(false) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)

                    Button { onNavigate(true) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                }

                Button { isPresented = false; searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12)
        .onAppear { isFocused = true }
        .onChange(of: searchText) { _, _ in
            // matching is handled by parent
        }
    }
}
```

- [ ] **Step 2: Add search state and overlay to StrategyCanvasTab**

In `StrategyCanvasTab.swift`, add search state properties:

```swift
@State private var showSearch = false
@State private var searchText = ""
@State private var searchMatches: [UUID] = []
@State private var currentSearchIndex = 0
```

Add search overlay to the ZStack:

```swift
// At the end of the main ZStack (before closing brace):
.overlay(alignment: .top) {
    if showSearch {
        CanvasSearchOverlay(
            isPresented: $showSearch,
            searchText: $searchText,
            matchCount: searchMatches.count,
            currentMatchIndex: currentSearchIndex,
            onNavigate: navigateSearch
        )
        .padding(.top, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

Add search navigation function:

```swift
private func navigateSearch(next: Bool) {
    guard !searchMatches.isEmpty else { return }
    if next { currentSearchIndex = (currentSearchIndex + 1) % searchMatches.count }
    else { currentSearchIndex = (currentSearchIndex - 1 + searchMatches.count) % searchMatches.count }
    let targetId = searchMatches[currentSearchIndex]
    if let node = viewModel.graph.nodes.first(where: { $0.id == targetId }) {
        // Animate viewport to center on matched node
        withAnimation(.easeInOut(duration: 0.3)) {
            let cx = -(node.position.x + node.size.width / 2) * viewModel.viewport.scale + 400
            let cy = -(node.position.y + node.size.height / 2) * viewModel.viewport.scale + 300
            viewModel.viewport.offset = CGPoint(x: cx, y: cy)
        }
    }
}
```

Add search filter logic to `onChange(of: searchText)`:

```swift
.onChange(of: searchText) { _, text in
    if text.isEmpty {
        searchMatches = []
        currentSearchIndex = 0
    } else {
        searchMatches = viewModel.graph.nodes
            .filter { node in
                let def = NodeRegistry.definition(for: node.nodeType)
                let searchable = "\(def?.name ?? "") \(node.nodeType) \(node.config.values.map { String(describing: $0.value) }.joined())"
                return searchable.localizedCaseInsensitiveContains(text)
            }
            .map(\.id)
        currentSearchIndex = 0
        if let first = searchMatches.first {
            viewModel.selectNode(id: first)
        }
    }
}
```

Add keyboard shortcut for ⌘F:

```swift
// Add to the onKeyPress handlers:
.onKeyPress(keys: [.init("f")], phases: .down) { press in
    guard press.modifiers.contains(.command) else { return .ignored }
    withAnimation(.easeInOut(duration: 0.15)) { showSearch = true }
    return .handled
}
.onKeyPress(keys: [.init("g")], phases: .down) { press in
    guard press.modifiers.contains(.command) && showSearch else { return .ignored }
    navigateSearch(next: !press.modifiers.contains(.shift))
    return .handled
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/CanvasSearchOverlay.swift macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift
git commit -m "feat(canvas): add CanvasSearchOverlay with ⌘F node search and result navigation"
```

---

### Task 13: Wire remaining keyboard shortcuts and snap-on-drag-end

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift`

- [ ] **Step 1: Add snap engine integration to NodeDragWrapper**

In the `NodeDragWrapper` struct, add a snap engine and use it on drag end:

```swift
// Add inside NodeDragWrapper:
private let snapEngine = SnapEngine()

// In .onEnded, before committing position:
.onEnded { v in
    isDragging = false
    dragOffset = .zero
    let s = viewModel.viewport.scale
    let rawX = node.position.x + v.translation.width / s
    let rawY = node.position.y + v.translation.height / s
    let useGrid = NSEvent.modifierFlags.contains(.shift)
    let result = snapEngine.snap(
        position: CGPoint(x: rawX, y: rawY),
        size: node.size,
        otherNodes: viewModel.graph.nodes,
        excludeId: node.id,
        useGrid: useGrid
    )
    viewModel.startDrag(nodeId: node.id, at: node.position)
    viewModel.updateDrag(to: result.snappedPosition)
    viewModel.endDrag()
    // Pass snap guides back to parent via viewModel
    viewModel.activeSnapGuides = result.guides
}
```

- [ ] **Step 2: Add snap guides display in StrategyCanvasTab**

Add to the overlay layer in ZStack:

```swift
if !viewModel.activeSnapGuides.isEmpty {
    SnapGuidesView(guides: viewModel.activeSnapGuides,
                   scale: viewModel.viewport.scale,
                   offset: viewModel.viewport.offset)
        .allowsHitTesting(false)
        // Auto-clear after a brief delay
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.activeSnapGuides = []
            }
        }
}
```

- [ ] **Step 3: Add remaining keyboard shortcuts**

Add to the `onKeyPress` handlers in StrategyCanvasTab:

```swift
.onKeyPress(.init("c")) { press in
    guard press.modifiers.contains(.command) else { return .ignored }
    viewModel.copySelected(); return .handled
}
.onKeyPress(.init("v")) { press in
    guard press.modifiers.contains(.command) else { return .ignored }
    viewModel.paste(); return .handled
}
.onKeyPress(.init("d")) { press in
    guard press.modifiers.contains(.command) && !press.modifiers.contains(.shift) else { return .ignored }
    viewModel.duplicateSelected(); return .handled
}
.onKeyPress(.init("a")) { press in
    guard press.modifiers.contains(.command) else { return .ignored }
    viewModel.selectAll(); return .handled
}
.onKeyPress(.init("0")) { press in
    viewModel.fitToContent(); return .handled
}
```

Add arrow key nudge:

```swift
.onKeyPress(.leftArrow) { press in
    nudgeSelection(dx: press.modifiers.contains(.shift) ? -10 : -1, dy: 0); return .handled
}
.onKeyPress(.rightArrow) { press in
    nudgeSelection(dx: press.modifiers.contains(.shift) ? 10 : 1, dy: 0); return .handled
}
.onKeyPress(.upArrow) { press in
    nudgeSelection(dx: 0, dy: press.modifiers.contains(.shift) ? -10 : -1); return .handled
}
.onKeyPress(.downArrow) { press in
    nudgeSelection(dx: 0, dy: press.modifiers.contains(.shift) ? 10 : 1); return .handled
}
```

Add nudge helper:

```swift
private func nudgeSelection(dx: CGFloat, dy: CGFloat) {
    for id in viewModel.selectedNodeIds {
        if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == id }) {
            viewModel.graph.nodes[i].position.x += dx
            viewModel.graph.nodes[i].position.y += dy
        }
    }
}
```

- [ ] **Step 4: Add activeSnapGuides to CanvasViewModel**

In `CanvasViewModel.swift`, add:

```swift
var activeSnapGuides: [SnapGuide] = []
```

- [ ] **Step 5: Add multi-node drag support to CanvasViewModel**

In `CanvasViewModel.swift`, modify `startDrag` and `updateDrag` to support multi-node:

```swift
func startDrag(nodeId: UUID, at point: CGPoint) {
    draggingNodeId = nodeId
    // Record initial positions for all selected nodes if multi-drag
    if selectedNodeIds.contains(nodeId) && selectedNodeIds.count > 1 {
        multiDragStartPositions = [:]
        for id in selectedNodeIds {
            if let node = graph.nodes.first(where: { $0.id == id }) {
                multiDragStartPositions[id] = node.position
            }
        }
    }
    dragStartPosition = graph.nodes.first(where: { $0.id == nodeId })?.position
    guard let node = graph.nodes.first(where: { $0.id == nodeId }) else { return }
    dragOffset = CGSize(width: point.x - node.position.x, height: point.y - node.position.y)
}

func updateDrag(to point: CGPoint) {
    guard let nodeId = draggingNodeId else { return }
    if let multiPositions = multiDragStartPositions, !multiPositions.isEmpty {
        let delta = CGPoint(
            x: point.x - dragOffset.width - (multiPositions[nodeId]?.x ?? 0),
            y: point.y - dragOffset.height - (multiPositions[nodeId]?.y ?? 0)
        )
        for id in selectedNodeIds {
            if let startPos = multiPositions[id],
               let index = graph.nodes.firstIndex(where: { $0.id == id }) {
                graph.nodes[index].position = CGPoint(x: startPos.x + delta.x, y: startPos.y + delta.y)
            }
        }
    } else {
        let newPos = CGPoint(x: point.x - dragOffset.width, y: point.y - dragOffset.height)
        if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
            graph.nodes[index].position = newPos
        }
    }
}

func endDrag() {
    if let nodeId = draggingNodeId, let startPos = dragStartPosition {
        if let node = graph.nodes.first(where: { $0.id == nodeId }), node.position != startPos {
            record(.moveNode(id: nodeId, from: startPos, to: node.position))
        }
    }
    draggingNodeId = nil
    dragOffset = .zero
    dragStartPosition = nil
    multiDragStartPositions = nil
}

// Add property:
private var multiDragStartPositions: [UUID: CGPoint]?
```

- [ ] **Step 6: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 7: Commit**

```bash
git add macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift macos-app/PulseDesk/ViewModels/CanvasViewModel.swift
git commit -m "feat(canvas): add snap-on-drag-end, multi-node drag, full keyboard shortcut system"
```

---

## Phase 3: Panel Reworks

### Task 14: Rewrite NodePalette — tabs, favorites, recents, drag-to-add

**Files:**
- Modify: `macos-app/PulseDesk/Views/Canvas/NodePalette.swift` (complete rewrite)

- [ ] **Step 1: Rewrite NodePalette**

Replace entire contents of `NodePalette.swift`. The new palette uses a horizontal scrollable category tab bar, favorites section (UserDefaults), recently used section (in-memory MRU), fuzzy search, and drag-to-add.

```swift
import SwiftUI

struct NodePalette: View {
    @Environment(PulseColors.self) private var colors
    @Binding var isPresented: Bool
    var onAddNode: (NodeDefinition) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: NodeCategory? = nil
    @State private var favoriteTypes: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "canvas.favoriteNodes") ?? [])
    @State private var recentlyUsed: [String] = UserDefaults.standard.stringArray(forKey: "canvas.recentNodes") ?? []
    @FocusState private var isSearchFocused: Bool

    private let allDefinitions = NodeRegistry.allDefinitions

    private var displayedDefinitions: [NodeDefinition] {
        let categoryFiltered: [NodeDefinition]
        if let cat = selectedCategory {
            categoryFiltered = allDefinitions.filter { $0.category == cat }
        } else {
            categoryFiltered = allDefinitions
        }

        if searchText.isEmpty { return categoryFiltered }
        return categoryFiltered.filter { def in
            def.name.localizedCaseInsensitiveContains(searchText) ||
            def.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favoriteDefs: [NodeDefinition] {
        allDefinitions.filter { favoriteTypes.contains($0.type) }
    }

    private var recentDefs: [NodeDefinition] {
        recentlyUsed.compactMap { type in allDefinitions.first(where: { $0.type == type }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .focused($isSearchFocused)
            }
            .padding(8)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
            .padding(8)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    CategoryTab(label: "全部", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(NodeCategory.allCases, id: \.self) { cat in
                        CategoryTab(label: cat.label, isSelected: selectedCategory == cat) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            Divider().foregroundStyle(colors.border)

            // Node list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if searchText.isEmpty && selectedCategory == nil {
                        if !favoriteDefs.isEmpty {
                            sectionHeader("⭐ 收藏", onClear: { clearFavorites() })
                            ForEach(favoriteDefs) { def in nodeRow(def) }
                        }
                        if !recentDefs.isEmpty {
                            sectionHeader("🕐 最近使用", onClear: { clearRecents() })
                            ForEach(recentDefs) { def in nodeRow(def) }
                        }
                    }

                    if searchText.isEmpty && selectedCategory == nil {
                        ForEach(NodeCategory.allCases, id: \.self) { cat in
                            let catDefs = allDefinitions.filter { $0.category == cat }
                            if !catDefs.isEmpty {
                                sectionHeader("📂 \(cat.label)", onClear: nil)
                                ForEach(catDefs) { def in nodeRow(def) }
                            }
                        }
                    } else {
                        ForEach(displayedDefinitions) { def in nodeRow(def) }
                    }
                }
            }
        }
        .frame(width: 220)
        .background(colors.background)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(colors.border), alignment: .trailing)
        .onAppear { loadRecents() }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String, onClear: (() -> Void)?) -> some View {
        HStack {
            Text(title).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Spacer()
            if let onClear { Button("清除") { onClear() }.font(PulseFonts.micro).foregroundStyle(colors.accent).buttonStyle(.plain) }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    private func nodeRow(_ def: NodeDefinition) -> some View {
        HStack(spacing: 6) {
            Image(systemName: def.icon).font(.system(size: 10)).foregroundStyle(def.color).frame(width: 14)
            Text(def.name).font(PulseFonts.caption).foregroundStyle(colors.textPrimary).lineLimit(1)
            Spacer()
            Button {
                toggleFavorite(def)
            } label: {
                Image(systemName: favoriteTypes.contains(def.type) ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(favoriteTypes.contains(def.type) ? PulseColors.amber : colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onAddNode(def); addToRecent(def) }
        .onDrag { NSItemProvider(object: def.type as NSString) }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(colors.surfaceElevated.opacity(0.5))
                .opacity(0.0001) // transparent hit target
        )
    }

    // MARK: - Persistence

    private func toggleFavorite(_ def: NodeDefinition) {
        if favoriteTypes.contains(def.type) {
            favoriteTypes.remove(def.type)
        } else {
            favoriteTypes.insert(def.type)
        }
        persistFavorites()
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoriteTypes), forKey: "canvas.favoriteNodes")
    }

    private func clearFavorites() {
        favoriteTypes.removeAll()
        persistFavorites()
    }

    private func addToRecent(_ def: NodeDefinition) {
        recentlyUsed.removeAll { $0 == def.type }
        recentlyUsed.insert(def.type, at: 0)
        if recentlyUsed.count > 10 { recentlyUsed = Array(recentlyUsed.prefix(10)) }
        UserDefaults.standard.set(recentlyUsed, forKey: "canvas.recentNodes")
    }

    private func loadRecents() {
        recentlyUsed = UserDefaults.standard.stringArray(forKey: "canvas.recentNodes") ?? []
    }

    private func clearRecents() {
        recentlyUsed.removeAll()
        UserDefaults.standard.set(recentlyUsed, forKey: "canvas.recentNodes")
    }
}

// MARK: - CategoryTab
private struct CategoryTab: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? PulseColors.accent : colors.textMuted)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? PulseColors.accent.opacity(0.1) : .clear)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(isSelected ? PulseColors.accent : .clear),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/NodePalette.swift macos-app/PulseDesk/Services/NodeRegistry.swift
git commit -m "feat(canvas): rewrite NodePalette with tabs, favorites, recents, and drag-to-add"
```

---

### Task 15: Rewrite NodeConfigPanel — validation, filePicker, undo coalescing

**Files:**
- Modify: `macos-app/PulseDesk/Views/Canvas/NodeConfigPanel.swift` (complete rewrite)

- [ ] **Step 1: Rewrite NodeConfigPanel with validation and filePicker**

Replace entire contents of `NodeConfigPanel.swift`:

```swift
import SwiftUI
import AppKit

struct NodeConfigPanel: View {
    @Environment(PulseColors.self) private var colors
    let node: CanvasNode
    let definition: NodeDefinition?
    var onDelete: (() -> Void)?
    var onConfigChange: ((String, AnyCodable) -> Void)?
    var onWidgetChange: ((String, AnyCodable) -> Void)?

    @State private var showAdvanced = false
    @State private var showDeleteConfirm = false
    @State private var nameText: String = ""
    @State private var notesText: String = ""
    @State private var fieldErrors: [String: String] = [:]
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().foregroundStyle(colors.border)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    sectionLabel("名称")
                    configTextField(text: $nameText, placeholder: definition?.name ?? "")

                    sectionLabel("备注")
                    configTextField(text: $notesText, placeholder: "添加备注...")

                    Divider().foregroundStyle(colors.border)

                    if let definition, !definition.configSchema.isEmpty {
                        sectionLabel("参数")
                        ForEach(definition.configSchema) { field in
                            VStack(alignment: .leading, spacing: 2) {
                                configFieldView(field)
                                if let error = fieldErrors[field.key] {
                                    Text(error).font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                                }
                            }
                        }
                    }

                    Divider().foregroundStyle(colors.border)

                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                            sectionLabel("输出变量名")
                            configTextField(text: .constant(""), placeholder: "自动生成")
                            sectionLabel("执行条件")
                            configTextField(text: .constant(""), placeholder: "始终执行")
                        }.padding(.top, PulseSpacing.xs)
                    } label: {
                        Text("高级选项").font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
                    }
                }
                .padding(PulseSpacing.md)
            }
        }
        .frame(width: 320)
        .task { reloadNodeData() }
        .onChange(of: node.id) { _, _ in reloadNodeData() }
        .onChange(of: nameText) { _, new in onConfigChange?("name", AnyCodable(new)) }
        .onChange(of: notesText) { _, new in onConfigChange?("notes", AnyCodable(new)) }
        .background(colors.surfaceElevated)
        .overlay(Rectangle().fill(PulseGlass.surfaceTint(colors)).allowsHitTesting(false))
        .overlay(Rectangle().frame(width: 1).foregroundStyle(colors.border), alignment: .leading)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .commaSeparatedText, .pythonScript]) { result in
            if case .success(let url) = result {
                onConfigChange?("filePath", AnyCodable(url.path))
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: definition?.icon ?? "circle")
                .font(.system(size: 14)).foregroundStyle(definition?.color ?? colors.textSecondary)
            Text(definition?.name ?? node.nodeType)
                .font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary).lineLimit(1)
            Spacer()
            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(PulseColors.danger)
            }
            .buttonStyle(.plain).help("删除节点")
            .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) { onDelete?() }
                Button("取消", role: .cancel) {}
            } message: { Text("确定要删除节点 \"\(definition?.name ?? node.nodeType)\" 吗？") }
        }
        .padding(PulseSpacing.sm)
    }

    // MARK: - Config fields
    @ViewBuilder
    private func configFieldView(_ field: ConfigField) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(field.label).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                .frame(width: 60, alignment: .leading)
            if field.fieldType == .number || field.fieldType == .slider {
                Text("*").foregroundStyle(PulseColors.danger).font(PulseFonts.caption)
            }

            switch field.fieldType {
            case .text, .expression, .code:
                configTextField(
                    text: Binding(get: { node.config[field.key]?.value as? String ?? "" },
                                  set: { onConfigChange?(field.key, AnyCodable($0)); validateField(field, value: $0) }),
                    placeholder: field.defaultValue?.value as? String ?? ""
                )
            case .number:
                configTextField(
                    text: Binding(
                        get: { node.config[field.key].flatMap { String(describing: $0.value) } ?? "" },
                        set: { str in
                            if let d = Double(str) { onConfigChange?(field.key, AnyCodable(d)); validateField(field, value: d) }
                        }
                    ), placeholder: "0"
                )
            case .slider:
                let current = node.config[field.key]?.value as? Double ?? field.defaultValue?.value as? Double ?? 0
                let range = (field.min ?? 0)...(field.max ?? 100)
                Slider(value: Binding(get: { current },
                                      set: { onConfigChange?(field.key, AnyCodable($0)); validateField(field, value: $0) }),
                       in: range, step: field.step ?? 1)
                    .tint(PulseColors.accent)
                Text(String(format: "%.0f", current)).font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary).frame(width: 28, alignment: .trailing)
            case .dropdown:
                let current = node.config[field.key]?.value as? String ?? field.defaultValue?.value as? String ?? ""
                Picker(selection: Binding(get: { current }, set: { onConfigChange?(field.key, AnyCodable($0)) })) {
                    ForEach(field.options ?? [], id: \.self) { Text($0).tag($0) }
                } label: { EmptyView() }.pickerStyle(.menu).tint(PulseColors.accent)
            case .toggle:
                let current = node.config[field.key]?.value as? Bool ?? false
                Toggle(isOn: Binding(get: { current }, set: { onConfigChange?(field.key, AnyCodable($0)) })) { EmptyView() }
                    .toggleStyle(.switch).tint(PulseColors.accent)
            case .filePicker:
                let path = node.config[field.key]?.value as? String
                HStack(spacing: 4) {
                    Text(path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "选择文件...")
                        .font(PulseFonts.caption).foregroundStyle(path != nil ? colors.textPrimary : colors.textMuted).lineLimit(1)
                    Button { showFilePicker = true } label: {
                        Image(systemName: "folder").font(.system(size: 12)).foregroundStyle(PulseColors.accent)
                    }.buttonStyle(.plain)
                }
            case .multiselect:
                configTextField(
                    text: Binding(get: { node.config[field.key]?.value as? String ?? "" },
                                  set: { onConfigChange?(field.key, AnyCodable($0)) }),
                    placeholder: "选择..."
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(PulseFonts.captionMedium).foregroundStyle(colors.textMuted)
    }

    private func configTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
            .padding(PulseSpacing.xs).background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }

    private func reloadNodeData() {
        nameText = node.config["name"]?.value as? String ?? definition?.name ?? ""
        notesText = node.config["notes"]?.value as? String ?? ""
    }

    private func validateField(_ field: ConfigField, value: Any) {
        if let d = value as? Double {
            if let min = field.min, d < min {
                fieldErrors[field.key] = "最小 \(Int(min))"
            } else if let max = field.max, d > max {
                fieldErrors[field.key] = "最大 \(Int(max))"
            } else {
                fieldErrors.removeValue(forKey: field.key)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/NodeConfigPanel.swift
git commit -m "feat(canvas): rewrite NodeConfigPanel with validation, filePicker, and field error display"
```

---

### Task 16: Add undo coalescing to CanvasViewModel

**Files:**
- Modify: `macos-app/PulseDesk/ViewModels/CanvasViewModel.swift`

- [ ] **Step 1: Add config change debounce for undo coalescing**

Add a debounce mechanism in `CanvasViewModel.swift` for config changes. The drag coalescing is already handled in Task 13.

Add these properties:

```swift
// Config undo coalescing
private var configDebounceTasks: [String: Task<Void, Never>] = [:]
private var configOldValues: [String: AnyCodable] = [:]
private var configFieldKey: ((String) -> String) = { key in
    // Maps a config key back to the node:field key for coalescing
    ""
}
```

Replace `updateNodeWidget` to use debounce:

```swift
func updateNodeWidget(nodeId: UUID, key: String, value: AnyCodable) {
    if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
        let coalesceKey = "\(nodeId.uuidString).\(key)"
        let old = graph.nodes[index].widgetValues[key]

        // If old is nil, record immediately (first set)
        if old == nil {
            graph.nodes[index].widgetValues[key] = value
            record(.updateConfig(nodeId: nodeId, key: key, old: AnyCodable(""), new: value))
            scheduleSave()
            return
        }

        // Store oldest old value for undo
        if configOldValues[coalesceKey] == nil {
            configOldValues[coalesceKey] = old
        }

        graph.nodes[index].widgetValues[key] = value

        // Debounce — coalesce consecutive changes to same field
        configDebounceTasks[coalesceKey]?.cancel()
        configDebounceTasks[coalesceKey] = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if let savedOld = configOldValues[coalesceKey] {
                await MainActor.run {
                    record(.updateConfig(nodeId: nodeId, key: key, old: savedOld, new: value))
                    configOldValues.removeValue(forKey: coalesceKey)
                }
            }
            scheduleSave()
        }
    }
}
```

- [ ] **Step 2: Undo stack cap**

Add guard in `record()` to cap undo stack at 100:

```swift
private func record(_ action: CanvasAction) {
    undoStack.append(action)
    if undoStack.count > 100 {
        undoStack.removeFirst(undoStack.count - 100)
    }
    redoStack.removeAll()
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/ViewModels/CanvasViewModel.swift
git commit -m "feat(canvas): add undo coalescing with 500ms debounce and 100-entry cap"
```

---

## Phase 4: Polish + Code Gen + Tests

### Task 17: Implement CanvasErrorNotifier and loading/save states

**Files:**
- Create: `macos-app/PulseDesk/Services/CanvasErrorNotifier.swift`
- Modify: `macos-app/PulseDesk/ViewModels/CanvasViewModel.swift`
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift`

- [ ] **Step 1: Create CanvasErrorNotifier**

Create `macos-app/PulseDesk/Services/CanvasErrorNotifier.swift`:

```swift
import SwiftUI

@Observable
final class CanvasErrorNotifier {
    var currentToast: String?
    private var toastTask: Task<Void, Never>?
    private var consecutiveErrorCount = 0

    func showToast(_ message: String, duration: TimeInterval = 3) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = message
        }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentToast = nil
                }
            }
        }
    }

    func reportSaveError() {
        consecutiveErrorCount += 1
        if consecutiveErrorCount >= 3 {
            showToast("保存连续失败 \(consecutiveErrorCount) 次，请检查网络连接", duration: 5)
        } else {
            showToast("保存失败，10s 后重试")
        }
    }

    func reportSaveSuccess() {
        consecutiveErrorCount = 0
    }
}
```

- [ ] **Step 2: Add save status and error notifier to CanvasViewModel**

Add to `CanvasViewModel.swift`:

```swift
var saveStatus: SaveStatus = .saved
var isLoading = false
let errorNotifier = CanvasErrorNotifier()
```

Modify `saveToBackend`:

```swift
func saveToBackend() async {
    guard let api = canvasAPI, let sid = strategyId else { return }
    saveStatus = .saving
    do {
        let data = try graphSerializer.serialize(graph)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        let code = try CodeGenerator().generate(from: graph, strategyName: "Strategy_\(sid)")
        _ = try await api.save(strategyId: sid, graphJson: json, codeSnapshot: code)
        saveStatus = .saved
        errorNotifier.reportSaveSuccess()
    } catch {
        saveStatus = .error(error.localizedDescription)
        errorNotifier.reportSaveError()
    }
}
```

Modify `loadFromBackend`:

```swift
func loadFromBackend() async {
    guard let api = canvasAPI, let sid = strategyId else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        let response = try await api.load(strategyId: sid)
        if let data = response.graphJson.data(using: .utf8) {
            let loaded = try graphSerializer.deserialize(data)
            graph = loaded
        }
    } catch {
        errorNotifier.showToast("无法加载画布数据")
    }
}
```

- [ ] **Step 3: Add loading skeleton and toast to StrategyCanvasTab**

Add a loading skeleton overlay and save status bar to `StrategyCanvasTab`:

```swift
// Loading skeleton
if viewModel.isLoading {
    CanvasLoadingSkeleton()
        .transition(.opacity)
}

// Save status bar at bottom
VStack {
    Spacer()
    HStack {
        saveStatusIndicator
        Spacer()
        // Zoom indicator
        Text("\(Int(viewModel.viewport.scale * 100))%")
            .font(PulseFonts.micro).foregroundStyle(colors.textMuted).monospacedDigit()
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .background(colors.background.opacity(0.8))
}
```

Add save status indicator view:

```swift
private var saveStatusIndicator: some View {
    HStack(spacing: 4) {
        Circle()
            .fill(saveStatusColor).frame(width: 6, height: 6)
        Text(saveStatusText).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
    }
}

private var saveStatusColor: Color {
    switch viewModel.saveStatus {
    case .saved: return PulseColors.accent
    case .saving: return PulseColors.amber
    case .error: return PulseColors.danger
    case .dirty: return PulseColors.amber
    }
}

private var saveStatusText: String {
    switch viewModel.saveStatus {
    case .saved: return "已保存"
    case .saving: return "保存中..."
    case .error(let msg): return "保存失败"
    case .dirty: return "未保存"
    }
}
```

Add toast overlay (at top of ZStack):

```swift
// Toast
if let toast = viewModel.errorNotifier.currentToast {
    Text(toast)
        .font(PulseFonts.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(PulseColors.danger.opacity(0.9)))
        .padding(.top, 40)
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

- [ ] **Step 4: Create CanvasLoadingSkeleton**

Add to `StrategyCanvasTab.swift` as a private struct or create as a new file:

```swift
private struct CanvasLoadingSkeleton: View {
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors.surfaceElevated)
                    .frame(width: 200, height: 100)
                    .shimmer()
                    .offset(x: CGFloat(i * 60 - 90), y: CGFloat(i * 70 - 100))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }
}
```

- [ ] **Step 5: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add macos-app/PulseDesk/Services/CanvasErrorNotifier.swift macos-app/PulseDesk/ViewModels/CanvasViewModel.swift macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift
git commit -m "feat(canvas): add CanvasErrorNotifier, loading skeleton, save status indicator"
```

---

### Task 18: Enhance MiniMapView

**Files:**
- Modify: `macos-app/PulseDesk/Views/Canvas/MiniMapView.swift`

- [ ] **Step 1: Enhance MiniMapView with resize, selection highlight, hover opacity**

Read the current `MiniMapView.swift`. We'll enhance it by adding state properties and modifying the Canvas drawing to highlight selected nodes with accent color. Add a resize handle and hover-based opacity.

Add these new properties to the struct (alongside existing `minimapSize`):

```swift
@State private var minimapSize: CGSize = CGSize(width: 200, height: 150)
@State private var visibleOpacity: CGFloat = 0.4
@State private var opacityTask: Task<Void, Never>?
var selectedNodeIds: Set<UUID> = []
```

Modify the node drawing loop inside the existing `Canvas` block. Replace the existing node color assignment:

```swift
// Replace:
// let color = def?.category.color ?? colors.textMuted
// with:
let isSelected = selectedNodeIds.contains(node.id)
let color = isSelected ? PulseColors.accent : (def?.category.color ?? colors.textMuted)
let opacity: Double = isSelected ? 0.9 : 0.7
```

Then change the `context.fill` for nodes to use the new opacity:

```swift
context.fill(
    Path(roundedRect: rect, cornerRadius: 1),
    with: .color(color.opacity(opacity))
)
```

Wrap the entire view in a `ZStack` and add resize handle and hover behavior:

```swift
var body: some View {
    ZStack(alignment: .bottomTrailing) {
        // Existing Canvas block wrapped with hover opacity
        Canvas { context, size in
            // ... existing drawing code with selection highlight ...
        }
        .frame(width: minimapSize.width, height: minimapSize.height)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .opacity(visibleOpacity)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !nodes.isEmpty else { return }
                    let bounds = computeBounds()
                    let scaleX = minimapSize.width / max(bounds.width, 1)
                    let scaleY = minimapSize.height / max(bounds.height, 1)
                    let scale = min(scaleX, scaleY, 1.0)
                    let worldX = value.location.x / scale + bounds.minX
                    let worldY = value.location.y / scale + bounds.minY
                    onPan?(CGPoint(x: -worldX * viewport.scale, y: -worldY * viewport.scale))
                }
        )

        // Resize handle (bottom-right corner)
        Circle()
            .fill(colors.textMuted.opacity(0.4))
            .frame(width: 10, height: 10)
            .padding(2)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        let newW = max(100, min(400, minimapSize.width + v.translation.width))
                        let newH = max(75, min(300, minimapSize.height + v.translation.height))
                        minimapSize = CGSize(width: newW, height: newH)
                    }
            )
    }
    .onHover { hovering in
        opacityTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleOpacity = hovering ? 0.9 : 0.4
        }
        if !hovering {
            opacityTask = Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) { visibleOpacity = 0.4 }
                }
            }
        }
    }
}
```

Remove the old `let minimapSize = CGSize(width: 200, height: 150)` constant since we use `@State` now.

- [ ] **Step 2: Add MiniMapView to StrategyCanvasTab overlay**

In `StrategyCanvasTab.swift`, add MiniMapView as a bottom-trailing overlay inside the main ZStack (alongside existing overlays):

```swift
// Add to the ZStack overlays (after existing overlay(alignment: .topTrailing)):
.overlay(alignment: .bottomTrailing) {
    if !viewModel.graph.nodes.isEmpty {
        MiniMapView(
            nodes: viewModel.graph.nodes,
            viewport: viewModel.viewport,
            canvasSize: CGSize(width: 1200, height: 800),
            selectedNodeIds: viewModel.selectedNodeIds,
            onPan: { delta in viewModel.pan(by: delta) }
        )
        .padding(8)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Views/Canvas/MiniMapView.swift macos-app/PulseDesk/Views/Strategies/StrategyCanvasTab.swift
git commit -m "feat(canvas): enhance MiniMap with resize, smooth animation, and selection highlight"
```

---

### Task 19: Refactor CodeGenerator to template registry pattern

**Files:**
- Modify: `macos-app/PulseDesk/Services/CodeGenerator.swift`

- [ ] **Step 1: Replace switch/case with dictionary-driven template registry**

Read current CodeGenerator structure. Key changes:

1. Define a `CodeTemplate` protocol/struct:

```swift
struct CodeTemplate {
    let indicatorCode: ((CanvasNode, [String: String]) -> String)?  // inputVarName → generated code
    let entrySignalCode: ((CanvasNode, [String: String]) -> String)?
    let exitSignalCode: ((CanvasNode, [String: String]) -> String)?
}
```

2. Build a registry dictionary:

```swift
private let templateRegistry: [String: CodeTemplate] = [
    "indicator.rsi": CodeTemplate(
        indicatorCode: { node, vars in
            let period = node.config["period"]?.value as? Double ?? 14
            let source = vars["data"] ?? "close"
            return "        dataframe['rsi_\(node.id.uuidString.prefix(8))'] = ta.RSI(dataframe['\(source)'], timeperiod=\(Int(period)))"
        },
        entrySignalCode: { node, vars in
            let field = "rsi_\(node.id.uuidString.prefix(8))"
            let threshold = node.config["oversoldThreshold"]?.value as? Double ?? 30
            return "                (dataframe['\(field)'] < \(Int(threshold)))"
        },
        exitSignalCode: { node, vars in
            let field = "rsi_\(node.id.uuidString.prefix(8))"
            let threshold = node.config["overboughtThreshold"]?.value as? Double ?? 70
            return "                (dataframe['\(field)'] > \(Int(threshold)))"
        }
    ),
    "indicator.macd": CodeTemplate(
        indicatorCode: { node, vars in
            let fast = node.config["fastPeriod"]?.value as? Double ?? 12
            let slow = node.config["slowPeriod"]?.value as? Double ?? 26
            let signal = node.config["signalPeriod"]?.value as? Double ?? 9
            let source = vars["data"] ?? "close"
            let prefix = node.id.uuidString.prefix(8)
            return """
                    macd_\(prefix) = ta.MACD(dataframe['\(source)'], fastperiod=\(Int(fast)), slowperiod=\(Int(slow)), signalperiod=\(Int(signal)))
                    dataframe['macd_\(prefix)'] = macd_\(prefix)['macd']
                    dataframe['macdsignal_\(prefix)'] = macd_\(prefix)['macdsignal']
                    dataframe['macdhist_\(prefix)'] = macd_\(prefix)['macdhist']
            """
        },
        entrySignalCode: { node, vars in
            let prefix = node.id.uuidString.prefix(8)
            return "                (dataframe['macd_\(prefix)'] > dataframe['macdsignal_\(prefix)'])"
        },
        exitSignalCode: { node, vars in
            let prefix = node.id.uuidString.prefix(8)
            return "                (dataframe['macd_\(prefix)'] < dataframe['macdsignal_\(prefix)'])"
        }
    ),
    // ... extend for all 55 target node types
]
```

3. Modify generation methods to use registry:

```swift
func generate(from graph: WorkflowGraph, strategyName: String) throws -> String {
    let sorted = try topologicalSort(graph)
    // ... validation
    
    var indicatorCodes: [String] = []
    var entryConditions: [String] = []
    var exitConditions: [String] = []
    
    for node in sorted {
        guard let template = templateRegistry[node.nodeType] else {
            // Unknown node — emit warning comment
            indicatorCodes.append("        # warning: no code generator for node type '\(node.nodeType)'")
            continue
        }
        
        // Build input variable mappings from edges
        let inputVars = resolveInputVariables(node: node, graph: graph)
        
        if let indicatorFn = template.indicatorCode {
            indicatorCodes.append(indicatorFn(node, inputVars))
        }
        if let entryFn = template.entrySignalCode {
            entryConditions.append(entryFn(node, inputVars))
        }
        if let exitFn = template.exitSignalCode {
            exitConditions.append(exitFn(node, inputVars))
        }
    }
    
    return renderStrategyTemplate(name: strategyName, indicators: indicatorCodes, entries: entryConditions, exits: exitConditions)
}
```

4. Add template entries for the 55 node types. Prioritize:
- All 25 data/indicator nodes (RSI, MACD, BB, EMA, SMA, ATR, OBV, Stoch, CCI, ADX, etc.)
- All 15 signal processing nodes (cross, threshold, filter, normalize, etc.)
- All 10 decision nodes (AND, OR, weight vote, if-else, etc.)
- 5 AI nodes (LLM predict, sentiment filter, etc.)
- All 5 output nodes (already covered)

- [ ] **Step 2: Add helper method for input variable resolution**

```swift
private func resolveInputVariables(node: CanvasNode, graph: WorkflowGraph) -> [String: String] {
    var vars: [String: String] = [:]
    for edge in graph.edges where edge.targetNodeId == node.id {
        if let sourceNode = graph.nodes.first(where: { $0.id == edge.sourceNodeId }),
           let sourceDef = NodeRegistry.definition(for: sourceNode.nodeType) {
            let varName = sourceNode.config["outputVar"]?.value as? String
                ?? "\(sourceNode.nodeType.replacingOccurrences(of: ".", with: "_"))_\(sourceNode.id.uuidString.prefix(8))"
            vars[edge.targetPort] = varName
        }
    }
    return vars
}
```

- [ ] **Step 3: Verify build and existing behavior**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/CodeGenerator.swift
git commit -m "feat(canvas): refactor CodeGenerator to dictionary-driven template registry, expand to 55 node types"
```

---

### Task 20: Add backend canvas tests

**Files:**
- Create: `backend/tests/test_canvas.py`

- [ ] **Step 1: Create backend canvas tests**

Create `backend/tests/test_canvas.py`:

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.fixture
def anyio_backend():
    return "asyncio"

@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest.mark.anyio
async def test_canvas_save_and_load(client):
    # Create a strategy first
    create_resp = await client.post("/api/strategies", json={
        "name": "Test Canvas Strategy",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Save canvas
    graph_json = '{"nodes":[{"id":"test-1","nodeType":"indicator.rsi","position":{"x":100,"y":100},"size":{"width":200,"height":120},"config":{},"widgetValues":{},"isCollapsed":false,"isDisabled":false}],"edges":[],"groups":[],"viewport":{"scale":1.0,"offset":{"x":0,"y":0}}}'
    save_resp = await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": graph_json,
        "code_snapshot": "# test code"
    })
    assert save_resp.status_code == 201

    # Load canvas
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert load_resp.status_code == 200
    assert load_resp.json()["graph_json"] == graph_json

    # Clean up
    await client.delete(f"/api/strategies/{strategy_id}")

@pytest.mark.anyio
async def test_canvas_update(client):
    create_resp = await client.post("/api/strategies", json={
        "name": "Test Canvas Update",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Save initial
    await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": "{}",
        "code_snapshot": ""
    })

    # Update
    update_resp = await client.put(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": '{"nodes":[{"id":"updated","nodeType":"data.kline"}]}',
        "code_snapshot": "# updated"
    })
    assert update_resp.status_code == 200

    # Verify update
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert "data.kline" in load_resp.json()["graph_json"]

    await client.delete(f"/api/strategies/{strategy_id}")

@pytest.mark.anyio
async def test_canvas_large_graph_roundtrip(client):
    create_resp = await client.post("/api/strategies", json={
        "name": "Large Canvas Test",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Build 200 nodes
    nodes = []
    for i in range(200):
        nodes.append({
            "id": f"node-{i}",
            "nodeType": "indicator.rsi",
            "position": {"x": i * 150 % 5000, "y": i * 100 % 3000},
            "size": {"width": 200, "height": 120},
            "config": {"period": {"value": 14}},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })

    import json
    large_graph = json.dumps({
        "nodes": nodes,
        "edges": [],
        "groups": [],
        "viewport": {"scale": 1.0, "offset": {"x": 0, "y": 0}}
    })

    save_resp = await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": large_graph,
        "code_snapshot": ""
    })
    assert save_resp.status_code == 201

    # Load and verify
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert load_resp.status_code == 200
    loaded = json.loads(load_resp.json()["graph_json"])
    assert len(loaded["nodes"]) == 200

    await client.delete(f"/api/strategies/{strategy_id}")
```

- [ ] **Step 2: Run backend tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/test_canvas.py -q 2>&1`
Expected: 3 tests pass

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_canvas.py
git commit -m "test(backend): add canvas CRUD and large-graph roundtrip tests"
```

---

### Task 21: Final integration verification and run all tests

- [ ] **Step 1: Run all Swift tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift test 2>&1`
Expected: All tests pass (ViewportCullerTests, EdgeRouterTests, EdgeValidatorTests)

- [ ] **Step 2: Run all backend tests**

Run: `cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1`
Expected: All tests pass, including new canvas tests

- [ ] **Step 3: Verify full build**

Run: `cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: final integration — all canvas tests and build verified"
```
