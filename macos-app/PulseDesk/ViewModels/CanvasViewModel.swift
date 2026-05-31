// CanvasViewModel.swift — 画布视图模型
// 管理图状态、视口、选择、拖拽、连接线（接线状态机）、撤销/重做

import SwiftUI

// MARK: - WiringState — port wiring state machine

enum WiringState: Equatable {
    case idle
    case draggingFrom(sourceNodeId: UUID, sourcePortKey: String, fromPoint: CGPoint)
    case clickingFrom(sourceNodeId: UUID, sourcePortKey: String)

    var isActive: Bool {
        if case .idle = self { return false }
        return true
    }

    var sourcePortKey: String? {
        switch self {
        case .idle: return nil
        case .draggingFrom(_, let key, _): return key
        case .clickingFrom(_, let key): return key
        }
    }

    var sourceNodeId: UUID? {
        switch self {
        case .idle: return nil
        case .draggingFrom(let id, _, _): return id
        case .clickingFrom(let id, _): return id
        }
    }
}

// MARK: - CanvasAction — undo/redo action type

enum CanvasAction {
    case addNode(CanvasNode)
    case removeNode(CanvasNode)
    case moveNode(id: UUID, from: CGPoint, to: CGPoint)
    case addEdge(CanvasEdge)
    case removeEdge(CanvasEdge)
    case updateConfig(nodeId: UUID, key: String, old: AnyCodable, new: AnyCodable)
}

// MARK: - CanvasViewModel

@Observable
@MainActor
final class CanvasViewModel {
    // Graph state
    var graph = WorkflowGraph()

    // Selection
    var selectedNodeIds: Set<UUID> = []
    var selectedEdgeIds: Set<UUID> = []

    // Save/load state
    var saveStatus: SaveStatus = .saved
    var isLoading = false
    let errorNotifier = CanvasErrorNotifier()

    // Viewport — single source of truth lives in graph
    var viewport: ViewportState {
        get { graph.viewport }
        set { graph.viewport = newValue }
    }

    // Drag state
    var draggingNodeId: UUID?
    var dragOffset: CGSize = .zero
    var dragStartPosition: CGPoint?
    private var multiDragStartPositions: [UUID: CGPoint]?

    // Config undo coalescing
    private var configDebounceTasks: [String: Task<Void, Never>] = [:]
    private var configOldValues: [String: AnyCodable] = [:]

    // Wiring state
    var wiringState: WiringState = .idle
    var wireEndpoint: CGPoint?         // cursor position for rubber-band line
    var wireTargetPort: (nodeId: UUID, portKey: String)?  // port being hovered during drag
    let schema = ConnectionSchema()

    // Fullscreen
    var isFullscreen = false

    // Selection rectangle
    var selectionRect: CGRect?

    // Snap guides
    var activeSnapGuides: [SnapGuide] = []

    // Undo/Redo
    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []

    // Auto-save
    private var canvasAPI: APICanvas?
    private var strategyId: Int?
    private var saveTask: Task<Void, Never>?
    private var graphSerializer = GraphSerializer()
    private let clipboard = ClipboardManager()

    // Templates
    static let templates: [CanvasTemplate] = CanvasTemplate.builtInTemplates

    // MARK: - Computed

