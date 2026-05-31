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
    @State private var showTabPalette = false
    @State private var tabSearchText = ""
    @State private var highlightedTabIndex = 0
    @State private var templateDismissed = false

    private var selectedNode: CanvasNode? {
        guard let id = viewModel.selectedNodeIds.first else { return nil }
        return viewModel.graph.nodes.first { $0.id == id }
    }

    private var filteredTabDefinitions: [NodeDefinition] {
        let all = NodeRegistry.allDefinitions
        if tabSearchText.isEmpty { return all }
        return all.filter { def in
            def.name.localizedCaseInsensitiveContains(tabSearchText) ||
            def.type.localizedCaseInsensitiveContains(tabSearchText) ||
            def.category.label.localizedCaseInsensitiveContains(tabSearchText)
        }
    }

    private var rubberBandLine: (from: CGPoint, to: CGPoint)? {
        guard case .draggingFrom(_, _, let fromPt) = viewModel.wiringState,
              let endpoint = viewModel.wireEndpoint else { return nil }
        return (from: fromPt, to: endpoint)
    }

    private func connectedInputPorts(
        for node: CanvasNode
    ) -> [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] {
        let edges = viewModel.graph.edges.filter { $0.targetNodeId == node.id }
        var result: [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] = [:]
        for edge in edges {
            let peerNode = viewModel.graph.nodes.first(where: { $0.id == edge.sourceNodeId })
            let peerName = peerNode
                .flatMap { NodeRegistry.definition(for: $0.nodeType)?.name ?? $0.nodeType }
            result[edge.targetPortKey] = (true, peerName, edge.sourceNodeId)
        }
        if let def = NodeRegistry.definition(for: node.nodeType) {
            for port in def.inputPorts where result[port.key] == nil {
                result[port.key] = (false, nil, nil)
            }
        }
        return result
    }

    private func connectedOutputPorts(
        for node: CanvasNode
    ) -> [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] {
        let edges = viewModel.graph.edges.filter { $0.sourceNodeId == node.id }
        var result: [String: (connected: Bool, peerName: String?, peerNodeId: UUID?)] = [:]
        for edge in edges {
            let peerNode = viewModel.graph.nodes.first(where: { $0.id == edge.targetNodeId })
            let peerName = peerNode
                .flatMap { NodeRegistry.definition(for: $0.nodeType)?.name ?? $0.nodeType }
            result[edge.sourcePortKey] = (true, peerName, edge.targetNodeId)
        }
        if let def = NodeRegistry.definition(for: node.nodeType) {
            for port in def.outputPorts where result[port.key] == nil {
                result[port.key] = (false, nil, nil)
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            if showPalette, !viewModel.isFullscreen {
                NodePalette(isPresented: $showPalette,
                    onAddNode: { def in addNode(def) },
                    onLoadTemplate: { template in viewModel.loadTemplate(template) })
                    .transition(.move(edge: .leading))
            }

            ZStack {
                CanvasBackground(scale: viewModel.viewport.scale, offset: viewModel.viewport.offset)
                CanvasEdges(edges: viewModel.graph.edges, nodes: viewModel.graph.nodes,
                            selectedEdgeIds: viewModel.selectedEdgeIds,
                            scale: viewModel.viewport.scale, offset: viewModel.viewport.offset,
                            rubberBand: rubberBandLine)

                GeometryReader { geo in
                    let culler = ViewportCuller()
                    let visible = culler.visibleNodes(
                        viewModel.graph.nodes,
                        selectedIds: viewModel.selectedNodeIds,
                        viewport: viewModel.viewport,
                        canvasSize: geo.size
                    )

                    if viewModel.graph.nodes.isEmpty, !templateDismissed {
                        templateEmptyState
                    } else if viewModel.graph.nodes.isEmpty {
                        Color.clear
                    } else {
                        ForEach(visible) { node in
                            NodeDragWrapper(viewModel: viewModel, node: node)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let selRect = viewModel.selectionRect {
                    CanvasSelectionRect(rect: selRect).allowsHitTesting(false)
                }

                if !viewModel.activeSnapGuides.isEmpty {
                    SnapGuidesView(guides: viewModel.activeSnapGuides,
                                   scale: viewModel.viewport.scale,
                                   offset: viewModel.viewport.offset)
                        .allowsHitTesting(false)
                }

                if viewModel.isLoading {
                    CanvasLoadingSkeleton()
                        .transition(.opacity)
                }

                if let toast = viewModel.errorNotifier.currentToast {
                    Text(toast)
                        .font(PulseFonts.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(PulseColors.danger.opacity(0.9)))
                        .padding(.top, 40)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(colors.background)
            .gesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.tab) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showTabPalette.toggle()
                    if showTabPalette { tabSearchText = ""; highlightedTabIndex = 0 }
                }
                return .handled
            }
            .onKeyPress(.return) {
                guard showTabPalette, !filteredTabDefinitions.isEmpty else { return .ignored }
                let idx = min(highlightedTabIndex, filteredTabDefinitions.count - 1)
                guard idx >= 0 else { return .handled }
                addNode(filteredTabDefinitions[idx])
                withAnimation(.easeInOut(duration: 0.15)) {
                    showTabPalette = false
                    tabSearchText = ""
                }
                return .handled
            }
            .onKeyPress(.delete) { deleteSelected(); return .handled }
            .onKeyPress(.escape) {
                if showTabPalette { showTabPalette = false; tabSearchText = ""; return .handled }
                if viewModel.isFullscreen { viewModel.isFullscreen = false; return .handled }
                viewModel.deselectAll(); return .handled
            }
            .onKeyPress(keys: [.init("z")], phases: .down) { press in
                press.modifiers.contains(.shift) ? viewModel.redo() : viewModel.undo()
                return .handled
            }
            .onKeyPress(keys: [.init("f")], phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                if press.modifiers.contains(.shift) {
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.isFullscreen.toggle() }
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) { showSearch = true }
                }
                return .handled
            }
            .onKeyPress(keys: [.init("g")], phases: .down) { press in
                guard press.modifiers.contains(.command) && showSearch else { return .ignored }
                navigateSearch(next: !press.modifiers.contains(.shift))
                return .handled
            }
            .onKeyPress(keys: [.init("c")], phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel.copySelected(); return .handled
            }
            .onKeyPress(keys: [.init("v")], phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel.paste(); return .handled
            }
            .onKeyPress(keys: [.init("d")], phases: .down) { press in
                guard press.modifiers.contains(.command) && !press.modifiers.contains(.shift) else {
                    return .ignored
                }
                viewModel.duplicateSelected(); return .handled
            }
            .onKeyPress(keys: [.init("a")], phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel.selectAll(); return .handled
            }
            .onKeyPress(keys: [.init("0")], phases: .down) { press in
                viewModel.fitToContent(); return .handled
            }
            .onKeyPress(.leftArrow) {
                if showTabPalette {
                    highlightedTabIndex = max(0, highlightedTabIndex - 1)
                    return .handled
                }
                let shift = NSEvent.modifierFlags.contains(.shift)
                nudgeSelection(dx: shift ? -10 : -1, dy: 0); return .handled
            }
            .onKeyPress(.rightArrow) {
                if showTabPalette {
                    highlightedTabIndex = min(filteredTabDefinitions.count - 1, highlightedTabIndex + 1)
                    return .handled
                }
                let shift = NSEvent.modifierFlags.contains(.shift)
                nudgeSelection(dx: shift ? 10 : 1, dy: 0); return .handled
            }
            .onKeyPress(.upArrow) {
                if showTabPalette {
                    highlightedTabIndex = max(0, highlightedTabIndex - 1)
                    return .handled
                }
                let shift = NSEvent.modifierFlags.contains(.shift)
                nudgeSelection(dx: 0, dy: shift ? -10 : -1); return .handled
            }
            .onKeyPress(.downArrow) {
                if showTabPalette {
                    highlightedTabIndex = min(filteredTabDefinitions.count - 1, highlightedTabIndex + 1)
                    return .handled
                }
                let shift = NSEvent.modifierFlags.contains(.shift)
                nudgeSelection(dx: 0, dy: shift ? 10 : 1); return .handled
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
            .onChange(of: tabSearchText) { _, _ in
                highlightedTabIndex = 0
            }
            .onChange(of: viewModel.graph.nodes.count) { _, count in
                if count > 0 { templateDismissed = false }
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
                    onWidgetChange: { k, v in
                        viewModel.updateNodeWidget(nodeId: node.id, key: k, value: v)
                    },
                    onClose: { showConfig = false },
                    connectedInputPorts: connectedInputPorts(for: node),
                    connectedOutputPorts: connectedOutputPorts(for: node)
                )
                .frame(width: 260)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPalette)
        .animation(.easeInOut(duration: 0.2), value: showConfig)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Button { withAnimation { showPalette.toggle() } } label: {
                        Image(systemName: showPalette ? "sidebar.left" : "sidebar.right")
                            .font(.system(size: 12)).foregroundStyle(colors.textSecondary)
                            .padding(6).background(
                                RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated)
                            )
                    }.buttonStyle(.plain)

                    Button { viewModel.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12)).foregroundStyle(colors.textSecondary)
                            .padding(6).background(
                                RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated)
                            )
                    }.buttonStyle(.plain)
                        .disabled(!viewModel.canUndo)
                        .opacity(viewModel.canUndo ? 1 : 0.4)

                    Button { viewModel.redo() } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 12)).foregroundStyle(colors.textSecondary)
                            .padding(6).background(
                                RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated)
                            )
                    }.buttonStyle(.plain)
                        .disabled(!viewModel.canRedo)
                        .opacity(viewModel.canRedo ? 1 : 0.4)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isFullscreen.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isFullscreen
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12)).foregroundStyle(colors.textSecondary)
                            .padding(6).background(
                                RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated)
                            )
                    }.buttonStyle(.plain)
                }

                if viewModel.isFullscreen, showPalette {
                    NodePalette(isPresented: $showPalette,
                        onAddNode: { def in addNode(def) },
                        onLoadTemplate: { template in viewModel.loadTemplate(template) })
                        .frame(width: 220)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.3), radius: 8)
                        .padding(.leading, 8)
                }
            }
            .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            ProofAlphaButton(title: "生成并部署") {
                generatedCode = (try? CodeGenerator()
                    .generate(from: viewModel.graph, strategyName: strategy.name)) ?? ""
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
        .overlay(alignment: .bottom) {
            HStack {
                saveStatusIndicator
                Spacer()
                Text("\(viewModel.graph.nodes.count) 节点 · \(viewModel.graph.edges.count) 连线")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted).monospacedDigit()
                Spacer().frame(width: 12)
                Text("\(Int(viewModel.viewport.scale * 100))%")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted).monospacedDigit()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(colors.background.opacity(0.8))
        }
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.graph.nodes.isEmpty {
                MiniMapView(
                    nodes: viewModel.graph.nodes,
                    edges: viewModel.graph.edges,
                    viewport: viewModel.viewport,
                    canvasSize: CGSize(width: 1200, height: 800),
                    onPan: { delta in viewModel.pan(by: delta) },
                    selectedNodeIds: viewModel.selectedNodeIds
                )
                .padding(8)
            }
        }
        .overlay {
            if showTabPalette {
                tabCommandPalette
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
        let cy = (-viewModel.viewport.offset.y + 150) / viewModel.viewport.scale
        let count = viewModel.graph.nodes.count
        let col = CGFloat(count % 3)
        let row = CGFloat(count / 3)
        let x = cx + col * 230
        let y = cy + row * 150
        viewModel.addNode(CanvasNode(nodeType: def.type,
            position: CGPoint(x: x, y: y),
            size: CGSize(width: 200, height: 120)))
    }

    private func deleteSelected() {
        for id in viewModel.selectedNodeIds { viewModel.removeNode(id: id) }
        showConfig = false
    }

    private func navigateSearch(next: Bool) {
        guard !searchMatches.isEmpty else { return }
        if next { currentSearchIndex = (currentSearchIndex + 1) % searchMatches.count }
        else {
            currentSearchIndex = (currentSearchIndex - 1 + searchMatches.count) % searchMatches.count
        }
        let targetId = searchMatches[currentSearchIndex]
        if let node = viewModel.graph.nodes.first(where: { $0.id == targetId }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                let cx = -(node.position.x + node.size.width / 2) * viewModel.viewport.scale + 400
                let cy = -(node.position.y + node.size.height / 2) * viewModel.viewport.scale + 300
                viewModel.viewport.offset = CGPoint(x: cx, y: cy)
            }
        }
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

    private func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        for id in viewModel.selectedNodeIds {
            if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == id }) {
                viewModel.graph.nodes[i].position.x += dx
                viewModel.graph.nodes[i].position.y += dy
            }
        }
    }

    // MARK: - Views
    private var templateEmptyState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.md) {
                Text("快速开始")
                    .font(PulseFonts.displayHeading).foregroundStyle(colors.textPrimary)
                Text("选择一个模板，或从空白开始构建")
                    .font(PulseFonts.body).foregroundStyle(colors.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                    ForEach(CanvasViewModel.templates) { template in
                        templateCard(template)
                            .onTapGesture { viewModel.loadTemplate(template) }
                    }
                    emptyCanvasCard
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func templateCard(_ template: CanvasTemplate) -> some View {
        VStack(spacing: 8) {
            Image(systemName: template.icon)
                .font(.system(size: 28))
                .foregroundStyle(PulseColors.accent)
            Text(template.name)
                .font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
            Text("\(template.nodeCount) 个节点")
                .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }
        .frame(width: 180, height: 120)
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
    }

    private var emptyCanvasCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 28))
                .foregroundStyle(colors.textMuted)
            Text("空画布")
                .font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
            Text("从零开始构建")
                .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }
        .frame(width: 180, height: 120)
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                templateDismissed = true
            }
        }
        .contentShape(Rectangle())
    }

    private func deployStrategy() async {
        isDeploying = true; defer { isDeploying = false }
        await viewModel.saveToBackend()
        _ = try? await APIStrategies(client: client).deploy(id: strategy.id)
        showCodePreview = false
    }

    // MARK: - Tab command palette
    private var tabCommandPalette: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showTabPalette = false
                        tabSearchText = ""
                    }
                }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14)).foregroundStyle(colors.textMuted)
                    TextField("搜索节点...", text: $tabSearchText)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.body)
                        .foregroundStyle(colors.textPrimary)
                }
                .padding(12)
                .background(colors.surface)

                Divider().foregroundStyle(colors.border)

                if !filteredTabDefinitions.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredTabDefinitions.enumerated()),
                                    id: \.element.id) { idx, def in
                                tabPaletteRow(def, isHighlighted: idx == highlightedTabIndex)
                                    .onTapGesture {
                                        addNode(def)
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showTabPalette = false
                                            tabSearchText = ""
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 24)).foregroundStyle(colors.textMuted)
                        Text("无匹配节点")
                            .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                    .padding(24)
                }
            }
            .frame(width: 360, height: 420)
            .background(colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.4), radius: 20)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        }
    }

    private func tabPaletteRow(_ def: NodeDefinition, isHighlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: def.icon)
                .font(.system(size: 14))
                .foregroundStyle(def.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(def.name)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Text(def.category.label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(def.color.opacity(0.15))
                )
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            isHighlighted ? colors.surfaceElevated : Color.clear
        )
        .contentShape(Rectangle())
    }

    // MARK: - Save status indicator
    private var saveStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(saveStatusColor).frame(width: 6, height: 6)
            Text(saveStatusText).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
        }
    }

    private var saveStatusColor: Color {
        switch viewModel.saveStatus {
        case .saved: return PulseColors.accent
        case .saving: return PulseColors.amber
        case .error: return PulseColors.danger
        case .dirty: return PulseColors.amber
        }
    }

    private var saveStatusText: String {
        switch viewModel.saveStatus {
        case .saved: return "已保存"
        case .saving: return "保存中..."
        case .error: return "保存失败"
        case .dirty: return "未保存"
        }
    }
}

