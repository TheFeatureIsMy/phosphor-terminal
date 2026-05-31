// StrategyCanvasTab.swift — 策略画布标签
// 浮动面板 + MiniMap + 配置侧边栏

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
    @State private var showPalette = false
    @State private var showConfigPanel = false
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            // === Canvas Area ===
            VStack(spacing: 0) {
                // Mini toolbar
                canvasToolbar

                ZStack {
                    // Background grid
                    CanvasBackground(
                        scale: viewModel.viewport.scale,
                        offset: viewModel.viewport.offset
                    )

                    // Edges
                    CanvasEdges(
                        edges: viewModel.graph.edges,
                        nodes: viewModel.graph.nodes,
                        scale: viewModel.viewport.scale,
                        offset: viewModel.viewport.offset
                    )

                    // Nodes
                    if viewModel.graph.nodes.isEmpty {
                        emptyCanvas
                    } else {
                        nodeLayer
                    }

                    // Wire drag preview
                    wireDragPreviewLayer

                    // Selection rectangle
                    if let selRect = viewModel.selectionRect {
                        CanvasSelectionRect(rect: selRect).allowsHitTesting(false)
                    }

                    // Wire drag overlay
                    if viewModel.wireDragSource != nil {
                        Color.clear.contentShape(Rectangle()).gesture(wireDragGesture)
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
                .onTapGesture(count: 1) { viewModel.deselectAll() }
                .onChange(of: viewModel.selectedNodeIds) { _, newIds in
                    withAnimation(PulseAnimation.easeOutFast) {
                        showConfigPanel = !newIds.isEmpty
                    }
                }
                .onAppear { viewModel.configure(client: client, strategyId: strategy.id) }

                // Bottom status bar
                canvasStatusBar
            }

            // === Floating Palette (left overlay) ===
            if showPalette {
                HStack {
                    NodePalette(
                        isPresented: $showPalette,
                        onNodeSelected: { def in
                            addNodeFromPalette(def)
                            showPalette = false
                        }
                    )
                    .frame(width: 240)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
                .zIndex(10)
            }

            // === MiniMap (bottom-right) ===
            if !viewModel.graph.nodes.isEmpty {
                MiniMapView(
                    nodes: viewModel.graph.nodes,
                    viewport: viewModel.viewport,
                    canvasSize: canvasSize,
                    onPan: { viewModel.viewport.offset = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(PulseSpacing.md)
            }

            // === NodeConfigPanel (right slide-in) ===
            if showConfigPanel, let node = viewModel.selectedNode {
                HStack {
                    Spacer()
                    NodeConfigPanel(
                        node: node,
                        definition: NodeRegistry.definition(for: node.nodeType),
                        onDelete: {
                            viewModel.removeNode(id: node.id)
                            showConfigPanel = false
                        },
                        onConfigChange: { key, value in
                            if let idx = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                                viewModel.graph.nodes[idx].config[key] = value
                            }
                        },
                        onWidgetChange: { key, value in
                            viewModel.updateNodeWidget(nodeId: node.id, key: key, value: value)
                        }
                    )
                    .frame(width: 260)
                    .transition(.move(edge: .trailing))
                }
                .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(
                code: generatedCode,
                onDeploy: { Task { await deployStrategy() } },
                onCancel: {}
            )
        }
    }

    // MARK: - Canvas Toolbar

    private var canvasToolbar: some View {
        HStack(spacing: PulseSpacing.sm) {
            // Palette toggle
            Button {
                withAnimation(PulseAnimation.springDefault) { showPalette.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 11))
                    Text("\u{8282}\u{70B9}").font(PulseFonts.monoLabel)
                }
                .foregroundStyle(showPalette ? PulseColors.accent : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.xs).padding(.vertical, 5)
                .background(showPalette ? PulseColors.accent.opacity(0.1) : colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Spacer()

            // Undo/Redo
            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 12))
            }
            .buttonStyle(.plain).disabled(viewModel.graph.nodes.isEmpty)
            Button { viewModel.redo() } label: {
                Image(systemName: "arrow.uturn.forward").font(.system(size: 12))
            }
            .buttonStyle(.plain).disabled(viewModel.graph.nodes.isEmpty)

            // Fit to content
            Button { viewModel.fitToContent() } label: {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain).disabled(viewModel.graph.nodes.isEmpty)

            Divider().frame(height: 16).foregroundStyle(colors.border)

            // Deploy
            ProofAlphaButton(title: "\u{90E8}\u{7F72}") {
                generatedCode = try! CodeGenerator().generate(from: viewModel.graph, strategyName: strategy.name)
                showCodePreview = true
            }
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, 4)
        .background(colors.surfaceElevated)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.border).frame(height: 0.5)
        }
    }

    // MARK: - Canvas Status Bar

    private var canvasStatusBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text("\u{7F29}\u{653E}: \(String(format: "%.0f%%", viewModel.viewport.scale * 100))")
                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text("\u{8282}\u{70B9}: \(viewModel.graph.nodes.count)")
                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text("\u{8FDE}\u{7EBF}: \(viewModel.graph.edges.count)")
                .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Spacer()
            if let node = viewModel.selectedNode {
                Text(node.nodeType)
                    .font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
            }
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, 3)
        .background(colors.surfaceElevated)
        .overlay(alignment: .top) {
            Rectangle().fill(colors.border).frame(height: 0.5)
        }
    }

    // MARK: - Empty Canvas (actionable)

    private var emptyCanvas: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 40))
                .foregroundStyle(colors.textMuted.opacity(0.5))
            Text("\u{7A7A}\u{767D}\u{753B}\u{5E03}")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textSecondary)
            Text("\u{70B9}\u{51FB}\u{5DE6}\u{4E0A}\u{89D2}\u{300C}\u{8282}\u{70B9}\u{300D}\u{6309}\u{94AE}\u{6253}\u{5F00}\u{9762}\u{677F}\u{FF0C}\u{9009}\u{62E9}\u{8282}\u{70B9}\u{5F00}\u{59CB}\u{6784}\u{5EFA}\u{7B56}\u{7565}")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(PulseAnimation.springDefault) { showPalette = true }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle").font(.system(size: 11))
                    Text("\u{6DFB}\u{52A0}\u{7B2C}\u{4E00}\u{4E2A}\u{8282}\u{70B9}").font(PulseFonts.captionMedium)
                }
                .padding(.horizontal, PulseSpacing.md).padding(.vertical, PulseSpacing.xs)
                .background(PulseColors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(PulseColors.accent.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Add a node from the palette at a reasonable insert position
    private func addNodeFromPalette(_ def: NodeDefinition) {
        let centerX = (-viewModel.viewport.offset.x + 200) / viewModel.viewport.scale
        let centerY = (-viewModel.viewport.offset.y + 200) / viewModel.viewport.scale
        let newNode = CanvasNode(
            nodeType: def.type,
            position: CGPoint(x: centerX + CGFloat.random(in: -40...40), y: centerY + CGFloat.random(in: -40...40)),
            size: CGSize(width: 200, height: 120)
        )
        viewModel.addNode(newNode)
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
            deployResult = "\u{90E8}\u{7F72}\u{6210}\u{529F}"
        } catch {
            deployResult = "\u{90E8}\u{7F72}\u{5931}\u{8D25}: \(error.localizedDescription)"
        }
        showCodePreview = false
    }
}