    var selectedNode: CanvasNode? {
        guard selectedNodeIds.count == 1, let id = selectedNodeIds.first else { return nil }
        return graph.nodes.first { $0.id == id }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Auto-save configuration

    func configure(client: any NetworkClientProtocol, strategyId: Int) {
        self.canvasAPI = APICanvas(client: client)
        self.strategyId = strategyId
        Task { await loadFromBackend() }
    }

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
            // Load failure is non-critical — start with empty canvas.
            // Save will surface real issues to the user.
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await saveToBackend()
        }
    }

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

    // MARK: - Node operations

    func addNode(_ node: CanvasNode) {
        graph.nodes.append(node)
        record(.addNode(node))
        scheduleSave()
    }

    func removeNode(id: UUID) {
        guard let index = graph.nodes.firstIndex(where: { $0.id == id }) else { return }
        let node = graph.nodes[index]
        graph.nodes.remove(at: index)
        // Also remove connected edges
        let connectedEdges = graph.edges.filter { $0.sourceNodeId == id || $0.targetNodeId == id }
        for edge in connectedEdges {
            graph.edges.removeAll { $0.id == edge.id }
        }
        selectedNodeIds.remove(id)
        record(.removeNode(node))
        scheduleSave()
    }

    func moveNode(id: UUID, to position: CGPoint) {
        guard let index = graph.nodes.firstIndex(where: { $0.id == id }) else { return }
        let oldPosition = graph.nodes[index].position
        graph.nodes[index].position = position
        record(.moveNode(id: id, from: oldPosition, to: position))
        scheduleSave()
    }

    func updateNodeWidget(nodeId: UUID, key: String, value: AnyCodable) {
        if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
            let coalesceKey = "\(nodeId.uuidString).\(key)"
            let old = graph.nodes[index].widgetValues[key]

            if old == nil {
                graph.nodes[index].widgetValues[key] = value
                record(.updateConfig(nodeId: nodeId, key: key, old: AnyCodable(""), new: value))
                scheduleSave()
                return
            }

            if configOldValues[coalesceKey] == nil {
                configOldValues[coalesceKey] = old
            }

            graph.nodes[index].widgetValues[key] = value

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

    // MARK: - Wiring (state machine)

    /// Start a wire drag from a port.
    func startWireDrag(nodeId: UUID, portKey: String, from point: CGPoint) {
        wiringState = .draggingFrom(sourceNodeId: nodeId, sourcePortKey: portKey, fromPoint: point)
        wireEndpoint = point
        wireTargetPort = nil
    }

    /// Update wire drag endpoint and optionally the port being hovered.
    func updateWireDrag(to point: CGPoint, hoveredPort: (nodeId: UUID, portKey: String)? = nil) {
        wireEndpoint = point
        wireTargetPort = hoveredPort
    }

    /// End a wire drag — attempt connection if hovering a valid target port.
    func endWireDrag() {
        if case .draggingFrom(let sourceNodeId, let sourcePortKey, _) = wiringState {
            if let target = wireTargetPort {
                tryConnect(
                    sourceNodeId: sourceNodeId,
                    sourcePortKey: sourcePortKey,
                    targetNodeId: target.nodeId,
                    targetPortKey: target.portKey
                )
            }
        }
        wiringState = .idle
        wireEndpoint = nil
        wireTargetPort = nil
    }

    /// Cancel active wiring without creating an edge.
    func cancelWiring() {
        wiringState = .idle
        wireEndpoint = nil
        wireTargetPort = nil
    }

    /// Handle a port tap for click-to-connect flow.
    /// - First tap on an output port enters `.clickingFrom` state.
    /// - Second tap on an input port creates the connection.
    /// - Tapping the same port again cancels.
    func handlePortTap(nodeId: UUID, portKey: String, direction: PortDirection) {
        switch wiringState {
        case .idle:
            // Only start click-to-connect from output ports
            if direction == .output {
                wiringState = .clickingFrom(sourceNodeId: nodeId, sourcePortKey: portKey)
            }

        case .clickingFrom(let sourceNodeId, let sourcePortKey):
            // Tapping same port cancels
            if sourceNodeId == nodeId && sourcePortKey == portKey {
                cancelWiring()
                return
            }
            // Tapping an input port on a different node attempts connection
            if direction == .input {
                tryConnect(
                    sourceNodeId: sourceNodeId,
                    sourcePortKey: sourcePortKey,
                    targetNodeId: nodeId,
                    targetPortKey: portKey
                )
            }
            cancelWiring()

        case .draggingFrom:
            // Port tap while in drag resets
            cancelWiring()
        }
    }

    /// Validate and create an edge between the given ports.
    func tryConnect(
        sourceNodeId: UUID,
        sourcePortKey: String,
        targetNodeId: UUID,
        targetPortKey: String
    ) {
        // Prevent duplicate
        guard !graph.edges.contains(where: {
            $0.sourceNodeId == sourceNodeId && $0.sourcePortKey == sourcePortKey &&
            $0.targetNodeId == targetNodeId && $0.targetPortKey == targetPortKey
        }) else { return }

        // Prevent self-connection
        guard sourceNodeId != targetNodeId else { return }

        // Validate port direction and data type compatibility
        let sourceDef = graph.nodes
            .first(where: { $0.id == sourceNodeId })
            .flatMap { NodeRegistry.definition(for: $0.nodeType) }
        let targetDef = graph.nodes
            .first(where: { $0.id == targetNodeId })
            .flatMap { NodeRegistry.definition(for: $0.nodeType) }

        if let sourcePort = sourceDef?.outputPorts.first(where: { $0.key == sourcePortKey }),
           let targetPort = targetDef?.inputPorts.first(where: { $0.key == targetPortKey }) {
            let result = schema.canConnect(
                from: sourcePort,
                to: targetPort,
                sourceNodeId: sourceNodeId,
                targetNodeId: targetNodeId,
                existingEdges: graph.edges
            )
            guard result.isAllowed else { return }
        }

        let edge = CanvasEdge(
            sourceNodeId: sourceNodeId,
            sourcePortKey: sourcePortKey,
            targetNodeId: targetNodeId,
            targetPortKey: targetPortKey
        )
        addEdge(edge)
        cancelWiring()
    }

    /// Check if a port is a valid target for the current wiring operation (for visual feedback).
    func isPortCompatible(nodeId: UUID, portKey: String, direction: PortDirection) -> Bool {
        guard wiringState.isActive else { return false }
        guard let sourceNodeId = wiringState.sourceNodeId,
              let sourcePortKey = wiringState.sourcePortKey else { return false }
        guard sourceNodeId != nodeId else { return false }

        // Only input ports are valid targets when dragging from an output port
        guard direction == .input else { return false }

        guard let sourceDef = graph.nodes
            .first(where: { $0.id == sourceNodeId })
            .flatMap({ NodeRegistry.definition(for: $0.nodeType) }),
              let targetDef = graph.nodes
            .first(where: { $0.id == nodeId })
            .flatMap({ NodeRegistry.definition(for: $0.nodeType) })
        else { return false }

        guard let sourcePort = sourceDef.outputPorts.first(where: { $0.key == sourcePortKey }),
              let targetPort = targetDef.inputPorts.first(where: { $0.key == portKey })
        else { return false }

        let result = schema.canConnect(
            from: sourcePort,
            to: targetPort,
            sourceNodeId: sourceNodeId,
            targetNodeId: nodeId,
            existingEdges: graph.edges
        )
        return result.isAllowed
    }

    /// Return all edges connected to a given port.
    func edgesForPort(nodeId: UUID, portKey: String) -> [CanvasEdge] {
        graph.edges.filter {
            ($0.sourceNodeId == nodeId && $0.sourcePortKey == portKey) ||
            ($0.targetNodeId == nodeId && $0.targetPortKey == portKey)
        }
    }

    /// Return the display name of the target node at the given edge's source port.
    func targetNodeName(for edge: CanvasEdge, portKey: String) -> String? {
        guard edge.sourcePortKey == portKey else { return nil }
        guard let targetNode = graph.nodes.first(where: { $0.id == edge.targetNodeId }) else { return nil }
        let def = NodeRegistry.definition(for: targetNode.nodeType)
        return def?.name ?? targetNode.nodeType
    }

    /// Return the display name of the source node at the given edge's target port.
    func sourceNodeName(for edge: CanvasEdge, portKey: String) -> String? {
        guard edge.targetPortKey == portKey else { return nil }
        guard let sourceNode = graph.nodes.first(where: { $0.id == edge.sourceNodeId }) else { return nil }
        let def = NodeRegistry.definition(for: sourceNode.nodeType)
        return def?.name ?? sourceNode.nodeType
    }

    // MARK: - Edge operations

    func addEdge(_ edge: CanvasEdge) {
        // Prevent duplicate edges
        guard !graph.edges.contains(where: {
            $0.sourceNodeId == edge.sourceNodeId &&
            $0.sourcePortKey == edge.sourcePortKey &&
            $0.targetNodeId == edge.targetNodeId &&
            $0.targetPortKey == edge.targetPortKey
        }) else { return }
        graph.edges.append(edge)
        record(.addEdge(edge))
        scheduleSave()
    }

    func removeEdge(id: UUID) {
        guard let index = graph.edges.firstIndex(where: { $0.id == id }) else { return }
        let edge = graph.edges[index]
        graph.edges.remove(at: index)
        selectedEdgeIds.remove(id)
        record(.removeEdge(edge))
        scheduleSave()
    }

    // MARK: - Selection

    func selectNode(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            if selectedNodeIds.contains(id) {
                selectedNodeIds.remove(id)
            } else {
                selectedNodeIds.insert(id)
            }
        } else {
            selectedNodeIds = [id]
        }
        selectedEdgeIds.removeAll()
    }

    func selectEdge(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            if selectedEdgeIds.contains(id) {
                selectedEdgeIds.remove(id)
            } else {
                selectedEdgeIds.insert(id)
            }
        } else {
            selectedEdgeIds = [id]
        }
        selectedNodeIds.removeAll()
    }

    func selectAll() {
        selectedNodeIds = Set(graph.nodes.map(\.id))
        selectedEdgeIds = Set(graph.edges.map(\.id))
    }

    func deselectAll() {
        selectedNodeIds.removeAll()
        selectedEdgeIds.removeAll()
    }

    // MARK: - Viewport

    func pan(by delta: CGPoint) {
        viewport.offset.x += delta.x
        viewport.offset.y += delta.y
    }

    func zoom(by factor: CGFloat, center: CGPoint) {
        let clampedScale = max(0.1, min(5.0, viewport.scale * factor))
        let scaleRatio = clampedScale / viewport.scale
        // Zoom toward center point
        viewport.offset.x = center.x - (center.x - viewport.offset.x) * scaleRatio
        viewport.offset.y = center.y - (center.y - viewport.offset.y) * scaleRatio
        viewport.scale = clampedScale
    }

    func fitToContent() {
        guard !graph.nodes.isEmpty else {
            viewport.scale = 1.0
            viewport.offset = .zero
            return
        }
        let positions = graph.nodes.map(\.position)
        let minX = positions.map(\.x).min() ?? 0
        let maxX = positions.map(\.x).max() ?? 0
        let minY = positions.map(\.y).min() ?? 0
        let maxY = positions.map(\.y).max() ?? 0

        let contentWidth = maxX - minX + 400 // add node width buffer
        let contentHeight = maxY - minY + 200

        // Assume a reasonable viewport size; actual size would come from geometry
        let viewWidth: CGFloat = 1200
        let viewHeight: CGFloat = 800

        let scaleX = viewWidth / max(contentWidth, 1)
        let scaleY = viewHeight / max(contentHeight, 1)
        viewport.scale = min(scaleX, scaleY, 2.0)
        viewport.offset = CGPoint(
            x: -minX * viewport.scale + 50,
            y: -minY * viewport.scale + 50
        )
    }

    // MARK: - Templates

    func loadTemplate(_ template: CanvasTemplate) {
        graph = template.graph
        undoStack.removeAll()
        redoStack.removeAll()
        selectedNodeIds.removeAll()
        selectedEdgeIds.removeAll()
        fitToContent()
        scheduleSave()
    }

    // MARK: - Clipboard (copy / paste / duplicate)

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

    // MARK: - Drag handling

    func startDrag(nodeId: UUID, at point: CGPoint) {
        draggingNodeId = nodeId
        if selectedNodeIds.contains(nodeId) && selectedNodeIds.count > 1 {
            multiDragStartPositions = [:]
            for id in selectedNodeIds {
                if let node = graph.nodes.first(where: { $0.id == id }) {
                    multiDragStartPositions![id] = node.position
                }
            }
        }
        dragStartPosition = graph.nodes.first(where: { $0.id == nodeId })?.position
        guard let node = graph.nodes.first(where: { $0.id == nodeId }) else { return }
        dragOffset = CGSize(
            width: point.x - node.position.x,
            height: point.y - node.position.y
        )
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

    // MARK: - Undo / Redo

    func undo() {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(action)
        applyInverse(action)
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        applyAction(action)
    }

    private func record(_ action: CanvasAction) {
        undoStack.append(action)
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
        redoStack.removeAll() // new action clears redo stack
    }

    private func applyAction(_ action: CanvasAction) {
        switch action {
        case .addNode(let node):
            graph.nodes.append(node)
        case .removeNode(let node):
            graph.nodes.removeAll { $0.id == node.id }
            graph.edges.removeAll { $0.sourceNodeId == node.id || $0.targetNodeId == node.id }
        case .moveNode(let id, _, let to):
            if let index = graph.nodes.firstIndex(where: { $0.id == id }) {
                graph.nodes[index].position = to
            }
        case .addEdge(let edge):
            graph.edges.append(edge)
        case .removeEdge(let edge):
            graph.edges.removeAll { $0.id == edge.id }
        case .updateConfig(let nodeId, let key, _, let new):
            if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
                graph.nodes[index].config[key] = new
            }
        }
    }

    private func applyInverse(_ action: CanvasAction) {
        switch action {
        case .addNode(let node):
            graph.nodes.removeAll { $0.id == node.id }
            graph.edges.removeAll { $0.sourceNodeId == node.id || $0.targetNodeId == node.id }
        case .removeNode(let node):
            graph.nodes.append(node)
        case .moveNode(let id, let from, _):
            if let index = graph.nodes.firstIndex(where: { $0.id == id }) {
                graph.nodes[index].position = from
            }
        case .addEdge(let edge):
            graph.edges.removeAll { $0.id == edge.id }
        case .removeEdge(let edge):
            graph.edges.append(edge)
        case .updateConfig(let nodeId, let key, let old, _):
            if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
                graph.nodes[index].config[key] = old
            }
        }
    }
}
