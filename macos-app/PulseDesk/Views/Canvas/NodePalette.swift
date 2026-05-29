// NodePalette.swift — 左侧节点面板 (240px)
// 按分类展示可用节点类型，支持搜索和折叠展开

import SwiftUI

struct NodePalette: View {
    @Binding var isPresented: Bool
    var onNodeSelected: ((NodeDefinition) -> Void)?

    @State private var searchText = ""
    @State private var expandedCategories: Set<NodeCategory> = [.data]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().foregroundStyle(PulseColors.border)

            // Search
            searchBar

            Divider().foregroundStyle(PulseColors.border)

            // Node list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(NodeCategory.allCases, id: \.self) { category in
                        let defs = filteredNodes(in: category)
                        if !defs.isEmpty || searchText.isEmpty {
                            categorySection(category, definitions: defs)
                        }
                    }
                }
            }
        }
        .frame(width: 240)
        .background(PulseColors.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(PulseGlass.surfaceTint)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(PulseColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12))
                .foregroundStyle(PulseColors.accent)
            Text("节点面板")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(PulseColors.textPrimary)
            Spacer()
            Button {
                withAnimation(PulseAnimation.easeOutFast) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseColors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.sm)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(PulseColors.textMuted)
            TextField("搜索节点...", text: $searchText)
                .textFieldStyle(.plain)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.textPrimary)
        }
        .padding(PulseSpacing.xs)
        .background(PulseColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - Category section

    private func categorySection(_ category: NodeCategory, definitions: [NodeDefinition]) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategories.contains(category) },
                set: { isExpanded in
                    withAnimation(PulseAnimation.easeOutFast) {
                        if isExpanded {
                            expandedCategories.insert(category)
                        } else {
                            expandedCategories.remove(category)
                        }
                    }
                }
            )
        ) {
            VStack(spacing: 1) {
                ForEach(definitions) { def in
                    nodeRow(def)
                }
            }
            .padding(.leading, PulseSpacing.xs)
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(category.color)
                    .frame(width: 16)
                Text(category.label)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(PulseColors.textPrimary)
                Spacer()
                Text("\(definitions.count)")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.textMuted)
            }
        }
        .padding(.horizontal, PulseSpacing.sm)
        .padding(.vertical, 2)
    }

    // MARK: - Node row

    private func nodeRow(_ def: NodeDefinition) -> some View {
        Button {
            onNodeSelected?(def)
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: def.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(def.color)
                    .frame(width: 16)
                Text(def.name)
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                // Port count indicator
                if !def.outputPorts.isEmpty {
                    Text("\(def.outputPorts.count)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.textMuted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(PulseColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, PulseSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter

    private func filteredNodes(in category: NodeCategory) -> [NodeDefinition] {
        let defs = NodeRegistry.nodes(in: category)
        if searchText.isEmpty { return defs }
        return defs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }
}
