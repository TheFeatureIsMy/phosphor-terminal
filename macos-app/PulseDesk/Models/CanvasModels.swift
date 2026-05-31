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
    let sourcePortKey: String     // matches PortDefinition.key
    let targetNodeId: UUID
    let targetPortKey: String

    init(id: UUID = UUID(), sourceNodeId: UUID, sourcePortKey: String, targetNodeId: UUID, targetPortKey: String) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.sourcePortKey = sourcePortKey
        self.targetNodeId = targetNodeId
        self.targetPortKey = targetPortKey
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

// MARK: - Port direction — input (left side) / output (right side)
enum PortDirection: String, Codable, CaseIterable {
    case input   // rendered on left side of node
    case output  // rendered on right side of node
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
    let key: String               // stable identifier, e.g. "kline", "rsiValue"
    let name: String              // display label, e.g. "K线数据", "RSI值"
    let direction: PortDirection  // .input or .output
    let dataType: PortDataType
    let isRequired: Bool
    let allowsMultiple: Bool
    let tooltip: String

    init(key: String, name: String, direction: PortDirection, dataType: PortDataType, isRequired: Bool = false, allowsMultiple: Bool = false, tooltip: String = "") {
        self.key = key
        self.name = name
        self.direction = direction
        self.dataType = dataType
        self.isRequired = isRequired
        self.allowsMultiple = allowsMultiple
        self.tooltip = tooltip
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

// MARK: - Connection validation

enum ConnectionResult: Equatable {
    case allowed
    case incompatibleType(PortDataType, PortDataType)
    case wrongDirection
    case alreadyFullyConnected
    case selfConnection

    var isAllowed: Bool { self == .allowed }
}

struct ConnectionSchema {
    func canConnect(from sourcePort: PortDefinition, to targetPort: PortDefinition, sourceNodeId: UUID, targetNodeId: UUID, existingEdges: [CanvasEdge]) -> ConnectionResult {
        if sourceNodeId == targetNodeId { return .selfConnection }
        if sourcePort.direction != .output { return .wrongDirection }
        if targetPort.direction != .input { return .wrongDirection }
        let compatible = sourcePort.dataType == targetPort.dataType
            || sourcePort.dataType == .signal
            || targetPort.dataType == .signal
        if !compatible { return .incompatibleType(sourcePort.dataType, targetPort.dataType) }
        if !targetPort.allowsMultiple {
            let alreadyConnected = existingEdges.contains {
                $0.targetNodeId == targetNodeId && $0.targetPortKey == targetPort.key
            }
            if alreadyConnected { return .alreadyFullyConnected }
        }
        return .allowed
    }
}

// MARK: - CanvasTemplate

struct CanvasTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let nodeCount: Int
    let graph: WorkflowGraph
}

// MARK: - Cached port position (for edge rendering)
struct CachedPortPosition {
    let nodeId: UUID
    let portKey: String
    let worldPosition: CGPoint
}

// MARK: - Save status for auto-save feedback
enum SaveStatus {
    case saved
    case saving
    case error(String)
    case dirty
}

// MARK: - Built-in templates

@MainActor
extension CanvasTemplate {
    static let builtInTemplates: [CanvasTemplate] = [maCrossTemplate, aiSignalTemplate, gridTemplate]

    static let maCrossTemplate: CanvasTemplate = {
        let klineId = UUID()
        let fastMAId = UUID()
        let slowMAId = UUID()
        let entryId = UUID()

        return CanvasTemplate(
            id: "ma_cross",
            name: "均线交叉",
            description: "经典双均线交叉策略，金叉买入死叉卖出",
            icon: "chart.line.flattrend.xyaxis",
            nodeCount: 4,
            graph: WorkflowGraph(
                nodes: [
                    CanvasNode(id: klineId, nodeType: "data.kline", position: CGPoint(x: 0, y: 80),
                               size: CGSize(width: 200, height: 100),
                               config: ["symbol": AnyCodable("BTC/USDT"), "timeframe": AnyCodable("1h")]),
                    CanvasNode(id: fastMAId, nodeType: "indicator.ma", position: CGPoint(x: 260, y: 20),
                               size: CGSize(width: 200, height: 100),
                               config: ["period": AnyCodable(5), "type": AnyCodable("EMA")]),
                    CanvasNode(id: slowMAId, nodeType: "indicator.ma", position: CGPoint(x: 260, y: 140),
                               size: CGSize(width: 200, height: 100),
                               config: ["period": AnyCodable(20), "type": AnyCodable("EMA")]),
                    CanvasNode(id: entryId, nodeType: "strategy.entry", position: CGPoint(x: 520, y: 80),
                               size: CGSize(width: 200, height: 100),
                               config: ["entryConditions": AnyCodable("ma_fast > ma_slow"), "positionSize": AnyCodable(1000)]),
                ],
                edges: [
                    CanvasEdge(sourceNodeId: klineId, sourcePortKey: "kline", targetNodeId: fastMAId, targetPortKey: "kline"),
                    CanvasEdge(sourceNodeId: klineId, sourcePortKey: "kline", targetNodeId: slowMAId, targetPortKey: "kline"),
                    CanvasEdge(sourceNodeId: fastMAId, sourcePortKey: "maValue", targetNodeId: entryId, targetPortKey: "signal"),
                ]
            )
        )
    }()

