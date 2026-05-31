// ClipboardManager.swift — 复制/粘贴/重复 节点和边
// 使用 NSPasteboard 跨粘贴板交互

import AppKit
import Foundation

struct ClipboardManager {
    private let pasteboard = NSPasteboard.general
    private let serializer = GraphSerializer()

    func copy(nodes: [CanvasNode], edges: [CanvasEdge], from graph: WorkflowGraph) {
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
                       sourcePortKey: edge.sourcePortKey,
                       targetNodeId: idMap[edge.targetNodeId] ?? edge.targetNodeId,
                       targetPortKey: edge.targetPortKey)
        }
        return (newNodes, newEdges)
    }
}