// MARK: - CanvasLoadingSkeleton
private struct CanvasLoadingSkeleton: View {
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors.surfaceElevated)
                    .frame(width: 200, height: 100)
                    .shimmer()
                    .offset(x: CGFloat(i * 60 - 90), y: CGFloat(i * 70 - 100))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }
}

// MARK: - NodeDragWrapper — node rendering with drag and port click-to-connect
private struct NodeDragWrapper: View {
    let viewModel: CanvasViewModel
    let node: CanvasNode

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private var selected: Bool { viewModel.selectedNodeIds.contains(node.id) }

    private var connectedInputPorts: Set<String> {
        Set(viewModel.graph.edges.filter { $0.targetNodeId == node.id }.map(\.targetPortKey))
    }

    private var connectedOutputPorts: Set<String> {
        Set(viewModel.graph.edges.filter { $0.sourceNodeId == node.id }.map(\.sourcePortKey))
    }

    var body: some View {
        let def = NodeRegistry.definition(for: node.nodeType)
        let bp = screenPosFor(node)
        NodeView(
            node: node, definition: def,
            isSelected: selected, isDragging: isDragging,
            onPortDragStart: { nid, portKey, point in
                viewModel.startWireDrag(nodeId: nid, portKey: portKey, from: point)
            },
            onPortDragEnd: {
                viewModel.endWireDrag()
            },
            onPortTap: { nid, portKey, direction in
                viewModel.selectNode(id: nid)
                viewModel.handlePortTap(nodeId: nid, portKey: portKey, direction: direction)
            },
            onPortHover: { nid, portKey, hovering in
                if hovering, let nid, let portKey {
                    viewModel.updateWireDrag(to: .zero, hoveredPort: (nid, portKey))
                } else {
                    viewModel.updateWireDrag(to: viewModel.wireEndpoint ?? .zero, hoveredPort: nil)
                }
            },
            portCompatibility: { nid, portKey, direction in
                viewModel.isPortCompatible(nodeId: nid, portKey: portKey, direction: direction)
            },
            connectedInputPorts: connectedInputPorts,
            connectedOutputPorts: connectedOutputPorts,
            wiringSourcePortKey: viewModel.wiringState.sourcePortKey,
            onCollapseToggle: {
                if let i = viewModel.graph.nodes.firstIndex(where: { $0.id == node.id }) {
                    viewModel.graph.nodes[i].isCollapsed.toggle()
                }
            },
            onWidgetChange: { k, v in
                viewModel.updateNodeWidget(nodeId: node.id, key: k, value: v)
            }
        )
        .position(x: bp.x + dragOffset.width, y: bp.y + dragOffset.height)
        .scaleEffect(viewModel.viewport.scale, anchor: .center)
        .zIndex(isDragging || selected ? 10 : 1)
        .shadow(color: (isDragging || selected)
                ? PulseColors.accent.opacity(0.3) : .black.opacity(0.15),
                radius: isDragging ? 16 : 4, y: isDragging ? 4 : 2)
        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { v in
                    if !isDragging {
                        isDragging = true
                        viewModel.selectNode(id: node.id)
                        viewModel.startDrag(nodeId: node.id, at: node.position)
                    }
                    let s = viewModel.viewport.scale
                    dragOffset = CGSize(
                        width: v.translation.width / s, height: v.translation.height / s
                    )
                }
                .onEnded { v in
                    isDragging = false
                    dragOffset = .zero
                    let s = viewModel.viewport.scale
                    let rawX = node.position.x + v.translation.width / s
                    let rawY = node.position.y + v.translation.height / s
                    let useGrid = NSEvent.modifierFlags.contains(.shift)
                    let snapEngine = SnapEngine()
                    let result = snapEngine.snap(
                        position: CGPoint(x: rawX, y: rawY),
                        size: node.size,
                        otherNodes: viewModel.graph.nodes,
                        excludeId: node.id,
                        useGrid: useGrid
                    )
                    viewModel.updateDrag(to: result.snappedPosition)
                    viewModel.endDrag()
                    viewModel.activeSnapGuides = result.guides
                }
        )
        .onTapGesture {
            viewModel.selectNode(
                id: node.id, addToSelection: NSEvent.modifierFlags.contains(.command)
            )
        }
    }

    private func screenPosFor(_ n: CanvasNode) -> CGPoint {
        CGPoint(
            x: n.position.x * viewModel.viewport.scale
                + viewModel.viewport.offset.x
                + n.size.width * viewModel.viewport.scale / 2,
            y: n.position.y * viewModel.viewport.scale
                + viewModel.viewport.offset.y
                + n.size.height * viewModel.viewport.scale / 2
        )
    }
}
