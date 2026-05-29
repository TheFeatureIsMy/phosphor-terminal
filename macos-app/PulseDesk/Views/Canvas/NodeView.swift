// NodeView.swift — 单节点渲染组件
// 玻璃卡片风格，端口，折叠/展开，选中/禁用态

import SwiftUI

struct NodeView: View {
    let node: CanvasNode
    let definition: NodeDefinition?
    let isSelected: Bool
    let isDragging: Bool
    /// Called when starting a node drag; receives gesture location in world coordinates
    var onNodeDragStart: ((CGPoint) -> Void)?
    /// Called during node drag; receives gesture location in world coordinates
    var onNodeDragUpdate: ((CGPoint) -> Void)?
    /// Called when node drag ends
    var onNodeDragEnd: (() -> Void)?
    /// Called when tapping an output port to start a wire drag
    var onOutputPortTap: ((UUID, String) -> Void)?
    /// Called when tapping an input port to complete a wire drag
    var onInputPortTap: ((UUID, String) -> Void)?
    /// Viewport scale for coordinate conversion
    var viewportScale: CGFloat = 1.0
    /// Viewport offset for coordinate conversion
    var viewportOffset: CGPoint = .zero
    /// Called when collapse toggle is tapped
    var onCollapseToggle: (() -> Void)?
    /// Called when a widget value changes
    var onWidgetChange: ((String, AnyCodable) -> Void)?

    /// Tracks whether a node drag gesture has already fired its start callback
    @State private var hasStartedDrag = false
    /// Tracks whether an output port wire drag has already fired its start callback
    @State private var hasStartedWireDrag = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar (draggable)
            titleBar

            if !node.isCollapsed {
                Divider().foregroundStyle(PulseColors.border)

                // Input ports
                inputPorts

                // Widget controls (inline)
                if let definition, !definition.widgetDefinitions.isEmpty {
                    widgetControls(definition.widgetDefinitions)
                }

                // Output ports
                outputPorts
            }
        }
        .frame(width: node.size.width)
        .opacity(node.isDisabled ? 0.5 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(PulseColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(isSelected ? PulseColors.accent : PulseColors.border, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? PulseColors.accent.opacity(0.2) : .clear, radius: 8)
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: definition?.icon ?? "circle")
                .font(.system(size: 12))
                .foregroundStyle(definition?.color ?? PulseColors.textSecondary)

            Text(definition?.name ?? node.nodeType)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Collapse button
            Button {
                onCollapseToggle?()
            } label: {
                Image(systemName: node.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseColors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, PulseSpacing.xs)
        .contentShape(Rectangle())
        .gesture(nodeDragGesture)
    }

    // MARK: - Input ports

    private var inputPorts: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(definition?.inputPorts ?? []) { port in
                HStack(spacing: 6) {
                    Circle()
                        .fill(port.dataType.color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(PulseColors.background, lineWidth: 2))
                        .onTapGesture {
                            onInputPortTap?(node.id, port.name)
                        }
                    Text(port.name)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.textSecondary)
                }
                .padding(.leading, PulseSpacing.sm)
            }
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Output ports

    private var outputPorts: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(definition?.outputPorts ?? []) { port in
                HStack(spacing: 6) {
                    Text(port.name)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.textSecondary)
                    Circle()
                        .fill(port.dataType.color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(PulseColors.background, lineWidth: 2))
                        .contentShape(Circle())
                        .gesture(outputPortDragGesture(nodeId: node.id, portName: port.name))
                }
                .padding(.trailing, PulseSpacing.sm)
            }
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Widget controls

    @ViewBuilder
    private func widgetControls(_ widgets: [WidgetDefinition]) -> some View {
        VStack(spacing: 6) {
            ForEach(widgets) { widget in
                HStack {
                    Text(widget.label)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.textMuted)
                        .frame(width: 50, alignment: .leading)

                    switch widget.widgetType {
                    case .slider:
                        let currentValue = node.widgetValues[widget.key]?.value as? Double ?? widget.min ?? 0
                        let range = (widget.min ?? 0)...(widget.max ?? 1)
                        Slider(value: Binding(
                            get: { currentValue },
                            set: { onWidgetChange?(widget.key, AnyCodable($0)) }
                        ), in: range)
                        .tint(PulseColors.accent)
                    case .dropdown:
                        Text(widget.options?.first ?? "—")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.textSecondary)
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, PulseSpacing.sm)
            }
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Gestures

    /// Drag gesture on the title bar to move the node (world coordinates)
    private var nodeDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let worldPos = CGPoint(
                    x: (value.location.x - viewportOffset.x) / viewportScale,
                    y: (value.location.y - viewportOffset.y) / viewportScale
                )
                if !hasStartedDrag {
                    hasStartedDrag = true
                    onNodeDragStart?(worldPos)
                }
                onNodeDragUpdate?(worldPos)
            }
            .onEnded { _ in
                hasStartedDrag = false
                onNodeDragEnd?()
            }
    }

    /// Drag gesture on an output port circle to start/preview a wire connection
    private func outputPortDragGesture(nodeId: UUID, portName: String) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if !hasStartedWireDrag {
                    hasStartedWireDrag = true
                    onOutputPortTap?(nodeId, portName)
                }
            }
            .onEnded { _ in
                hasStartedWireDrag = false
            }
    }
}
