// CommandPaletteView.swift — ⌘K 一等入口
// Phase 5: MRU 排序、交易对搜索、动作命令

import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var searchResults: [Strategy] = []
    @FocusState private var isSearchFocused: Bool

    // MARK: - Data sources

    private var allRoutes: [AppRoute] {
        AppRoute.allCases.filter { $0.sidebarVisible }
    }

    private var recentRoutes: [AppRoute] {
        appState.recentRoutes.filter { $0.sidebarVisible }
    }

    private static let tradingPairs: [PairItem] = [
        PairItem(symbol: "BTC/USDT", price: "68,420.50"),
        PairItem(symbol: "ETH/USDT", price: "3,840.12"),
        PairItem(symbol: "SOL/USDT", price: "156.45"),
        PairItem(symbol: "BNB/USDT", price: "582.30"),
        PairItem(symbol: "AVAX/USDT", price: "32.18"),
        PairItem(symbol: "DOGE/USDT", price: "0.1284"),
        PairItem(symbol: "ADA/USDT", price: "0.452"),
        PairItem(symbol: "MATIC/USDT", price: "0.682"),
    ]

    private var filteredPairs: [PairItem] {
        if searchText.isEmpty { return [] }
        return Self.tradingPairs.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredRoutes: [AppRoute] {
        if searchText.isEmpty {
            // Empty search: show MRU first, then others
            let remaining = allRoutes.filter { !recentRoutes.contains($0) }
            return recentRoutes + remaining
        }
        return allRoutes.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private struct PairItem: Identifiable {
        let id = UUID()
        let symbol: String
        let price: String
    }

    // Section offsets for keyboard navigation
    private var pairSectionStart: Int { filteredRoutes.count }
    private var pairSectionEnd: Int { pairSectionStart + filteredPairs.count }
    private var strategySectionStart: Int { pairSectionEnd }
    private var totalItems: Int { strategySectionStart + searchResults.count }

    var body: some View {
        ZStack {
            colors.background.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                searchHeader
                Divider().foregroundStyle(colors.border)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            // Section: Pages
                            if !filteredRoutes.isEmpty {
                                sectionLabel(searchText.isEmpty ? "最近" : "页面")
                                ForEach(Array(filteredRoutes.enumerated()), id: \.element.id) { index, route in
                                    routeRow(route, index: index).id(index)
                                }
                            }

                            // Section: Trading Pairs
                            if !filteredPairs.isEmpty {
                                sectionLabel("交易对")
                                ForEach(Array(filteredPairs.enumerated()), id: \.element.id) { index, pair in
                                    pairRow(pair, index: pairSectionStart + index).id(pairSectionStart + index)
                                }
                            }

                            // Section: Strategies (backend)
                            if !searchResults.isEmpty {
                                sectionLabel("策略")
                                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, strategy in
                                    strategyRow(strategy, index: strategySectionStart + index).id(strategySectionStart + index)
                                }
                            }

                            // Empty state
                            if filteredRoutes.isEmpty && filteredPairs.isEmpty && searchResults.isEmpty && !searchText.isEmpty {
                                Text("无匹配结果")
                                    .font(PulseFonts.body)
                                    .foregroundStyle(colors.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, PulseSpacing.xl)
                            }
                        }
                        .padding(PulseSpacing.xs)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
                .frame(maxHeight: 360)

                // Footer hints
                footerHints
            }
            .frame(width: 520)
            .scaleEffect(appState.showCommandPalette ? 1 : 0.95)
            .opacity(appState.showCommandPalette ? 1 : 0)
            .animation(PulseAnimation.springDefault, value: appState.showCommandPalette)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.lg)
                    .fill(colors.cardBackground)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.lg).fill(.ultraThinMaterial))
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.lg).stroke(colors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        }
        .onAppear { isSearchFocused = true }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(.downArrow) { selectedIndex = min(totalItems - 1, selectedIndex + 1); return .handled }
        .onKeyPress(.return) { handleEnter(); return .handled }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            await searchBackend()
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: PulseSpacing.sm) {
            AlphaLoopLogoView().frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("AlphaLoop Command")
                    .font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)

                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13)).foregroundStyle(PulseColors.accent)

                    TextField("open dashboard · btc position · pause trading ...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.body)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
                }
            }

            Spacer()

            Text("ESC")
                .font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceHover))
        }
        .padding(PulseSpacing.md)
    }

    // MARK: - Row types

    private func routeRow(_ route: AppRoute, index: Int) -> some View {
        PaletterRow(
            icon: route.icon,
            title: route.label,
            subtitle: route.primaryWorkspace.label,
            isSelected: index == selectedIndex,
            action: { selectRoute(route) }
        )
    }

    private func pairRow(_ pair: PairItem, index: Int) -> some View {
        PaletterRow(
            icon: "chart.line.uptrend.xyaxis",
            title: pair.symbol,
            subtitle: pair.price,
            isSelected: index == selectedIndex,
            action: { selectPair(pair) }
        )
    }

    private func strategyRow(_ strategy: Strategy, index: Int) -> some View {
        PaletterRow(
            icon: "gearshape.2",
            title: strategy.name,
            subtitle: strategy.tags.first ?? strategy.market,
            isSelected: index == selectedIndex,
            action: { selectStrategy(strategy) }
        )
    }

    // MARK: - Actions

    private func selectRoute(_ route: AppRoute) {
        appState.selectedRoute = route
        dismiss()
    }

    private func selectPair(_ pair: PairItem) {
        // Navigate to positions view filtered by this pair
        appState.selectedRoute = .ordersPositions
        dismiss()
    }

    private func selectStrategy(_ strategy: Strategy) {
        appState.selectedRoute = .strategyWorkspace
        dismiss()
    }

    private func handleEnter() {
        if selectedIndex < pairSectionStart, let route = filteredRoutes[safe: selectedIndex] {
            selectRoute(route)
        } else if selectedIndex < pairSectionEnd, let pair = filteredPairs[safe: selectedIndex - pairSectionStart] {
            selectPair(pair)
        } else if selectedIndex < totalItems, let strategy = searchResults[safe: selectedIndex - strategySectionStart] {
            selectStrategy(strategy)
        }
    }

    // MARK: - Backend search

    private func searchBackend() async {
        guard !searchText.isEmpty else { searchResults = []; return }
        let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        do {
            searchResults = try await networkClient.get("/search?q=\(query)", mock: { [] as [Strategy] })
        } catch {
            searchResults = []
        }
    }

    private func dismiss() {
        withAnimation(PulseAnimation.easeOutFast) {
            appState.showCommandPalette = false
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(colors.textMuted)
            .textCase(.uppercase)
            .tracking(1.2)
            .padding(.horizontal, PulseSpacing.xs)
            .padding(.top, PulseSpacing.sm)
            .padding(.bottom, 2)
    }

    // MARK: - Footer

    private var footerHints: some View {
        HStack(spacing: PulseSpacing.lg) {
            hint("↑↓", "导航")
            hint("↵", "选择")
            hint("ESC", "关闭")
            Spacer()
            if !searchText.isEmpty {
                Text("\(totalItems) 个结果")
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
        .overlay(alignment: .top) { Rectangle().fill(colors.border).frame(height: 1) }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(colors.surfaceHover))
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        }
    }
}

// MARK: - Shared Row Component

private struct PaletterRow: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? PulseColors.accent : colors.textSecondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
                    Text(subtitle).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }

                Spacer()

                if isSelected {
                    Text("↵").font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceHover))
                }
            }
            .padding(.vertical, PulseSpacing.xs).padding(.horizontal, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(isSelected ? PulseColors.accent.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Safe array access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
