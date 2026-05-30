// StrategyCanvasTab.swift — 策略画布标签
// 主画布布局：背景网格 → 连线 → 节点 → 交互手势

import SwiftUI

struct StrategyCanvasTab: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy
    let client: NetworkClientProtocol
    @State private var viewModel = CanvasViewModel()
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var zoomCenter: CGPoint = .zero
    @State private var showCodePreview = false
    @State private var generatedCode = ""
    @State private var isDeploying = false
    @State private var deployResult: String?

    var body: some View {
        ZStack {
            // Layer 1: Grid background
            CanvasBackground(
                scale: viewModel.viewport.scale,
                offset: viewModel.viewport.offset
            )

            // Layer 2: Edges
            CanvasEdges(
                edges: viewModel.graph.edges,
                nodes: viewModel.graph.nodes,
                scale: viewModel.viewport.scale,
                offset: viewModel.viewport.offset
            )

            // Layer 3: Nodes
            if viewModel.graph.nodes.isEmpty {
                emptyState
            } else {
                nodeLayer
            }

            // Layer 4: Wire drag preview
            wireDragPreviewLayer

            // Layer 5: Selection rectangle
            if let selRect = viewModel.selectionRect {
                CanvasSelectionRect(rect: selRect)
                    .allowsHitTesting(false)
            }

            // Layer 6: Wire drag interaction overlay
            if viewModel.wireDragSource != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(wireDragGesture)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .gesture(panGesture)
        .gesture(zoomGesture)
        .onKeyPress(keys: [.init("z")], phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                viewModel.redo()
                return .handled
            } else if press.modifiers.contains(.command) {
                viewModel.undo()
                return .handled
            }
            return .ignored
        }
        .onTapGesture(count: 1) {
            viewModel.deselectAll()
        }
        .overlay(alignment: .topTrailing) {
            // Deploy button
            ProofAlphaButton(title: "生成并部署") {
                generatedCode = try! CodeGenerator().generate(from: viewModel.graph, strategyName: strategy.name)
                showCodePreview = true
            }
            .disabled(viewModel.graph.nodes.isEmpty)
            .opacity(viewModel.graph.nodes.isEmpty ? 0.5 : 1.0)
            .padding(PulseSpacing.md)
        }
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(
                code: generatedCode,
                onDeploy: {
                    Task { await deployStrategy() }
                },
                onCancel: {}
            )
        }
        .onAppear {
            viewModel.configure(client: client, strategyId: strategy.id)
        }
    }

    // MARK: - Node layer

    private var nodeLayer: some View {
        ForEach(viewModel.graph.nodes) { node in
            canvasNodeView(for: node)
                .position(nodeScreenPosition(node))
                .scaleEffect(viewModel.viewport.scale, anchor: .center)
        }
    }

    @ViewBuilder
    private func canvasNodeView(for node: CanvasNode) -> some View {
        let definition = NodeRegistry.definition(for: node.nodeType)
        let selected = viewModel.selectedNodeIds.contains(node.id)
        let dragging = viewModel.draggingNodeId == node.id

        NodeView(
            node: node,
            definition: definition,
            isSelected: selected,
            isDragging: dragging,
            onNodeDragStart: { worldPos in viewModel.startDrag(nodeId: node.id, at: worldPos) },
            onNodeDragUpdate: { worldPos in viewModel.updateDrag(to: worldPos) },
            onNodeDragEnd: { viewModel.endDrag() },
            onOutputPortTap: { nodeId, portName in handleOutputPortTap(nodeId: nodeId, portName: portName) },
            onInputPortTap: { targetNodeId, targetPortName in completeWireDrag(targetNodeId: targetNodeId, targetPortName: targetPortName) },
            viewportScale: viewModel.viewport.scale,
            viewportOffset: viewModel.viewport.offset,
            onCollapseToggle: { toggleCollapse(nodeId: node.id) },
            onWidgetChange: { key, value in viewModel.updateNodeWidget(nodeId: node.id, key: key, value: value) }
        )
    }

    /// Compute screen position for a node (world -> screen)
    private func nodeScreenPosition(_ node: CanvasNode) -> CGPoint {
        CGPoint(
            x: node.position.x * viewModel.viewport.scale + viewModel.viewport.offset.x + node.size.width * viewModel.viewport.scale / 2,
            y: node.position.y * viewModel.viewport.scale + viewModel.viewport.offset.y + node.size.height * viewModel.viewport.scale / 2
        )
    }

    // MARK: - Wire drag preview layer

    @ViewBuilder
    private var wireDragPreviewLayer: some View {
        if let source = viewModel.wireDragSource,
           let target = viewModel.wireDragTarget,
           let sourceNode = viewModel.graph.nodes.first(where: { $0.id == source.nodeId }),
           let definition = NodeRegistry.definition(for: sourceNode.nodeType) {
            let portIndex = definition.outputPorts.firstIndex(where: { $0.name == source.port }) ?? 0
            let portY = sourceNode.position.y + 30 + CGFloat(definition.inputPorts.count) * 18 + 12 + CGFloat(portIndex) * 18 + 9
            let sourceWorld = CGPoint(
                x: sourceNode.position.x + sourceNode.size.width,
                y: portY
            )
            CanvasDragPreview(
                sourcePoint: sourceWorld,
                currentPoint: target,
                color: PortDataType.signal.color(colors),
                scale: viewModel.viewport.scale,
                offset: viewModel.viewport.offset
            )
            .allowsHitTesting(false)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 48))
                .foregroundStyle(colors.textMuted)
            Text("拖拽节点到画布开始构建策略")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
            Text("从左侧面板选择节点类型")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - Pan gesture (canvas panning)

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Skip pan when dragging a node
                guard viewModel.draggingNodeId == nil else { return }

                let delta = CGSize(
                    width: value.translation.width - lastPanTranslation.width,
                    height: value.translation.height - lastPanTranslation.height
                )
                lastPanTranslation = value.translation
                viewModel.pan(by: CGPoint(x: delta.width, y: delta.height))
            }
            .onEnded { _ in
                lastPanTranslation = .zero
            }
    }

    // MARK: - Zoom gesture

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = value.magnification / lastMagnification
                lastMagnification = value.magnification
                zoomCenter = value.startLocation
                viewModel.zoom(by: factor, center: zoomCenter)
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    // MARK: - Wire drag gesture (overlay captures mouse movement during wire drag)

    private var wireDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let worldPos = screenToWorld(value.location)
                viewModel.updateWireDrag(to: worldPos)
            }
            .onEnded { value in
                let worldPos = screenToWorld(value.location)
                if let target = findNearestInputPort(near: worldPos) {
                    completeWireDrag(targetNodeId: target.nodeId, targetPortName: target.portName)
                } else {
                    viewModel.endWireDrag()
                }
            }
    }

    // MARK: - Helpers

    /// Convert screen coordinates to world coordinates
    private func screenToWorld(_ screen: CGPoint) -> CGPoint {
        CGPoint(
            x: (screen.x - viewModel.viewport.offset.x) / viewModel.viewport.scale,
            y: (screen.y - viewModel.viewport.offset.y) / viewModel.viewport.scale
        )
    }

    /// Handle tapping an output port to start a wire drag
    private func handleOutputPortTap(nodeId: UUID, portName: String) {
        guard viewModel.wireDragSource == nil else { return }
        viewModel.startWireDrag(nodeId: nodeId, port: portName)
        // Set initial wire drag target to the source port position
        if let sourceNode = viewModel.graph.nodes.first(where: { $0.id == nodeId }),
           let definition = NodeRegistry.definition(for: sourceNode.nodeType) {
            let portIndex = definition.outputPorts.firstIndex(where: { $0.name == portName }) ?? 0
            let portY = sourceNode.position.y + 30 + CGFloat(definition.inputPorts.count) * 18 + 12 + CGFloat(portIndex) * 18 + 9
            let startPos = CGPoint(
                x: sourceNode.position.x + sourceNode.size.width,
                y: portY
            )
            viewModel.updateWireDrag(to: startPos)
        }
    }

    /// Toggle collapse state of a node
    private func toggleCollapse(nodeId: UUID) {
        guard let idx = viewModel.graph.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        viewModel.graph.nodes[idx].isCollapsed.toggle()
    }

    /// Find the nearest input port within snapping distance of a world point
    private func findNearestInputPort(near point: CGPoint) -> (nodeId: UUID, portName: String)? {
        let snapDistance: CGFloat = 20.0
        var bestMatch: (nodeId: UUID, portName: String, distance: CGFloat)?

        for node in viewModel.graph.nodes {
            guard let def = NodeRegistry.definition(for: node.nodeType) else { continue }
            for (index, port) in def.inputPorts.enumerated() {
                let portWorldPos = CGPoint(
                    x: node.position.x + PulseSpacing.sm + 5,
                    y: node.position.y + 30 + CGFloat(index) * 18 + 9
                )
                let dist = hypot(point.x - portWorldPos.x, point.y - portWorldPos.y)
                if dist < snapDistance {
                    if bestMatch == nil || dist < bestMatch!.distance {
                        bestMatch = (nodeId: node.id, portName: port.name, distance: dist)
                    }
                }
            }
        }
        return bestMatch.map { (nodeId: $0.nodeId, portName: $0.portName) }
    }

    /// Complete a wire drag by creating an edge from source to target port
    private func completeWireDrag(targetNodeId: UUID, targetPortName: String) {
        guard let source = viewModel.wireDragSource else {
            viewModel.endWireDrag()
            return
        }
        guard source.nodeId != targetNodeId else {
            viewModel.endWireDrag()
            return
        }
        let sourceType = viewModel.graph.nodes.first(where: { $0.id == source.nodeId })?.nodeType ?? ""
        let dataType: PortDataType = {
            guard let def = NodeRegistry.definition(for: sourceType) else { return .signal }
            return def.outputPorts.first(where: { $0.name == source.port })?.dataType ?? .signal
        }()

        let edge = CanvasEdge(
            sourceNodeId: source.nodeId,
            sourcePort: source.port,
            targetNodeId: targetNodeId,
            targetPort: targetPortName,
            dataType: dataType
        )
        viewModel.addEdge(edge)
        viewModel.endWireDrag()
    }

    /// Deploy the strategy via API
    private func deployStrategy() async {
        isDeploying = true
        defer { isDeploying = false }
        do {
            // Save canvas first
            await viewModel.saveToBackend()
            // Deploy the strategy
            let strategies = APIStrategies(client: client)
            let _ = try await strategies.deploy(id: strategy.id)
            deployResult = "部署成功"
        } catch {
            deployResult = "部署失败: \(error.localizedDescription)"
        }
        showCodePreview = false
    }
}
