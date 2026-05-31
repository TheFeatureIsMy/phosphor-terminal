// StrategyCanvasTab.swift — 策略画布标签
// 左侧节点面板 + 中间画布 + 右侧配置面板

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

    // UI state
    @State private var showPalette = true
    @State private var showConfig = false

    private var selectedNode: CanvasNode? {
        guard let id = viewModel.selectedNodeIds.first else { return nil }
        return viewModel.graph.nodes.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Node Palette
            if showPalette {
                NodePalette(isPresented: $showPalette) { def in
                    addNode(def)
                }
                .transition(.move(edge: .leading))
            }

            // Center: Canvas
            ZStack {
                CanvasBackground(scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)
                CanvasEdges(edges: viewModel.graph.edges, nodes: viewModel.graph.nodes,
                            scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)

                if viewModel.graph.nodes.isEmpty { emptyState }
                else { ForEach(viewModel.graph.nodes) { node in nodeView(for: node) } }

                wireDragPreviewLayer

                if let selRect = viewModel.selectionRect {
                    CanvasSelectionRect(rect: selRect).allowsHitTesting(false)
                }

                if viewModel.wireDragSource != nil {
                    Color.clear.contentShape(Rectangle()).gesture(wireDragGesture)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.background)
            .simultaneousGesture(viewModel.draggingNodeId == nil ? panGesture : nil)
            .simultaneousGesture(zoomGesture)
            .onTapGesture(count: 1) { viewModel.deselectAll() }
            .onKeyPress(.delete) {
                deleteSelected()
                return .handled
            }
            .onKeyPress(.escape) {
                viewModel.deselectAll()
                return .handled
            }
            .onKeyPress(keys: [.init("z")], phases: .down) { press in
                press.modifiers.contains(.shift) ? viewModel.redo() : viewModel.undo()
                return .handled
            }
            .onChange(of: viewModel.selectedNodeIds) { _, ids in
                withAnimation(.easeInOut(duration: 0.15)) { showConfig = !ids.isEmpty }
            }
            .onAppear { viewModel.configure(client: client, strategyId: strategy.id) }

            // Right: Node Config Panel
            if showConfig, let node = selectedNode {
                NodeConfigPanel(
                    node: node,
                    definition: NodeRegistry.definition(for: node.nodeType),
                    onDelete: {
                        viewModel.removeNode(id: node.id)
                        showConfig = false
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
        }
        .animation(.easeInOut(duration: 0.2), value: showPalette)
        .animation(.easeInOut(duration: 0.2), value: showConfig)
        .overlay(alignment: .topLeading) {
            // Palette toggle
            Button {
                withAnimation { showPalette.toggle() }
            } label: {
                Image(systemName: showPalette ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textSecondary)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            ProofAlphaButton(title: "生成并部署") {
                generatedCode = (try? CodeGenerator().generate(from: viewModel.graph, strategyName: strategy.name)) ?? ""
                showCodePreview = true
            }
            .disabled(viewModel.graph.nodes.isEmpty)
            .opacity(viewModel.graph.nodes.isEmpty ? 0.5 : 1)
            .padding(8)
        }
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(code: generatedCode,
                onDeploy: { Task { await deployStrategy() } },
                onCancel: {})
        }
    }

    // MARK: - Add node from palette
    private func addNode(_ def: NodeDefinition) {
        let cx = (-viewModel.viewport.offset.x + 300) / viewModel.viewport.scale
        let cy = (-viewModel.viewport.offset.y + 250) / viewModel.viewport.scale
        viewModel.addNode(CanvasNode(
            nodeType: def.type,
            position: CGPoint(x: cx + CGFloat.random(in: -30...30), y: cy + CGFloat.random(in: -30...30)),
            size: CGSize(width: 200, height: 120)
        ))
    }

    // MARK: - Delete selected
    private func deleteSelected() {
        for id in viewModel.selectedNodeIds {
            viewModel.removeNode(id: id)
        }
        showConfig = false
    }

    // MARK: - Node view with gestures
    private func nodeView(for node: CanvasNode) -> some View {
        let def = NodeRegistry.definition(for: node.nodeType)
        let selected = viewModel.selectedNodeIds.contains(node.id)

        return NodeView(
            node: node, definition: def,
            isSelected: selected, isDragging: viewModel.draggingNodeId == node.id,
            onNodeDragStart: { viewModel.startDrag(nodeId: node.id, at: $0) },
            onNodeDragUpdate: { viewModel.updateDrag(to: $0) },
            onNodeDragEnd: { viewModel.endDrag() },
            onOutputPortTap: { nid, port in
                viewModel.startWireDrag(nodeId: nid, port: port)
                if let sourceNode = viewModel.graph.nodes.first(where: { $0.id == nid }),
                   let d = NodeRegistry.definition(for: sourceNode.nodeType) {
                    let pi = d.outputPorts.firstIndex(where: { $0.name == port }) ?? 0
                    let py = sourceNode.position.y + 30 + CGFloat(d.inputPorts.count) * 18 + 12 + CGFloat(pi) * 18 + 9
                    viewModel.updateWireDrag(to: CGPoint(x: sourceNode.position.x + sourceNode.size.width, y: py))
                }
            },
            onInputPortTap: { tid, port in
                if let src = viewModel.wireDragSource {
                    let dataType = NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
                        .outputPorts.first(where: { $0.name == src.port })?.dataType ?? .signal
                    viewModel.addEdge(CanvasEdge(sourceNodeId: src.nodeId, sourcePort: src.port,
                                                 targetNodeId: tid, targetPort: port, dataType: dataType))
                    viewModel.endWireDrag()
                }
            },
            viewportScale: viewModel.viewport.scale,
            viewportOffset: viewModel.viewport.offset,
            onCollapseToggle: {
                if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                    viewModel.graph.nodes[i].isCollapsed.toggle()
                }
            },
            onWidgetChange: { key, value in viewModel.updateNodeWidget(nodeId: node.id, key: key, value: value) }
        )
        .position(screenPos(node))
        .scaleEffect(viewModel.viewport.scale, anchor: .center)
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.selectNode(id: node.id, addToSelection: NSEvent.modifierFlags.contains(.command))
        })
    }

    private func screenPos(_ node: CanvasNode) -> CGPoint {
        CGPoint(
            x: node.position.x * viewModel.viewport.scale + viewModel.viewport.offset.x + node.size.width * viewModel.viewport.scale / 2,
            y: node.position.y * viewModel.viewport.scale + viewModel.viewport.offset.y + node.size.height * viewModel.viewport.scale / 2
        )
    }

    // MARK: - Wire drag preview
    @ViewBuilder
    private var wireDragPreviewLayer: some View {
        if let src = viewModel.wireDragSource,
           let tgt = viewModel.wireDragTarget,
           let srcNode = viewModel.graph.nodes.first(where: { $0.id == src.nodeId }),
           let def = NodeRegistry.definition(for: srcNode.nodeType) {
            let pi = def.outputPorts.firstIndex(where: { $0.name == src.port }) ?? 0
            let py = srcNode.position.y + 30 + CGFloat(def.inputPorts.count) * 18 + 12 + CGFloat(pi) * 18 + 9
            CanvasDragPreview(
                sourcePoint: CGPoint(x: srcNode.position.x + srcNode.size.width, y: py),
                currentPoint: tgt,
                color: PortDataType.signal.color(colors),
                scale: viewModel.viewport.scale,
                offset: viewModel.viewport.offset
            ).allowsHitTesting(false)
        }
    }

    // MARK: - Pan gesture (space not required — uses DragGesture on canvas background)
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                guard viewModel.draggingNodeId == nil else { return }
                let dx = v.translation.width - lastPanTranslation.width
                let dy = v.translation.height - lastPanTranslation.height
                lastPanTranslation = v.translation
                viewModel.pan(by: CGPoint(x: dx, y: dy))
            }
            .onEnded { _ in lastPanTranslation = .zero }
    }

    // MARK: - Zoom gesture
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let f = v.magnification / lastMagnification
                lastMagnification = v.magnification
                zoomCenter = v.startLocation
                viewModel.zoom(by: f, center: zoomCenter)
            }
            .onEnded { _ in lastMagnification = 1.0 }
    }

    // MARK: - Wire drag gesture
    private var wireDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let wp = screenToWorld(v.location)
                viewModel.updateWireDrag(to: wp)
            }
            .onEnded { v in
                let wp = screenToWorld(v.location)
                if let target = nearestInputPort(to: wp) {
                    let src = viewModel.wireDragSource!
                    let dataType = NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
                        .outputPorts.first(where: { $0.name == src.port })?.dataType ?? .signal
                    viewModel.addEdge(CanvasEdge(sourceNodeId: src.nodeId, sourcePort: src.port,
                                                 targetNodeId: target.nid, targetPort: target.port, dataType: dataType))
                }
                viewModel.endWireDrag()
            }
    }

    private func screenToWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - viewModel.viewport.offset.x) / viewModel.viewport.scale,
                y: (p.y - viewModel.viewport.offset.y) / viewModel.viewport.scale)
    }

    private func nearestInputPort(to point: CGPoint) -> (nid: UUID, port: String)? {
        for node in viewModel.graph.nodes {
            guard let def = NodeRegistry.definition(for: node.nodeType) else { continue }
            for (i, port) in def.inputPorts.enumerated() {
                let pp = CGPoint(x: node.position.x + 16, y: node.position.y + 30 + CGFloat(i) * 18 + 9)
                if hypot(point.x - pp.x, point.y - pp.y) < 30 {
                    return (node.id, port.name)
                }
            }
        }
        return nil
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "square.grid.2x2").font(.system(size: 40)).foregroundStyle(colors.textMuted)
            Text("从左侧面板选择节点").font(PulseFonts.body).foregroundStyle(colors.textSecondary)
            if !showPalette {
                Button("打开节点面板") { withAnimation { showPalette = true } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Deploy
    private func deployStrategy() async {
        isDeploying = true; defer { isDeploying = false }
        await viewModel.saveToBackend()
        _ = try? await APIStrategies(client: client).deploy(id: strategy.id)
        showCodePreview = false
    }
}
