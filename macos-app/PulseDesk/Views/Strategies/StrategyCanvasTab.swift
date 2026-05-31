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
    @State private var showPalette = true
    @State private var showConfig = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var searchMatches: [UUID] = []
    @State private var currentSearchIndex = 0

    private let edgeValidator = EdgeValidator()

    private var selectedNode: CanvasNode? {
        guard let id = viewModel.selectedNodeIds.first else { return nil }
        return viewModel.graph.nodes.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showPalette {
                NodePalette(isPresented: $showPalette) { def in addNode(def) }
                    .transition(.move(edge: .leading))
            }

            ZStack {
                CanvasBackground(scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)
                CanvasEdges(edges: viewModel.graph.edges, nodes: viewModel.graph.nodes,
                            selectedEdgeIds: [],
                            scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)

                GeometryReader { geo in
                    let culler = ViewportCuller()
                    let visible = culler.visibleNodes(
                        viewModel.graph.nodes,
                        selectedIds: viewModel.selectedNodeIds,
                        viewport: viewModel.viewport,
                        canvasSize: geo.size
                    )

                    if viewModel.graph.nodes.isEmpty {
                        emptyState
                    } else {
                        ForEach(visible) { node in
                            NodeDragWrapper(viewModel: viewModel, node: node,
                                onWireStart: { nid, port in startWire(nid, port) },
                                onWireEnd: { tid, port in endWire(tid, port) }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let src = viewModel.wireDragSource, let tgt = viewModel.wireDragTarget,
                   let sn = viewModel.graph.nodes.first(where: { $0.id == src.nodeId }),
                   let d = NodeRegistry.definition(for: sn.nodeType) {
                    let pi = d.outputPorts.firstIndex(where: { $0.name == src.port }) ?? 0
                    let py = sn.position.y + 30 + CGFloat(d.inputPorts.count) * 18 + 12 + CGFloat(pi) * 18 + 9
                    CanvasDragPreview(
                        sourcePoint: CGPoint(x: sn.position.x + sn.size.width, y: py), currentPoint: tgt,
                        color: PortDataType.signal.color(colors),
                        scale: viewModel.viewport.scale, offset: viewModel.viewport.offset
                    ).allowsHitTesting(false)
                }

                if let selRect = viewModel.selectionRect {
                    CanvasSelectionRect(rect: selRect).allowsHitTesting(false)
                }

                if viewModel.wireDragSource != nil {
                    Color.clear.contentShape(Rectangle()).gesture(wireDragGesture)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.background)
            .gesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.delete) { deleteSelected(); return .handled }
            .onKeyPress(.escape) { viewModel.deselectAll(); return .handled }
            .onKeyPress(keys: [.init("z")], phases: .down) { press in
                press.modifiers.contains(.shift) ? viewModel.redo() : viewModel.undo()
                return .handled
            }
            .onKeyPress(keys: [.init("f")], phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                withAnimation(.easeInOut(duration: 0.15)) { showSearch = true }
                return .handled
            }
            .onKeyPress(keys: [.init("g")], phases: .down) { press in
                guard press.modifiers.contains(.command) && showSearch else { return .ignored }
                navigateSearch(next: !press.modifiers.contains(.shift))
                return .handled
            }
            .onChange(of: viewModel.selectedNodeIds) { _, ids in
                withAnimation(.easeInOut(duration: 0.15)) { showConfig = !ids.isEmpty }
            }
            .onChange(of: searchText) { _, text in
                if text.isEmpty {
                    searchMatches = []
                    currentSearchIndex = 0
                } else {
                    searchMatches = viewModel.graph.nodes
                        .filter { node in
                            let def = NodeRegistry.definition(for: node.nodeType)
                            let searchable = "\(def?.name ?? "") \(node.nodeType)"
                            return searchable.localizedCaseInsensitiveContains(text)
                        }
                        .map(\.id)
                    currentSearchIndex = 0
                    if let first = searchMatches.first {
                        viewModel.selectNode(id: first)
                    }
                }
            }
            .onAppear { viewModel.configure(client: client, strategyId: strategy.id) }

            if showConfig, let node = selectedNode {
                NodeConfigPanel(
                    node: node,
                    definition: NodeRegistry.definition(for: node.nodeType),
                    onDelete: { viewModel.removeNode(id: node.id); showConfig = false },
                    onConfigChange: { k, v in
                        if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                            viewModel.graph.nodes[i].config[k] = v
                        }
                    },
                    onWidgetChange: { k, v in viewModel.updateNodeWidget(nodeId: node.id, key: k, value: v) }
                )
                .frame(width: 260)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPalette)
        .animation(.easeInOut(duration: 0.2), value: showConfig)
        .overlay(alignment: .topLeading) {
            Button { withAnimation { showPalette.toggle() } } label: {
                Image(systemName: showPalette ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 12)).foregroundStyle(colors.textSecondary)
                    .padding(6).background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated))
            }.buttonStyle(.plain).padding(8)
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
        .overlay(alignment: .top) {
            if showSearch {
                CanvasSearchOverlay(
                    isPresented: $showSearch,
                    searchText: $searchText,
                    matchCount: searchMatches.count,
                    currentMatchIndex: currentSearchIndex,
                    onNavigate: navigateSearch
                )
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(code: generatedCode,
                onDeploy: { Task { await deployStrategy() } }, onCancel: {})
        }
    }

    // MARK: - Actions
    private func addNode(_ def: NodeDefinition) {
        let cx = (-viewModel.viewport.offset.x + 300) / viewModel.viewport.scale
        let cy = (-viewModel.viewport.offset.y + 250) / viewModel.viewport.scale
        viewModel.addNode(CanvasNode(nodeType: def.type,
            position: CGPoint(x: cx + CGFloat.random(in: -30...30), y: cy + CGFloat.random(in: -30...30)),
            size: CGSize(width: 200, height: 120)))
    }

    private func deleteSelected() {
        for id in viewModel.selectedNodeIds { viewModel.removeNode(id: id) }
        showConfig = false
    }

    private func navigateSearch(next: Bool) {
        guard !searchMatches.isEmpty else { return }
        if next { currentSearchIndex = (currentSearchIndex + 1) % searchMatches.count }
        else { currentSearchIndex = (currentSearchIndex - 1 + searchMatches.count) % searchMatches.count }
        let targetId = searchMatches[currentSearchIndex]
        if let node = viewModel.graph.nodes.first(where: { $0.id == targetId }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                let cx = -(node.position.x + node.size.width / 2) * viewModel.viewport.scale + 400
                let cy = -(node.position.y + node.size.height / 2) * viewModel.viewport.scale + 300
                viewModel.viewport.offset = CGPoint(x: cx, y: cy)
            }
        }
    }

    private func startWire(_ nid: UUID, _ port: String) {
        viewModel.startWireDrag(nodeId: nid, port: port)
        if let sn = viewModel.graph.nodes.first(where: { $0.id == nid }),
           let d = NodeRegistry.definition(for: sn.nodeType) {
            let pi = d.outputPorts.firstIndex(where: { $0.name == port }) ?? 0
            let py = sn.position.y + 30 + CGFloat(d.inputPorts.count) * 18 + 12 + CGFloat(pi) * 18 + 9
            viewModel.updateWireDrag(to: CGPoint(x: sn.position.x + sn.size.width, y: py))
        }
    }

    private func endWire(_ tid: UUID, _ port: String) {
        guard let src = viewModel.wireDragSource else { return }

        // Check for cycle
        if edgeValidator.wouldCreateCycle(source: src.nodeId, target: tid, edges: viewModel.graph.edges) {
            viewModel.endWireDrag()
            return
        }

        let dt = NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
            .outputPorts.first(where: { $0.name == src.port })?.dataType ?? .signal
        viewModel.addEdge(CanvasEdge(sourceNodeId: src.nodeId, sourcePort: src.port,
                                     targetNodeId: tid, targetPort: port, dataType: dt))
        viewModel.endWireDrag()
    }

    // MARK: - Gestures
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

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let f = v.magnification / lastMagnification
                lastMagnification = v.magnification; zoomCenter = v.startLocation
                viewModel.zoom(by: f, center: zoomCenter)
            }
            .onEnded { _ in lastMagnification = 1.0 }
    }

    private var wireDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in viewModel.updateWireDrag(to: worldPos(v.location)) }
            .onEnded { v in
                let wp = worldPos(v.location)
                let srcType = viewModel.wireDragSource.flatMap { src in
                    NodeRegistry.definition(for: viewModel.graph.nodes.first(where: { $0.id == src.nodeId })?.nodeType ?? "")?
                        .outputPorts.first(where: { $0.name == src.port })?.dataType
                }
                if let t = nearestPort(to: wp, sourceType: srcType) {
                    endWire(t.nid, t.port)
                } else { viewModel.endWireDrag() }
            }
    }

    private func worldPos(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - viewModel.viewport.offset.x) / viewModel.viewport.scale,
                y: (p.y - viewModel.viewport.offset.y) / viewModel.viewport.scale)
    }

    private func nearestPort(to point: CGPoint, sourceType: PortDataType? = nil) -> (nid: UUID, port: String)? {
        for node in viewModel.graph.nodes {
            guard let def = NodeRegistry.definition(for: node.nodeType) else { continue }
            for (i, port) in def.inputPorts.enumerated() {
                if let srcType = sourceType, !edgeValidator.isTypeCompatible(source: srcType, target: port.dataType) {
                    continue
                }
                let pp = CGPoint(x: node.position.x + 16, y: node.position.y + 30 + CGFloat(i) * 18 + 9)
                if hypot(point.x - pp.x, point.y - pp.y) < 30 { return (node.id, port.name) }
            }
        }
        return nil
    }

    // MARK: - Views
    private var emptyState: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "square.grid.2x2").font(.system(size: 40)).foregroundStyle(colors.textMuted)
            Text("从左侧面板选择节点").font(PulseFonts.body).foregroundStyle(colors.textSecondary)
            if !showPalette { Button("打开面板") { withAnimation { showPalette = true } } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deployStrategy() async {
        isDeploying = true; defer { isDeploying = false }
        await viewModel.saveToBackend()
        _ = try? await APIStrategies(client: client).deploy(id: strategy.id)
        showCodePreview = false
    }
}

