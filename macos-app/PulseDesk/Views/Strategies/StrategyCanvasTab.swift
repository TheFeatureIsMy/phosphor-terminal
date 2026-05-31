// StrategyCanvasTab.swift — 策略画布 (Dify/ComfyUI-inspired)
// 双击搜索节点 · 右键菜单 · 拖拽连线 · 浮动面板 · 自动保存

import SwiftUI

// MARK: - Right-click handler via NSView
struct CanvasRightClickHandler: NSViewRepresentable {
    var onRightClick: (NSPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = _RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? _RightClickNSView)?.onRightClick = onRightClick
    }
}

private class _RightClickNSView: NSView {
    var onRightClick: ((NSPoint) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onRightClick?(point)
    }
}

// MARK: - Quick-Add Node Search Overlay (ComfyUI double-click pattern)
struct QuickNodeSearch: View {
    @Environment(PulseColors.self) private var colors
    @Binding var isPresented: Bool
    var onSelect: (NodeDefinition) -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    private var filteredNodes: [NodeDefinition] {
        if searchText.isEmpty { return NodeRegistry.allDefinitions }
        return NodeRegistry.allDefinitions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(PulseColors.accent)
                TextField("搜索节点类型...", text: $searchText)
                    .textFieldStyle(.plain).font(PulseFonts.body)
                    .focused($isFocused)
            }
            .padding(PulseSpacing.md)
            .background(colors.surfaceElevated)

            Divider().foregroundStyle(colors.border)

            // Results
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(Array(filteredNodes.enumerated()), id: \.element.id) { index, def in
                        Button {
                            onSelect(def)
                            isPresented = false
                        } label: {
                            HStack(spacing: PulseSpacing.sm) {
                                Image(systemName: def.icon).font(.system(size: 13))
                                    .foregroundStyle(def.color).frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(def.name).font(PulseFonts.body).foregroundStyle(colors.textPrimary)
                                    Text(def.type).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                                }
                                Spacer()
                                Text(def.category.label).font(PulseFonts.micro)
                                    .foregroundStyle(def.category.color)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(def.category.color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .padding(.horizontal, PulseSpacing.sm).padding(.vertical, PulseSpacing.xs)
                            .background(index == selectedIndex ? PulseColors.accent.opacity(0.08) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 300)
        }
        .frame(width: 420)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.lg).stroke(PulseGlass.accentBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20)
        .onAppear { isFocused = true; selectedIndex = 0 }
        .onKeyPress(keys: [.upArrow], phases: .down) { _ in selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(keys: [.downArrow], phases: .down) { _ in selectedIndex = min(filteredNodes.count - 1, selectedIndex + 1); return .handled }
        .onKeyPress(keys: [.return], phases: .down) { _ in
            if let def = filteredNodes[safe: selectedIndex] { onSelect(def); isPresented = false }
            return .handled
        }
        .onKeyPress(keys: [.escape], phases: .down) { _ in isPresented = false; return .handled }
    }
}

// MARK: - Snap-to-grid helper
private let SNAP_GRID: CGFloat = 20

func snapToGrid(_ value: CGFloat) -> CGFloat {
    round(value / SNAP_GRID) * SNAP_GRID
}

func snapPointToGrid(_ point: CGPoint) -> CGPoint {
    CGPoint(x: snapToGrid(point.x), y: snapToGrid(point.y))
}

// MARK: - Main Canvas Tab
struct StrategyCanvasTab: View {
    @Environment(PulseColors.self) private var colors
    let strategy: Strategy
    let client: NetworkClientProtocol

    @State private var viewModel = CanvasViewModel()

    // Viewport gestures
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var zoomCenter: CGPoint = .zero

    // UI state
    @State private var showPalette = false
    @State private var showQuickSearch = false
    @State private var showConfigPanel = false
    @State private var showCodePreview = false
    @State private var generatedCode = ""
    @State private var isDeploying = false
    @State private var saveStatus: SaveStatus = .saved
    @State private var canvasSize: CGSize = .zero

    enum SaveStatus { case saved, saving, unsaved }

