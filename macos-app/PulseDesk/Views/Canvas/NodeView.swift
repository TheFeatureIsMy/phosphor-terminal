// NodeView.swift — 节点渲染
// 输入端口在左侧，输出端口在右侧，支持拖拽连线和点击连线

import SwiftUI

struct NodeView: View {
    @Environment(PulseColors.self) private var colors
    let node: CanvasNode
    let definition: NodeDefinition?
    let isSelected: Bool
    let isDragging: Bool

    // Port interactions (all NEW signatures)
    var onPortDragStart: ((UUID, String, CGPoint) -> Void)?
    var onPortDragEnd: (() -> Void)?
    var onPortTap: ((UUID, String, PortDirection) -> Void)?
    var onPortHover: ((UUID?, String?, Bool) -> Void)?
    var portCompatibility: ((UUID, String, PortDirection) -> Bool)?

    // Connected ports
    var connectedInputPorts: Set<String> = []
    var connectedOutputPorts: Set<String> = []

    // Wiring highlight
    var wiringSourcePortKey: String?

    var onCollapseToggle: (() -> Void)?
    var onWidgetChange: ((String, AnyCodable) -> Void)?

    @State private var hoveredPortKey: String?

    private let portHitSize: CGFloat = 28
    private let portDotSize: CGFloat = 10

    var body: some View {
        let inputPorts = definition?.inputPorts ?? []
        let outputPorts = definition?.outputPorts ?? []
        let titleBarH: CGFloat = 32

        ZStack(alignment: .topLeading) {
            // Card body
            VStack(spacing: 0) {
                titleBar(titleBarH: titleBarH)

                if !node.isCollapsed {
                    Divider().foregroundStyle(colors.border)

                    VStack(spacing: 0) {
                        widgetSection
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: node.size.width, height: node.isCollapsed ? titleBarH : node.size.height)
            .opacity(node.isDisabled ? 0.5 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(isSelected ? PulseColors.accent : colors.border, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? PulseColors.accent.opacity(0.2) : .clear, radius: 8)

            // Input ports on LEFT side
            ForEach(Array(inputPorts.enumerated()), id: \.element.id) { index, port in
                portView(
                    port: port,
                    isConnected: connectedInputPorts.contains(port.key),
                    isHovered: hoveredPortKey == port.key,
                    isWiringSource: wiringSourcePortKey == port.key,
                    isCompatible: portCompatibility?(node.id, port.key, .input) ?? false,
                    yPosition: portY(index: index, count: inputPorts.count, titleH: titleBarH, isCollapsed: node.isCollapsed),
                    xPosition: 0
                )
            }

            // Output ports on RIGHT side
            ForEach(Array(outputPorts.enumerated()), id: \.element.id) { index, port in
                portView(
                    port: port,
                    isConnected: connectedOutputPorts.contains(port.key),
                    isHovered: hoveredPortKey == port.key,
                    isWiringSource: wiringSourcePortKey == port.key,
                    isCompatible: portCompatibility?(node.id, port.key, .output) ?? false,
                    yPosition: portY(index: index, count: outputPorts.count, titleH: titleBarH, isCollapsed: node.isCollapsed),
                    xPosition: node.size.width
                )
            }
        }
    }

    // Port view — the dot + label
    private func portView(port: PortDefinition, isConnected: Bool, isHovered: Bool, isWiringSource: Bool, isCompatible: Bool, yPosition: CGFloat, xPosition: CGFloat) -> some View {
        let isLeft = port.direction == .input
        let dotSize: CGFloat = (isHovered || isWiringSource || isCompatible) ? 14 : (isConnected ? 10 : 8)
        let dotColor = portDotColor(isConnected: isConnected, isHovered: isHovered, isWiringSource: isWiringSource, isCompatible: isCompatible)

        return ZStack {
            // Port dot
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Circle()
                        .stroke(isWiringSource ? PulseColors.accent : colors.background, lineWidth: 2)
                )
                .overlay(
                    // Glow when wiring source
                    Circle()
                        .fill(PulseColors.accent.opacity(0.4))
                        .frame(width: dotSize + 6, height: dotSize + 6)
                        .opacity(isWiringSource ? 1 : 0)
                )
                .overlay(
                    // Red X badge when incompatible target being hovered
                    Group {
                        if !isCompatible && isHovered && wiringSourcePortKey != nil && !isWiringSource {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(PulseColors.danger)
                        }
                    }
                )
                .scaleEffect(isWiringSource ? 1.3 : 1.0)
                .animation(.spring(response: 0.2), value: isHovered)
                .animation(.spring(response: 0.2), value: isWiringSource)
                .position(x: xPosition, y: yPosition)
                .contentShape(Circle().inset(by: -portHitSize/2))
                .onHover { hovering in
                    hoveredPortKey = hovering ? port.key : nil
                    onPortHover?(hovering ? node.id : nil, hovering ? port.key : nil, hovering)
                }

            // Port label (outside the node)
            Text(portLabel(port))
                .font(.system(size: 9))
                .foregroundStyle(isConnected ? colors.textSecondary : colors.textMuted)
                .lineLimit(1)
                .fixedSize()
                .position(
                    x: isLeft ? 4 + 18 : xPosition - 4 - 18,
                    y: yPosition
                )
                .allowsHitTesting(false)
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onEnded { _ in onPortDragEnd?() }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onPortTap?(node.id, port.key, port.direction)
                }
        )
    }

    private func portDotColor(isConnected: Bool, isHovered: Bool, isWiringSource: Bool, isCompatible: Bool) -> Color {
        if isWiringSource { return PulseColors.accent }
        if isHovered && isCompatible { return PulseColors.accent }
        if !isCompatible && isHovered && !isWiringSource { return PulseColors.danger }
        if isHovered { return PulseColors.accent.opacity(0.7) }
        if isConnected { return PulseColors.accent.opacity(0.7) }
        return colors.border.opacity(0.5)
    }

    private func portLabel(_ port: PortDefinition) -> String {
        let req = port.isRequired ? "*" : ""
        return port.direction == .input ? "\(req)\(port.name)" : "\(port.name)"
    }

    private func portY(index: Int, count: Int, titleH: CGFloat, isCollapsed: Bool) -> CGFloat {
        if isCollapsed { return titleH / 2 }
        let bodyH = node.size.height - titleH
        let spacing = bodyH / CGFloat(max(count, 1) + 1)
        return titleH + spacing * CGFloat(index + 1)
    }

    // Title bar
    private func titleBar(titleBarH: CGFloat) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: definition?.icon ?? "circle")
                .font(.system(size: 12))
                .foregroundStyle(definition?.color ?? colors.textSecondary)

