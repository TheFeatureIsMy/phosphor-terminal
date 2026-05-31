// CanvasModels.swift — 画布 / 工作流数据模型

import SwiftUI

// MARK: - WorkflowGraph — the canvas state
struct WorkflowGraph: Codable {
    var nodes: [CanvasNode]
    var edges: [CanvasEdge]
    var groups: [NodeGroup]
    var viewport: ViewportState

    init(nodes: [CanvasNode] = [], edges: [CanvasEdge] = [], groups: [NodeGroup] = [], viewport: ViewportState = ViewportState()) {
        self.nodes = nodes
        self.edges = edges
        self.groups = groups
        self.viewport = viewport
    }
}

// MARK: - CanvasNode
struct CanvasNode: Codable, Identifiable {
    let id: UUID
    let nodeType: String           // e.g. "data.kline", "indicator.rsi"
    var position: CGPoint
    var size: CGSize
    var config: [String: AnyCodable]
    var widgetValues: [String: AnyCodable]
    var isCollapsed: Bool
    var isDisabled: Bool

    init(id: UUID = UUID(), nodeType: String, position: CGPoint = .zero, size: CGSize = CGSize(width: 200, height: 120), config: [String: AnyCodable] = [:], widgetValues: [String: AnyCodable] = [:], isCollapsed: Bool = false, isDisabled: Bool = false) {
        self.id = id
        self.nodeType = nodeType
        self.position = position
        self.size = size
        self.config = config
        self.widgetValues = widgetValues
        self.isCollapsed = isCollapsed
        self.isDisabled = isDisabled
    }
}

// MARK: - CanvasEdge
struct CanvasEdge: Codable, Identifiable {
    let id: UUID
    let sourceNodeId: UUID
    let sourcePort: String
    let targetNodeId: UUID
    let targetPort: String
    let dataType: PortDataType

    init(id: UUID = UUID(), sourceNodeId: UUID, sourcePort: String, targetNodeId: UUID, targetPort: String, dataType: PortDataType) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.sourcePort = sourcePort
        self.targetNodeId = targetNodeId
        self.targetPort = targetPort
        self.dataType = dataType
    }
}

// MARK: - NodeGroup
struct NodeGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var nodeIds: [UUID]

    init(id: UUID = UUID(), title: String = "", nodeIds: [UUID] = []) {
        self.id = id
        self.title = title
        self.nodeIds = nodeIds
    }
}

// MARK: - ViewportState
struct ViewportState: Codable {
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
}

// MARK: - PortDataType — determines wire color and connection compatibility
enum PortDataType: String, Codable, CaseIterable {
    case ticker, kline, orderbook, indicator, signal, position
    case text, number, boolean, array, object
    case llmOutput, sentiment, riskMetric, macro
    case onchain, fundingRate, liquidation

    var label: String {
        switch self {
        case .ticker: return "行情"
        case .kline: return "K线"
        case .orderbook: return "订单簿"
        case .indicator: return "指标"
        case .signal: return "信号"
        case .position: return "持仓"
        case .text: return "文本"
        case .number: return "数值"
        case .boolean: return "布尔"
        case .array: return "数组"
        case .object: return "对象"
        case .llmOutput: return "LLM输出"
        case .sentiment: return "情绪"
        case .riskMetric: return "风险指标"
        case .macro: return "宏观"
        case .onchain: return "链上"
        case .fundingRate: return "资金费率"
        case .liquidation: return "清算"
        }
    }

    func color(_ colors: PulseColors) -> Color {
        switch self {
        case .ticker, .kline, .orderbook: return PulseColors.cyan
        case .indicator: return PulseColors.purple
        case .signal, .boolean: return PulseColors.amber
        case .position: return PulseColors.danger
        case .llmOutput, .sentiment, .riskMetric, .macro: return PulseColors.accent
        case .onchain, .fundingRate, .liquidation: return PulseColors.cyan
        case .text, .number, .array, .object: return colors.textSecondary
        }
    }
}

// MARK: - Variable reference for data passing between nodes
struct VariableRef: Codable {
    let nodeId: UUID
    let variableName: String
}

