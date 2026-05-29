// CanvasViewModel.swift — 画布视图模型
// 管理图状态、视口、选择、拖拽、撤销/重做

import SwiftUI

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

    // Viewport — single source of truth lives in graph
    var viewport: ViewportState {
        get { graph.viewport }
        set { graph.viewport = newValue }
    }

    // Drag state
    var draggingNodeId: UUID?
    var dragOffset: CGSize = .zero
    var dragStartPosition: CGPoint?

    // Wire drag state (connecting ports)
    var wireDragSource: (nodeId: UUID, port: String)?
    var wireDragTarget: CGPoint?

    // Selection rectangle
    var selectionRect: CGRect?

    // Undo/Redo
    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []

    // MARK: - Computed

    var selectedNode: CanvasNode? {
        guard selectedNodeIds.count == 1, let id = selectedNodeIds.first else { return nil }
        return graph.nodes.first { $0.id == id }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Node operations

    func addNode(_ node: CanvasNode) {
        graph.nodes.append(node)
        record(.addNode(node))
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
    }

    func moveNode(id: UUID, to position: CGPoint) {
        guard let index = graph.nodes.firstIndex(where: { $0.id == id }) else { return }
        let oldPosition = graph.nodes[index].position
        graph.nodes[index].position = position
        record(.moveNode(id: id, from: oldPosition, to: position))
    }

    func updateNodeWidget(nodeId: UUID, key: String, value: AnyCodable) {
        if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
            let old = graph.nodes[index].widgetValues[key]
            graph.nodes[index].widgetValues[key] = value
            if let old {
                record(.updateConfig(nodeId: nodeId, key: key, old: old, new: value))
            }
        }
    }

    // MARK: - Edge operations

    func addEdge(_ edge: CanvasEdge) {
        // Prevent duplicate edges
        guard !graph.edges.contains(where: {
            $0.sourceNodeId == edge.sourceNodeId &&
            $0.sourcePort == edge.sourcePort &&
            $0.targetNodeId == edge.targetNodeId &&
            $0.targetPort == edge.targetPort
        }) else { return }
        graph.edges.append(edge)
        record(.addEdge(edge))
    }

    func removeEdge(id: UUID) {
        guard let index = graph.edges.firstIndex(where: { $0.id == id }) else { return }
        let edge = graph.edges[index]
        graph.edges.remove(at: index)
        selectedEdgeIds.remove(id)
        record(.removeEdge(edge))
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

    // MARK: - Drag handling

    func startDrag(nodeId: UUID, at point: CGPoint) {
        draggingNodeId = nodeId
        dragStartPosition = graph.nodes.first(where: { $0.id == nodeId })?.position
        guard let node = graph.nodes.first(where: { $0.id == nodeId }) else { return }
        dragOffset = CGSize(
            width: point.x - node.position.x,
            height: point.y - node.position.y
        )
    }

    func updateDrag(to point: CGPoint) {
        guard let nodeId = draggingNodeId else { return }
        let newPos = CGPoint(
            x: point.x - dragOffset.width,
            y: point.y - dragOffset.height
        )
        if let index = graph.nodes.firstIndex(where: { $0.id == nodeId }) {
            graph.nodes[index].position = newPos
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
    }

    // MARK: - Wire drag (connecting ports)

    func startWireDrag(nodeId: UUID, port: String) {
        wireDragSource = (nodeId: nodeId, port: port)
    }

    func updateWireDrag(to point: CGPoint) {
        wireDragTarget = point
    }

    func endWireDrag() {
        wireDragSource = nil
        wireDragTarget = nil
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
