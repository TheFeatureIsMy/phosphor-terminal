// CommandPaletteView.swift — Cmd+K 全局命令面板
// 类 Raycast 的搜索覆盖层，支持键盘导航

import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var searchResults: [Strategy] = []
    @FocusState private var isSearchFocused: Bool

    private var filteredRoutes: [AppRoute] {
        if searchText.isEmpty {
            return AppRoute.allCases
        }
        return AppRoute.allCases.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Combined count of route results + strategy results for keyboard navigation bounds
    private var totalItems: Int {
        filteredRoutes.count + searchResults.count
    }

    var body: some View {
        ZStack {
            // 半透明遮罩
            colors.background.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // 面板
            VStack(spacing: 0) {
                // 搜索输入框
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(colors.textMuted)

                    TextField("搜索页面、策略、设置...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.body)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, _ in
                            selectedIndex = 0
                        }

                    Text("ESC")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colors.surfaceHover)
                        )
                }
                .padding(PulseSpacing.md)

                Divider()
                    .foregroundStyle(colors.border)

                // 搜索结果
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            // "页面" section header
                            if !filteredRoutes.isEmpty {
                                Text("页面")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, PulseSpacing.xs)
                            }

                            // 页面结果
                            ForEach(Array(filteredRoutes.enumerated()), id: \.element.id) { index, route in
                                resultRow(route, index: index)
                                    .id(index)
                            }

                            // 无匹配状态
                            if filteredRoutes.isEmpty && searchResults.isEmpty && !searchText.isEmpty {
                                Text("无匹配结果")
                                    .font(PulseFonts.body)
                                    .foregroundStyle(colors.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, PulseSpacing.xl)
                            }

                            // 策略搜索结果
                            if !searchResults.isEmpty {
                                Divider()
                                    .foregroundStyle(colors.border)
                                    .padding(.vertical, PulseSpacing.xs)

                                Text("策略")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, PulseSpacing.xs)

                                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, strategy in
                                    strategyRow(strategy, index: filteredRoutes.count + index)
                                        .id(filteredRoutes.count + index)
                                }
                            }
                        }
                        .padding(PulseSpacing.xs)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .frame(width: 480)
            .scaleEffect(appState.showCommandPalette ? 1 : 0.95)
            .opacity(appState.showCommandPalette ? 1 : 0)
            .animation(PulseAnimation.springDefault, value: appState.showCommandPalette)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.lg)
                    .fill(colors.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.lg)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.lg)
                    .stroke(PulseGlass.accentBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(totalItems - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredRoutes.count {
                if let route = filteredRoutes[safe: selectedIndex] {
                    selectRoute(route)
                }
            } else {
                let strategyIndex = selectedIndex - filteredRoutes.count
                if let strategy = searchResults[safe: strategyIndex] {
                    selectStrategy(strategy)
                }
            }
            return .handled
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            await searchBackend()
        }
    }

    // MARK: - 策略结果行
    private func strategyRow(_ strategy: Strategy, index: Int) -> some View {
        CommandPaletteRow(
            icon: "chart.line.uptrend.xyaxis",
            title: strategy.name,
            subtitle: strategy.type.label,
            isSelected: index == selectedIndex,
            action: { selectStrategy(strategy) }
        )
    }

    // MARK: - 结果行
    private func resultRow(_ route: AppRoute, index: Int) -> some View {
        CommandPaletteRow(
            icon: route.icon,
            title: route.label,
            subtitle: route.section.label,
            isSelected: index == selectedIndex,
            action: { selectRoute(route) }
        )
    }

    private func selectRoute(_ route: AppRoute) {
        withAnimation(PulseAnimation.easeOutFast) {
            appState.selectedRoute = route
            dismiss()
        }
    }

    private func selectStrategy(_ strategy: Strategy) {
        withAnimation(PulseAnimation.easeOutFast) {
            appState.selectedRoute = .strategies
            dismiss()
        }
    }

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

    // MARK: - 共享行组件
    private struct CommandPaletteRow: View {
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
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? PulseColors.accent : colors.textSecondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(PulseFonts.bodyMedium).foregroundStyle(colors.textPrimary)
                        Text(subtitle).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    if isSelected {
                        Text("Enter").font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceHover))
                    }
                }
                .padding(.vertical, PulseSpacing.xs).padding(.horizontal, PulseSpacing.xs)
                .background(RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(isSelected ? PulseColors.accent.opacity(0.1) : .clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Array 安全访问
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
