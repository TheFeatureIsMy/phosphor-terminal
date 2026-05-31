import SwiftUI

struct NodePalette: View {
    @Environment(PulseColors.self) private var colors
    @Binding var isPresented: Bool
    var onAddNode: (NodeDefinition) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: NodeCategory? = nil
    @State private var favoriteTypes: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "canvas.favoriteNodes") ?? [])
    @State private var recentlyUsed: [String] = UserDefaults.standard.stringArray(forKey: "canvas.recentNodes") ?? []
    @FocusState private var isSearchFocused: Bool

    private let allDefinitions = NodeRegistry.allDefinitions

    private var displayedDefinitions: [NodeDefinition] {
        let categoryFiltered: [NodeDefinition]
        if let cat = selectedCategory {
            categoryFiltered = allDefinitions.filter { $0.category == cat }
        } else {
            categoryFiltered = allDefinitions
        }
        if searchText.isEmpty { return categoryFiltered }
        return categoryFiltered.filter { def in
            def.name.localizedCaseInsensitiveContains(searchText) ||
            def.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favoriteDefs: [NodeDefinition] {
        allDefinitions.filter { favoriteTypes.contains($0.type) }
    }

    private var recentDefs: [NodeDefinition] {
        recentlyUsed.compactMap { type in allDefinitions.first(where: { $0.type == type }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .focused($isSearchFocused)
            }
            .padding(8)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colors.border, lineWidth: 1))
            .padding(8)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    CategoryTab(label: "全部", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(NodeCategory.allCases, id: \.self) { cat in
                        CategoryTab(label: cat.label, isSelected: selectedCategory == cat) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            Divider().foregroundStyle(colors.border)

            // Node list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if searchText.isEmpty && selectedCategory == nil {
                        if !favoriteDefs.isEmpty {
                            sectionHeader("⭐ 收藏", onClear: { clearFavorites() })
                            ForEach(favoriteDefs) { def in nodeRow(def) }
                        }
                        if !recentDefs.isEmpty {
                            sectionHeader("🕐 最近使用", onClear: { clearRecents() })
                            ForEach(recentDefs) { def in nodeRow(def) }
                        }
                    }

                    if searchText.isEmpty && selectedCategory == nil {
                        ForEach(NodeCategory.allCases, id: \.self) { cat in
                            let catDefs = allDefinitions.filter { $0.category == cat }
                            if !catDefs.isEmpty {
                                sectionHeader("📂 \(cat.label)", onClear: nil)
                                ForEach(catDefs) { def in nodeRow(def) }
                            }
                        }
                    } else {
                        ForEach(displayedDefinitions) { def in nodeRow(def) }
                    }
                }
            }
        }
        .frame(width: 220)
        .background(colors.background)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(colors.border), alignment: .trailing)
        .onAppear { loadRecents() }
    }

    private func sectionHeader(_ title: String, onClear: (() -> Void)?) -> some View {
        HStack {
            Text(title).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Spacer()
            if let onClear {
                Button("清除") { onClear() }
                    .font(PulseFonts.micro).foregroundStyle(PulseColors.accent).buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    private func nodeRow(_ def: NodeDefinition) -> some View {
        HStack(spacing: 6) {
            Image(systemName: def.icon).font(.system(size: 10)).foregroundStyle(def.color).frame(width: 14)
            Text(def.name).font(PulseFonts.caption).foregroundStyle(colors.textPrimary).lineLimit(1)
            Spacer()
            Button {
                toggleFavorite(def)
            } label: {
                Image(systemName: favoriteTypes.contains(def.type) ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(favoriteTypes.contains(def.type) ? PulseColors.amber : colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onAddNode(def); addToRecent(def) }
        .onDrag { NSItemProvider(object: def.type as NSString) }
    }

    private func toggleFavorite(_ def: NodeDefinition) {
        if favoriteTypes.contains(def.type) {
            favoriteTypes.remove(def.type)
        } else {
            favoriteTypes.insert(def.type)
        }
        persistFavorites()
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoriteTypes), forKey: "canvas.favoriteNodes")
    }

    private func clearFavorites() {
        favoriteTypes.removeAll()
        persistFavorites()
    }

    private func addToRecent(_ def: NodeDefinition) {
        recentlyUsed.removeAll { $0 == def.type }
        recentlyUsed.insert(def.type, at: 0)
        if recentlyUsed.count > 10 { recentlyUsed = Array(recentlyUsed.prefix(10)) }
        UserDefaults.standard.set(recentlyUsed, forKey: "canvas.recentNodes")
    }

    private func loadRecents() {
        recentlyUsed = UserDefaults.standard.stringArray(forKey: "canvas.recentNodes") ?? []
    }

    private func clearRecents() {
        recentlyUsed.removeAll()
        UserDefaults.standard.set(recentlyUsed, forKey: "canvas.recentNodes")
    }
}

// MARK: - CategoryTab
private struct CategoryTab: View {
    @Environment(PulseColors.self) private var colors
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? PulseColors.accent : colors.textMuted)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? PulseColors.accent.opacity(0.1) : .clear)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(isSelected ? PulseColors.accent : .clear),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
    }
}