    static let aiSignalTemplate: CanvasTemplate = {
        let klineId = UUID()
        let rsiId = UUID()
        let macdId = UUID()
        let llmId = UUID()
        let scoringId = UUID()
        let entryId = UUID()

        return CanvasTemplate(
            id: "ai_signal",
            name: "AI 信号策略",
            description: "利用AI情绪分析和LLM推理辅助交易决策",
            icon: "brain.head.profile",
            nodeCount: 6,
            graph: WorkflowGraph(
                nodes: [
                    CanvasNode(id: klineId, nodeType: "data.kline", position: CGPoint(x: 0, y: 120),
                               size: CGSize(width: 200, height: 100),
                               config: ["symbol": AnyCodable("BTC/USDT"), "timeframe": AnyCodable("4h")]),
                    CanvasNode(id: rsiId, nodeType: "indicator.rsi", position: CGPoint(x: 260, y: 20),
                               size: CGSize(width: 200, height: 100),
                               config: ["period": AnyCodable(14)]),
                    CanvasNode(id: macdId, nodeType: "indicator.macd", position: CGPoint(x: 260, y: 140),
                               size: CGSize(width: 200, height: 120),
                               config: ["fast": AnyCodable(12), "slow": AnyCodable(26), "signal": AnyCodable(9)]),
                    CanvasNode(id: llmId, nodeType: "ai.llm", position: CGPoint(x: 260, y: 260),
                               size: CGSize(width: 200, height: 100),
                               config: ["model": AnyCodable("Claude"), "temperature": AnyCodable(0.3)]),
                    CanvasNode(id: scoringId, nodeType: "ai.scoring", position: CGPoint(x: 520, y: 80),
                               size: CGSize(width: 200, height: 100)),
                    CanvasNode(id: entryId, nodeType: "strategy.entry", position: CGPoint(x: 780, y: 120),
                               size: CGSize(width: 200, height: 100),
                               config: ["entryConditions": AnyCodable("score > 0.7"), "positionSize": AnyCodable(500)]),
                ],
                edges: [
                    CanvasEdge(sourceNodeId: klineId, sourcePortKey: "kline", targetNodeId: rsiId, targetPortKey: "kline"),
                    CanvasEdge(sourceNodeId: klineId, sourcePortKey: "kline", targetNodeId: macdId, targetPortKey: "kline"),
                    CanvasEdge(sourceNodeId: rsiId, sourcePortKey: "rsiValue", targetNodeId: scoringId, targetPortKey: "signal"),
                    CanvasEdge(sourceNodeId: macdId, sourcePortKey: "macd", targetNodeId: scoringId, targetPortKey: "signal"),
                    CanvasEdge(sourceNodeId: llmId, sourcePortKey: "analysis", targetNodeId: scoringId, targetPortKey: "signal"),
                    CanvasEdge(sourceNodeId: scoringId, sourcePortKey: "score", targetNodeId: entryId, targetPortKey: "signal"),
                ]
            )
        )
    }()

    static let gridTemplate: CanvasTemplate = {
        let klineId = UUID()
        let bollingerId = UUID()
        let entryId = UUID()

        return CanvasTemplate(
            id: "grid",
            name: "网格交易",
            description: "震荡市布林带网格交易策略",
            icon: "tablecells",
            nodeCount: 3,
            graph: WorkflowGraph(
                nodes: [
                    CanvasNode(id: klineId, nodeType: "data.kline", position: CGPoint(x: 0, y: 50),
                               size: CGSize(width: 200, height: 100),
                               config: ["symbol": AnyCodable("ETH/USDT"), "timeframe": AnyCodable("15m")]),
                    CanvasNode(id: bollingerId, nodeType: "indicator.bollinger", position: CGPoint(x: 260, y: 60),
                               size: CGSize(width: 200, height: 120),
                               config: ["period": AnyCodable(20), "stdDev": AnyCodable(2.0)]),
                    CanvasNode(id: entryId, nodeType: "strategy.entry", position: CGPoint(x: 520, y: 50),
                               size: CGSize(width: 200, height: 100),
                               config: ["entryConditions": AnyCodable("price < lower"), "positionSize": AnyCodable(200)]),
                ],
                edges: [
                    CanvasEdge(sourceNodeId: klineId, sourcePortKey: "kline", targetNodeId: bollingerId, targetPortKey: "kline"),
                    CanvasEdge(sourceNodeId: bollingerId, sourcePortKey: "lower", targetNodeId: entryId, targetPortKey: "signal"),
                ]
            )
        )
    }()
}
