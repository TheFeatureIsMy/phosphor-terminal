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
        return def.inputPorts.contains { $0.isRequired && node.config[$0.name] == nil }
    }

    private var hasInvalidConfig: Bool {
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
