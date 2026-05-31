// NodeView.swift — 节点渲染（简化端口系统）
// 四边中点各一个端口，点击连接

import SwiftUI

struct NodeView: View {
    @Environment(PulseColors.self) private var colors
    let node: CanvasNode
    let definition: NodeDefinition?
    let isSelected: Bool
    let isDragging: Bool
    /// 四边端口被点击 (nodeId, portSide)
    var onPortTap: ((UUID, PortSide) -> Void)?
    /// 端口悬停
    var onPortHover: ((PortSide?) -> Void)?
    /// 连线到此节点的端口数量（按边统计）
    var connectedSides: Set<PortSide>
    /// 展开/折叠
    var onCollapseToggle: (() -> Void)?
    /// widget 值变更
    var onWidgetChange: ((String, AnyCodable) -> Void)?

    @State private var hoveredSide: PortSide?

    private let portSize: CGFloat = 10
    private let portHitSize: CGFloat = 22

    var body: some View {
        ZStack {
            // 卡片主体
            VStack(spacing: 0) {
                titleBar

                if !node.isCollapsed {
                    Divider().foregroundStyle(colors.border)

                    if let def = definition, !def.widgetDefinitions.isEmpty {
                        widgetBody(def.widgetDefinitions)
                    } else {
                        Spacer().frame(height: 8)
                        Spacer()
                    }
                }
            }
            .frame(width: node.size.width, height: node.isCollapsed ? 36 : node.size.height)
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

            // 四个端口 — 覆盖在边框上
            portCircle(at: .left)
            portCircle(at: .right)
            portCircle(at: .top)
            portCircle(at: .bottom)
        }
    }

    // MARK: - Port circle
    private func portCircle(at side: PortSide) -> some View {
        let pos = portPosition(side)
        let isConnected = connectedSides.contains(side)
        let isHovered = hoveredSide == side

        return Circle()
            .fill(portColor(side: side, isConnected: isConnected, isHovered: isHovered))
            .frame(width: portSize, height: portSize)
            .overlay(Circle().stroke(colors.background, lineWidth: 2))
            .scaleEffect(isHovered ? 1.4 : 1.0)
            .animation(.spring(response: 0.2), value: isHovered)
            .position(pos)
            .contentShape(Circle())
            .onHover { hovering in
                hoveredSide = hovering ? side : nil
                onPortHover?(hovering ? side : nil)
            }
            .onTapGesture {
                onPortTap?(node.id, side)
            }
    }

    private func portPosition(_ side: PortSide) -> CGPoint {
        switch side {
        case .left:  return CGPoint(x: 0, y: node.size.height / 2)
        case .right: return CGPoint(x: node.size.width, y: node.size.height / 2)
        case .top:   return CGPoint(x: node.size.width / 2, y: 0)
        case .bottom: return CGPoint(x: node.size.width / 2, y: node.size.height)
        }
    }

    private func portColor(side: PortSide, isConnected: Bool, isHovered: Bool) -> Color {
        if isHovered { return PulseColors.accent }
        if isConnected { return PulseColors.accent.opacity(0.6) }
        return colors.border
    }

    // MARK: - Title bar
    private var titleBar: some View {
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
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Widget controls
    @ViewBuilder
    private func widgetBody(_ widgets: [WidgetDefinition]) -> some View {
        VStack(spacing: 6) {
            ForEach(widgets) { widget in
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
    }
}