    // Context menu
    @State private var contextMenuNodeId: UUID?
    @State private var showContextMenu = false
    @State private var contextMenuPosition: CGPoint = .zero

    // Clipboard for copy/paste
    @State private var clipboard: [CanvasNode] = []

    var body: some View {
        ZStack {
            // === Main Canvas ===
            VStack(spacing: 0) {
                canvasToolbar

                ZStack {
                    CanvasBackground(scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)

                    CanvasEdges(
                        edges: viewModel.graph.edges,
                        nodes: viewModel.graph.nodes,
                        scale: viewModel.viewport.scale,
                        offset: viewModel.viewport.offset
                    )

                    if viewModel.graph.nodes.isEmpty {
                        emptyCanvas
                    } else {
                        nodeLayer
                        groupBoxesLayer
                    }

                    wireDragPreviewLayer

                    if let selRect = viewModel.selectionRect {
                        CanvasSelectionRect(rect: selRect).allowsHitTesting(false)
                    }

                    if viewModel.wireDragSource != nil {
                        Color.clear.contentShape(Rectangle()).gesture(wireDragGesture)
                    }

                    // Track canvas size for MiniMap
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { canvasSize = geo.size }
                                    .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.background)
                // Double-click empty space → quick search (ComfyUI hallmark)
                .onTapGesture(count: 2) { location in
                    // Only trigger if we didn't click on a node
                    if viewModel.selectedNodeIds.isEmpty {
                        showQuickSearch = true
                    }
                }
                .gesture(panGesture)
                .gesture(zoomGesture)

                canvasStatusBar
            }

            // === Quick Search overlay (centered) ===
            if showQuickSearch {
                ZStack {
                    colors.background.opacity(0.6).ignoresSafeArea()
                        .onTapGesture { showQuickSearch = false }
                    QuickNodeSearch(isPresented: $showQuickSearch) { def in
                        addNodeAtCenter(def)
                    }
                }
                .zIndex(20)
            }

            // === Floating Node Palette (left overlay) ===
            if showPalette {
                HStack {
                    NodePalette(isPresented: $showPalette) { def in
                        addNodeAtCenter(def)
                        showPalette = false
                    }
                    .frame(width: 240)
                    .transition(.move(edge: .leading))
                    Spacer()
                }
                .zIndex(10)
            }

            // === Node Config Panel (right slide-in) ===
            if showConfigPanel, let node = viewModel.selectedNode {
                HStack {
                    Spacer()
                    NodeConfigPanel(
                        node: node,
                        definition: NodeRegistry.definition(for: node.nodeType),
                        onDelete: {
                            viewModel.removeNode(id: node.id)
                            showConfigPanel = false
                            markUnsaved()
                        },
                        onConfigChange: { key, value in
                            if let idx = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                                viewModel.graph.nodes[idx].config[key] = value
                                markUnsaved()
                            }
                        },
                        onWidgetChange: { key, value in
                            viewModel.updateNodeWidget(nodeId: node.id, key: key, value: value)
                            markUnsaved()
                        }
                    )
                    .frame(width: 260)
                    .transition(.move(edge: .trailing))
                }
                .zIndex(10)
            }

            // === MiniMap ===
            if !viewModel.graph.nodes.isEmpty {
                MiniMapView(
                    nodes: viewModel.graph.nodes,
                    viewport: viewModel.viewport,
                    canvasSize: canvasSize,
                    onPan: { viewModel.viewport.offset = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(PulseSpacing.md)
                .opacity(0.8)
            }

            // === Right-Click Handler (invisible overlay on canvas) ===
            CanvasRightClickHandler { screenPoint in
                handleRightClick(at: screenPoint)
            }
            .allowsHitTesting(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)

            // === Context Menu (overlay) ===
            if showContextMenu, let nodeId = contextMenuNodeId, let node = viewModel.graph.nodes.first(where: { $0.id == nodeId }) {
                Color.clear.ignoresSafeArea().contentShape(Rectangle())
                    .onTapGesture { showContextMenu = false }
                    .overlay(alignment: .topLeading) {
                        contextMenuOverlay(for: node)
                            .position(contextMenuPosition)
                    }
                    .zIndex(30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keyboard shortcuts
        .onKeyPress(keys: [.init("c")], phases: .down) { press in
            if press.modifiers.contains(.command) { copySelected(); return .handled }
            return .ignored
        }
        .onKeyPress(keys: [.init("v")], phases: .down) { press in
            if press.modifiers.contains(.command) { pasteNodes(); return .handled }
            return .ignored
        }
        .onKeyPress(keys: [.init("a")], phases: .down) { press in
            if press.modifiers.contains(.command) { viewModel.selectAll(); return .handled }
            return .ignored
        }
        .onKeyPress(keys: [.init("d")], phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.option) {
                if let node = viewModel.selectedNode { duplicateNode(node); return .handled }
            }
            return .ignored
        }
        .onKeyPress(keys: [.init("g")], phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.option) {
                groupSelected(); return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.delete], phases: .down) { _ in deleteSelected(); return .handled }
        .onChange(of: viewModel.selectedNodeIds) { _, newIds in
            withAnimation(PulseAnimation.springDefault) { showConfigPanel = !newIds.isEmpty }
        }
        .sheet(isPresented: $showCodePreview) {
            CodePreviewSheet(
                code: generatedCode,
                onDeploy: { Task { await deployStrategy() } },
                onCancel: {}
            )
        }
        .onAppear { viewModel.configure(client: client, strategyId: strategy.id) }
        .onDisappear {
            Task { await viewModel.saveToBackend() }
        }
    }

    // MARK: - Right-click handling

    private func handleRightClick(at screenPoint: NSPoint) {
        let worldPoint = screenToWorld(CGPoint(x: screenPoint.x, y: screenPoint.y))
        // Find node nearest to the click point
        let hitNodes = viewModel.graph.nodes.filter { node in
            let nodeRect = CGRect(
                origin: node.position,
                size: node.size
            ).insetBy(dx: -10, dy: -10)
            return nodeRect.contains(worldPoint)
        }
        if let hitNode = hitNodes.first {
            contextMenuNodeId = hitNode.id
            contextMenuPosition = nodeScreenPosition(hitNode)
            showContextMenu = true
        }
    }

    // MARK: - Toolbar

    private var canvasToolbar: some View {
        HStack(spacing: PulseSpacing.sm) {
            Button { withAnimation { showPalette.toggle() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 11))
                    Text("节点").font(PulseFonts.monoLabel)
                }
                .foregroundStyle(showPalette ? PulseColors.accent : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.xs).padding(.vertical, 5)
                .background(showPalette ? PulseColors.accent.opacity(0.1) : colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("节点面板 (双击画布快速搜索)")

            Spacer()

            // Undo/Redo
            Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward").font(.system(size: 12)) }
                .buttonStyle(.plain).disabled(!viewModel.canUndo).help("撤销 ⌘Z")
            Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward").font(.system(size: 12)) }
                .buttonStyle(.plain).disabled(!viewModel.canRedo).help("重做 ⇧⌘Z")

            Divider().frame(height: 16)

            // Zoom controls
            Button { viewModel.zoom(by: 0.8, center: .zero) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 12)) }
                .buttonStyle(.plain).help("缩小")
            Text("\(String(format: "%.0f", viewModel.viewport.scale * 100))%")
                .font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted).frame(width: 36)
            Button { viewModel.zoom(by: 1.25, center: .zero) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 12)) }
                .buttonStyle(.plain).help("放大")
            Button { viewModel.fitToContent() } label: { Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left").font(.system(size: 10)) }
                .buttonStyle(.plain).disabled(viewModel.graph.nodes.isEmpty).help("适应内容")

            Divider().frame(height: 16)

            // Save status indicator
            HStack(spacing: 4) {
                Circle().frame(width: 5, height: 5)
                    .foregroundStyle(saveStatus == .saved ? PulseColors.success : saveStatus == .saving ? PulseColors.warning : PulseColors.amber)
                Text(saveStatus == .saved ? "已保存" : saveStatus == .saving ? "保存中..." : "未保存")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }

            ProofAlphaButton(title: "部署") {
                do {
                    generatedCode = try CodeGenerator().generate(from: viewModel.graph, strategyName: strategy.name)
                    showCodePreview = true
                } catch {
                    // On validation failure, leave generatedCode empty and show preview anyway
                    generatedCode = "// 错误: \(error.localizedDescription)"
                    showCodePreview = true
                }
            }
        }
        .padding(.horizontal, PulseSpacing.sm).padding(.vertical, 4)
        .background(colors.surfaceElevated)
        .overlay(alignment: .bottom) { Rectangle().fill(colors.border).frame(height: 0.5) }
    }

    // MARK: - Status Bar

    private var canvasStatusBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text("节点 \(viewModel.graph.nodes.count)").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text("连线 \(viewModel.graph.edges.count)").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            if !viewModel.selectedNodeIds.isEmpty {
                Text("已选 \(viewModel.selectedNodeIds.count)").font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
            }
            Spacer()
            if let node = viewModel.selectedNode {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: NodeRegistry.definition(for: node.nodeType)?.icon ?? "circle").font(.system(size: 9))
                    Text(node.nodeType).font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
                }
            }
        }
        .padding(.horizontal, PulseSpacing.sm).padding(.vertical, 3)
        .background(colors.surfaceElevated)
        .overlay(alignment: .top) { Rectangle().fill(colors.border).frame(height: 0.5) }
    }

    // MARK: - Empty Canvas

    private var emptyCanvas: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "square.grid.2x2").font(.system(size: 40)).foregroundStyle(colors.textMuted.opacity(0.4))
            Text("空白画布").font(PulseFonts.displaySubheading).foregroundStyle(colors.textSecondary)
            Text("双击画布搜索节点，或点击左上角「节点」按钮打开面板")
                .font(PulseFonts.caption).foregroundStyle(colors.textMuted).multilineTextAlignment(.center)
            Button {
                withAnimation { showQuickSearch = true }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.magnifyingglass").font(.system(size: 12))
                    Text("添加第一个节点").font(PulseFonts.captionMedium)
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

    // MARK: - Context Menu

    private func contextMenuOverlay(for node: CanvasNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            contextMenuItem("复制", icon: "doc.on.doc", shortcut: "⌘C") { copySelected() }
            contextMenuItem("复制并粘贴", icon: "doc.on.doc.fill", shortcut: "⌘⌥D") { duplicateNode(node) }
            Divider().foregroundStyle(colors.border)
            contextMenuItem(node.isCollapsed ? "展开" : "折叠", icon: node.isCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", shortcut: "") {
                toggleCollapse(nodeId: node.id)
            }
            contextMenuItem(node.isDisabled ? "启用" : "禁用", icon: node.isDisabled ? "circle" : "circle.slash", shortcut: "") {
                toggleDisable(nodeId: node.id)
            }
            Divider().foregroundStyle(colors.border)
            contextMenuItem("删除", icon: "trash", shortcut: "⌫", isDestructive: true) {
                viewModel.removeNode(id: node.id)
                showConfigPanel = false
                markUnsaved()
            }
        }
        .frame(width: 200)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8)
    }

    private func contextMenuItem(_ title: String, icon: String, shortcut: String = "", isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            showContextMenu = false
        }) {
            HStack {
                Image(systemName: icon).font(.system(size: 11)).frame(width: 18)
                    .foregroundStyle(isDestructive ? PulseColors.danger : colors.textSecondary)
                Text(title).font(PulseFonts.caption).foregroundStyle(isDestructive ? PulseColors.danger : colors.textSecondary)
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                }
            }
            .padding(.horizontal, PulseSpacing.sm).padding(.vertical, PulseSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addNodeAtCenter(_ def: NodeDefinition) {
        let centerX = (-viewModel.viewport.offset.x + 300) / viewModel.viewport.scale
        let centerY = (-viewModel.viewport.offset.y + 200) / viewModel.viewport.scale
        let pos = snapPointToGrid(CGPoint(x: centerX + CGFloat.random(in: -20...20), y: centerY + CGFloat.random(in: -20...20)))
        let newNode = CanvasNode(nodeType: def.type, position: pos, size: CGSize(width: 200, height: 120))
        viewModel.addNode(newNode)
        markUnsaved()
    }

    private func deleteSelected() {
        let ids = viewModel.selectedNodeIds
        for id in ids {
            viewModel.removeNode(id: id)
        }
        markUnsaved()
    }

    private func copySelected() {
        guard !viewModel.selectedNodeIds.isEmpty else { return }
        clipboard = viewModel.graph.nodes.filter { viewModel.selectedNodeIds.contains($0.id) }
    }

    private func pasteNodes() {
        guard !clipboard.isEmpty else { return }
        let offsetX: CGFloat = 40
        let offsetY: CGFloat = 40
        for node in clipboard {
            var copy = node
            copy.id = UUID()
            copy.position.x += offsetX
            copy.position.y += offsetY
            viewModel.addNode(copy)
        }
        markUnsaved()
    }

    private func duplicateNode(_ node: CanvasNode) {
        var copy = node
        copy.id = UUID()
        copy.position.x += 60
        copy.position.y += 60
        viewModel.addNode(copy)
        markUnsaved()
    }

    private func toggleDisable(nodeId: UUID) {
        guard let idx = viewModel.graph.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        viewModel.graph.nodes[idx].isDisabled.toggle()
        markUnsaved()
    }

    private func groupSelected() {
        let selectedIds = viewModel.selectedNodeIds
        guard selectedIds.count > 1 else { return }
        let group = NodeGroup(title: "分组 \(viewModel.graph.groups.count + 1)", nodeIds: Array(selectedIds))
        viewModel.graph.groups.append(group)
        markUnsaved()
    }

    private func markUnsaved() {
        saveStatus = .unsaved
        autoSave()
    }

    private func autoSave() {
        saveStatus = .saving
        Task {
            try? await Task.sleep(for: .seconds(2))
            await viewModel.saveToBackend()
            await MainActor.run { saveStatus = .saved }
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

    private var groupBoxesLayer: some View {
        ForEach(viewModel.graph.groups) { group in
            GroupBoxView(group: group, nodes: viewModel.graph.nodes)
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
            onNodeDragUpdate: { worldPos in viewModel.updateDrag(to: snapPointToGrid(worldPos)) },
            onNodeDragEnd: { viewModel.endDrag() },
            onOutputPortTap: { nodeId, portName in handleOutputPortTap(nodeId: nodeId, portName: portName) },
            onInputPortTap: { targetNodeId, targetPortName in completeWireDrag(targetNodeId: targetNodeId, targetPortName: targetPortName) },
            viewportScale: viewModel.viewport.scale,
            viewportOffset: viewModel.viewport.offset,
            onCollapseToggle: { toggleCollapse(nodeId: node.id) },
            onWidgetChange: { key, value in
                viewModel.updateNodeWidget(nodeId: node.id, key: key, value: value)
                markUnsaved()
            }
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
        markUnsaved()
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
        markUnsaved()
    }

    /// Add a node from the palette at a reasonable insert position
    private func addNodeFromPalette(_ def: NodeDefinition) {
        let centerX = (-viewModel.viewport.offset.x + 200) / viewModel.viewport.scale
        let centerY = (-viewModel.viewport.offset.y + 200) / viewModel.viewport.scale
        let pos = snapPointToGrid(CGPoint(x: centerX + CGFloat.random(in: -40...40), y: centerY + CGFloat.random(in: -40...40)))
        let newNode = CanvasNode(
            nodeType: def.type,
            position: pos,
            size: CGSize(width: 200, height: 120)
        )
        viewModel.addNode(newNode)
        markUnsaved()
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
            _ = try await strategies.deploy(id: strategy.id)
        } catch {
            // Silent failure — preview will show error or user can retry
        }
        showCodePreview = false
    }
}