// MARK: - Node category
enum NodeCategory: String, CaseIterable, Codable {
    case data      // cyan
    case signal    // purple
    case decision  // amber
    case ai        // accent green
    case output    // danger red

    var label: String {
        switch self {
        case .data: return "数据源"
        case .signal: return "信号处理"
        case .decision: return "决策"
        case .ai: return "AI"
        case .output: return "输出"
        }
    }

    var color: Color {
        switch self {
        case .data: return PulseColors.cyan
        case .signal: return PulseColors.purple
        case .decision: return PulseColors.amber
        case .ai: return PulseColors.accent
        case .output: return PulseColors.danger
        }
    }

    var icon: String {
        switch self {
        case .data: return "antenna.radiowaves.left.and.right"
        case .signal: return "waveform.path.ecg"
        case .decision: return "switch.2"
        case .ai: return "brain.head.profile"
        case .output: return "arrow.right.circle"
        }
    }
}

// MARK: - Port definition
struct PortDefinition: Identifiable, @unchecked Sendable {
    let id = UUID()
    let name: String
    let dataType: PortDataType
    let isRequired: Bool
    let allowsMultiple: Bool

    init(name: String, dataType: PortDataType, isRequired: Bool = false, allowsMultiple: Bool = false) {
        self.name = name
        self.dataType = dataType
        self.isRequired = isRequired
        self.allowsMultiple = allowsMultiple
    }
}

// MARK: - Config field for right-panel editing
struct ConfigField: Identifiable, @unchecked Sendable {
    let id = UUID()
    let key: String
    let label: String
    let fieldType: ConfigFieldType
    let defaultValue: AnyCodable?
    let options: [String]?  // for dropdown
    let min: Double?        // for slider/number
    let max: Double?
    let step: Double?

    init(key: String, label: String, fieldType: ConfigFieldType, defaultValue: AnyCodable? = nil, options: [String]? = nil, min: Double? = nil, max: Double? = nil, step: Double? = nil) {
        self.key = key
        self.label = label
        self.fieldType = fieldType
        self.defaultValue = defaultValue
        self.options = options
        self.min = min
        self.max = max
        self.step = step
    }
}

enum ConfigFieldType {
    case text, number, dropdown, slider, toggle, expression, code, multiselect, filePicker
}

// MARK: - Widget definition for inline node controls
struct WidgetDefinition: Identifiable, @unchecked Sendable {
    let id = UUID()
    let key: String
    let label: String
    let widgetType: WidgetType
    let min: Double?
    let max: Double?
    let step: Double?
    let options: [String]?

    init(key: String, label: String, widgetType: WidgetType, min: Double? = nil, max: Double? = nil, step: Double? = nil, options: [String]? = nil) {
        self.key = key
        self.label = label
        self.widgetType = widgetType
        self.min = min
        self.max = max
        self.step = step
        self.options = options
    }
}

enum WidgetType {
    case slider, dropdown, toggle, numberInput, textInput
}

// MARK: - Node definition (registry entry)
struct NodeDefinition: Identifiable, @unchecked Sendable {
    let id: String  // same as type, e.g. "data.kline"
    let type: String
    let category: NodeCategory
    let name: String              // display name (Chinese)
    let icon: String              // SF Symbol
    let color: Color              // node theme color (usually category color)
    let inputPorts: [PortDefinition]
    let outputPorts: [PortDefinition]
    let configSchema: [ConfigField]
    let widgetDefinitions: [WidgetDefinition]

    init(type: String, category: NodeCategory, name: String, icon: String, color: Color? = nil, inputPorts: [PortDefinition] = [], outputPorts: [PortDefinition] = [], configSchema: [ConfigField] = [], widgetDefinitions: [WidgetDefinition] = []) {
        self.id = type
        self.type = type
        self.category = category
        self.name = name
        self.icon = icon
        self.color = color ?? category.color
        self.inputPorts = inputPorts
        self.outputPorts = outputPorts
        self.configSchema = configSchema
        self.widgetDefinitions = widgetDefinitions
    }
}