// MARK: - NodeDragWrapper (local offset only during drag, commit to model on end)
private struct NodeDragWrapper: View {
    @Environment(PulseColors.self) private var colors
    let viewModel: CanvasViewModel
    let node: CanvasNode
    var onWireStart: (UUID, String) -> Void
    var onWireEnd: (UUID, String) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private var selected: Bool { viewModel.selectedNodeIds.contains(node.id) }

    var body: some View {
        let def = NodeRegistry.definition(for: node.nodeType)
        let bp = screenPosFor(node)

        NodeView(
            node: node, definition: def,
            isSelected: selected, isDragging: isDragging,
            onNodeDragStart: nil,   // replaced by our own gesture below
            onNodeDragUpdate: nil,
            onNodeDragEnd: nil,
            onOutputPortTap: { nid, port in onWireStart(nid, port) },
            onInputPortTap: { tid, port in onWireEnd(tid, port) },
            viewportScale: viewModel.viewport.scale,
            viewportOffset: viewModel.viewport.offset,
            onCollapseToggle: {
                if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                    viewModel.graph.nodes[i].isCollapsed.toggle()
                }
            },
            onWidgetChange: { k, v in viewModel.updateNodeWidget(nodeId: node.id, key: k, value: v) }
        )
        .position(x: bp.x + dragOffset.width, y: bp.y + dragOffset.height)
        .scaleEffect(viewModel.viewport.scale, anchor: .center)
        .zIndex(isDragging || selected ? 10 : 1)
        .shadow(color: (isDragging || selected) ? PulseColors.accent.opacity(0.3) : .black.opacity(0.15),
                radius: isDragging ? 16 : 4, y: isDragging ? 4 : 2)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if !isDragging {
                        isDragging = true
                        viewModel.selectNode(id: node.id)
                    }
                    // Only track visual offset locally — NO model update during drag
                    dragOffset = v.translation
                }
                .onEnded { v in
                    isDragging = false
                    dragOffset = .zero
                    // Commit final position to model once
                    let s = viewModel.viewport.scale
                    let newX = node.position.x + v.translation.width / s
                    let newY = node.position.y + v.translation.height / s
                    viewModel.startDrag(nodeId: node.id, at: node.position)
                    viewModel.updateDrag(to: CGPoint(x: newX, y: newY))
                    viewModel.endDrag()
                }
        )
        .onTapGesture {
            viewModel.selectNode(id: node.id, addToSelection: NSEvent.modifierFlags.contains(.command))
        }
    }

    private func screenPosFor(_ n: CanvasNode) -> CGPoint {
        CGPoint(
            x: n.position.x * viewModel.viewport.scale + viewModel.viewport.offset.x + n.size.width * viewModel.viewport.scale / 2,
            y: n.position.y * viewModel.viewport.scale + viewModel.viewport.offset.y + n.size.height * viewModel.viewport.scale / 2
        )
    }
}