            Text(definition?.name ?? node.nodeType)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                onCollapseToggle?()
            } label: {
                Image(systemName: node.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.sm)
        .frame(height: titleBarH)
    }

    // Widget section
    @ViewBuilder
    private var widgetSection: some View {
        if let def = definition, !def.widgetDefinitions.isEmpty {
            VStack(spacing: 6) {
                ForEach(def.widgetDefinitions) { widget in
                    HStack {
                        Text(widget.label)
                            .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                            .frame(width: 50, alignment: .leading)

                        switch widget.widgetType {
                        case .slider:
                            let val = node.widgetValues[widget.key]?.value as? Double ?? widget.min ?? 0
                            let range = (widget.min ?? 0)...(widget.max ?? 1)
                            Slider(value: Binding(get: { val }, set: { onWidgetChange?(widget.key, AnyCodable($0)) }), in: range)
                                .tint(PulseColors.accent)
                            Text(String(format: "%.1f", val)).font(PulseFonts.micro)
                                .foregroundStyle(colors.textSecondary).frame(width: 28, alignment: .trailing)
                        case .dropdown:
                            Text(widget.options?.first ?? "—")
                                .font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, PulseSpacing.sm)
                }
            }
            .padding(.vertical, PulseSpacing.xs)
            Spacer()
        } else {
            Spacer()
        }
    }
}
