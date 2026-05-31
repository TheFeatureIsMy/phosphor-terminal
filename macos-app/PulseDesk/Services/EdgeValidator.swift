import Foundation

struct EdgeValidator {
    // Downward-compatible type chain
    private let compatiblePairs: Set<String> = [
        "kline→indicator", "orderbook→indicator", "ticker→indicator",
        "indicator→signal", "indicator→indicator",
        "signal→boolean", "signal→signal",
        "boolean→boolean", "boolean→signal",
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

        // DFS cycle detection
        var visited = Set<UUID>()
        var recStack = Set<UUID>()
        var stack: [(UUID, Bool)] = [(source, true)]

        while let (current, entering) = stack.popLast() {
            if entering {
                if recStack.contains(current) { return true }
                if visited.contains(current) { continue }
                visited.insert(current)
                recStack.insert(current)
                stack.append((current, false))
                for neighbor in adj[current] ?? [] {
                    stack.append((neighbor, true))
                }
            } else {
                recStack.remove(current)
            }
        }
        return false
    }
}
