// StrategyCanvasTab.swift — 策略画布标签
// 主画布布局：背景网格 → 连线 → 节点 → 交互手势

import SwiftUI

struct StrategyCanvasTab: View {
    @State private var viewModel = CanvasViewModel()
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0

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

            // Layer 3: Nodes (placeholder — will be NodeView in Task 7)
            // For now, show node count as debug info when graph is empty
            if viewModel.graph.nodes.isEmpty {
                emptyState
            }

            // Layer 4: Wire drag preview (placeholder for Task 7)

            // Layer 5: Selection rectangle (placeholder for Task 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulseColors.background)
        .gesture(panGesture)
        .gesture(zoomGesture)
    }

    private var emptyState: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 48))
                .foregroundStyle(PulseColors.textMuted)
            Text("拖拽节点到画布开始构建策略")
                .font(PulseFonts.body)
                .foregroundStyle(PulseColors.textSecondary)
            Text("从左侧面板选择节点类型")
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.textMuted)
        }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
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

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = value.magnification / lastMagnification
                lastMagnification = value.magnification
                viewModel.zoom(by: factor, center: .zero)
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }
}
