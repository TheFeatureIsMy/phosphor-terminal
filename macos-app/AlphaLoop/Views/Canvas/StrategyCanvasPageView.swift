// StrategyCanvasPageView.swift — 策略画布独立页面
// 完整的画布编辑器：策略选择器 + React WKWebView 画布 + DSL预览 + 验证状态栏

import SwiftUI

struct StrategyCanvasPageView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(\.networkClient) private var networkClient

    // MARK: - State

    @State private var strategies: [StrategyV2] = []
    @State private var selectedStrategyId: String?
    @State private var isLoadingStrategies = true
    @State private var canvasVM: CanvasWebViewModel?
    @State private var showCreatePanel = false
    @State private var showTemplateLibrary = false
    @State private var showDSLPreview = false
    @State private var dslPreviewText = ""
    @State private var sidebarWidth: CGFloat = 220

    private var selectedStrategy: StrategyV2? {
        strategies.first(where: { $0.id == selectedStrategyId })
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(colors.border)

            if isLoadingStrategies {
                loadingView
            } else if strategies.isEmpty && !showCreatePanel {
                emptyStateView
            } else {
                mainContent
            }

            Divider().overlay(colors.border)
            validationStatusBar
        }
        .background(colors.background)
        .task { await loadStrategies() }
        .onChange(of: selectedStrategyId) { _, newId in
            if let id = newId {
                initializeCanvas(strategyId: id)
            }
        }
        .sheet(isPresented: $showCreatePanel) {
            createStrategySheet
        }
        .sheet(isPresented: $showTemplateLibrary) {
            templateLibrarySheet
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: "策略画布")

            if let strategy = selectedStrategy {
                HStack(spacing: PulseSpacing.xs) {
                    Circle()
                        .fill(statusColor(strategy.status))
                        .frame(width: 6, height: 6)
                    Text(strategy.name)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(colors.surface)
                )
            }

            Spacer()

            HStack(spacing: PulseSpacing.xs) {
                KryptonButton(title: "新建策略", action: {
                    showCreatePanel = true
                }, style: .ghost)

                KryptonButton(title: "模板库", action: {
                    showTemplateLibrary = true
                }, style: .ghost)

                KryptonButton(title: "验证", action: {
                    Task { await validateCurrentDSL() }
                }, style: .ghost)
                .disabled(canvasVM == nil || canvasVM?.lastDSL == nil)
                .opacity(canvasVM?.lastDSL == nil ? 0.5 : 1)

                KryptonButton(title: "保存", action: {
                    Task { await saveCurrentVersion() }
                })
                .disabled(canvasVM == nil || canvasVM?.lastDSL == nil)
                .opacity(canvasVM?.lastDSL == nil ? 0.5 : 1)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(colors.surfaceElevated.opacity(0.5))
    }

    // MARK: - Main Content (Sidebar + Canvas + DSL Preview)

    private var mainContent: some View {
        HStack(spacing: 0) {
            // Left: Strategy Selector Sidebar
            strategySidebar
                .frame(width: sidebarWidth)

            Divider().overlay(colors.border)

            // Center: Canvas WebView
            ZStack {
                if let vm = canvasVM {
                    CanvasWebView(viewModel: vm)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))

                    // Saving/status overlay
                    canvasStatusOverlay(vm: vm)
                } else {
                    canvasPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: DSL Preview Panel (toggleable)
            if showDSLPreview {
                Divider().overlay(colors.border)
                dslPreviewPanel
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(PulseAnimation.springDefault, value: showDSLPreview)
    }

    // MARK: - Strategy Sidebar

    private var strategySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar header
            HStack {
                Text("策略列表")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(1.0)

                Spacer()

                Button(action: { showCreatePanel = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseColors.accent)
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(PulseColors.accent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)

            Divider().overlay(colors.border)

            // Strategy list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: PulseSpacing.xxs) {
                    ForEach(strategies) { strategy in
                        strategySidebarRow(strategy)
                    }
                }
                .padding(.vertical, PulseSpacing.xs)
                .padding(.horizontal, PulseSpacing.xs)
            }
        }
        .background(colors.surface.opacity(0.3))
    }

    private func strategySidebarRow(_ strategy: StrategyV2) -> some View {
        let isSelected = strategy.id == selectedStrategyId

        return Button(action: {
            withAnimation(PulseAnimation.easeOutFast) {
                selectedStrategyId = strategy.id
            }
        }) {
            HStack(spacing: PulseSpacing.xs) {
                Circle()
                    .fill(statusColor(strategy.status))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(strategy.name)
                        .font(PulseFonts.caption)
                        .foregroundStyle(isSelected ? colors.textPrimary : colors.textSecondary)
                        .lineLimit(1)

                    Text(strategy.statusLabel)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PulseColors.accent)
                }
            }
            .padding(.horizontal, PulseSpacing.xs)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(isSelected ? PulseColors.accent.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(isSelected ? PulseColors.accent.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Canvas Status Overlay

    private func canvasStatusOverlay(vm: CanvasWebViewModel) -> some View {
        VStack {
            HStack(spacing: PulseSpacing.sm) {
                Spacer()
                if vm.isSaving {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("保存中...")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(colors.surfaceElevated)
                    )
                }
                if vm.saveSuccess {
                    Text("✓ 已保存")
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .fill(PulseColors.accent.opacity(0.1))
                        )
                }
                if let error = vm.error {
                    Text(error)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger)
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .fill(PulseColors.danger.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.top, PulseSpacing.xs)

            Spacer()
        }
    }

    // MARK: - Canvas Placeholder

    private var canvasPlaceholder: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(colors.textMuted.opacity(0.5))

            Text("选择左侧策略开始编辑")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            Text("或创建新策略")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - DSL Preview Panel

    private var dslPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Panel header
            HStack {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseColors.accent)
                    Text("CODE PREVIEW")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                        .tracking(1.0)
                }

                Spacer()

                Button(action: { copyDSLToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(colors.surface)
                        )
                }
                .buttonStyle(.plain)
                .help("复制 DSL")

                Button(action: {
                    withAnimation(PulseAnimation.springDefault) {
                        showDSLPreview = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .fill(colors.surface)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)

            Divider().overlay(colors.border)

            // DSL content
            ScrollView(.vertical, showsIndicators: true) {
                Text(dslPreviewText.isEmpty ? "// 画布变更后，DSL 代码将在此处实时预览\n// Edit the canvas to see DSL output" : dslPreviewText)
                    .font(PulseFonts.body)
                    .foregroundStyle(dslPreviewText.isEmpty ? colors.textMuted : colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PulseSpacing.sm)
                    .textSelection(.enabled)
            }
            .background(colors.background.opacity(0.5))
        }
        .background(colors.surface.opacity(0.3))
    }

    // MARK: - Validation Status Bar

    private var validationStatusBar: some View {
        HStack(spacing: PulseSpacing.md) {
            // Validation indicator
            if let vm = canvasVM {
                HStack(spacing: PulseSpacing.xs) {
                    if let valid = vm.validationValid {
                        Circle()
                            .fill(valid ? PulseColors.accent : PulseColors.danger)
                            .frame(width: 6, height: 6)
                        Text(valid ? "验证通过" : "验证失败 (\(vm.validationErrors) 错误)")
                            .font(PulseFonts.caption)
                            .foregroundStyle(valid ? PulseColors.accent : PulseColors.danger)
                    } else {
                        Circle()
                            .fill(colors.textMuted.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("未验证")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }

            Spacer()

            // DSL Preview Toggle
            Button(action: {
                withAnimation(PulseAnimation.springDefault) {
                    showDSLPreview.toggle()
                    if showDSLPreview {
                        updateDSLPreview()
                    }
                }
            }) {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 9, weight: .medium))
                    Text("DSL 预览")
                        .font(PulseFonts.caption)
                }
                .foregroundStyle(showDSLPreview ? PulseColors.accent : colors.textSecondary)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .fill(showDSLPreview ? PulseColors.accent.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(showDSLPreview ? PulseColors.accent.opacity(0.2) : colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Strategy count
            if !strategies.isEmpty {
                Text("\(strategies.count) 策略")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xs)
        .background(colors.surfaceElevated.opacity(0.3))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: PulseSpacing.md) {
            ProgressView()
                .controlSize(.regular)
            Text("加载策略列表...")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "square.on.square.dashed",
            title: "暂无策略",
            description: "创建您的第一个策略，使用可视化画布拖拽编排交易规则",
            primaryAction: (title: "新建策略", action: { showCreatePanel = true }),
            secondaryAction: (title: "浏览模板", action: { showTemplateLibrary = true })
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create Strategy Sheet

    private var createStrategySheet: some View {
        VStack(spacing: 0) {
            StrategyCreatePanel(onCancel: { showCreatePanel = false })
                .frame(width: 400)
                .padding(PulseSpacing.xl)
        }
        .background(PulseGlass.modalSurface)
        .environment(colors)
        .environment(appState)
    }

    // MARK: - Template Library Sheet

    private var templateLibrarySheet: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                TerminalLabel(text: "模板库")
                Spacer()
                Button(action: { showTemplateLibrary = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .background(colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(spacing: PulseSpacing.sm) {
                    templateRow(
                        name: "RSI 均值回归",
                        description: "RSI 超卖买入、超买卖出，适合震荡行情",
                        icon: "waveform.path.ecg"
                    )
                    templateRow(
                        name: "布林带突破",
                        description: "价格突破布林带上轨做多，跌破下轨做空",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    templateRow(
                        name: "MACD 趋势跟踪",
                        description: "MACD 金叉做多、死叉做空，搭配 EMA 过滤",
                        icon: "arrow.up.right"
                    )
                    templateRow(
                        name: "多时间框架确认",
                        description: "大周期定方向，小周期定入场，多级别共振",
                        icon: "clock.arrow.2.circlepath"
                    )
                    templateRow(
                        name: "网格交易",
                        description: "在固定价格区间内等距挂单，赚取波动收益",
                        icon: "grid"
                    )
                }
            }
            .frame(minHeight: 300)
        }
        .padding(PulseSpacing.lg)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: PulseGlass.sheetRadius)
                .fill(colors.cardBackground)
                .background(
                    RoundedRectangle(cornerRadius: PulseGlass.sheetRadius)
                        .fill(.ultraThinMaterial)
                )
        )
        .environment(colors)
    }

    private func templateRow(name: String, description: String, icon: String) -> some View {
        Button(action: {
            // TODO: Load template DSL into canvas
            showTemplateLibrary = false
        }) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(PulseColors.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .fill(PulseColors.accent.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(description)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(colors.surface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadStrategies() async {
        isLoadingStrategies = true
        let api = APIStrategiesV2(client: networkClient)
        do {
            strategies = try await api.list()
            // Auto-select first strategy if none selected
            if selectedStrategyId == nil, let first = strategies.first {
                selectedStrategyId = first.id
            }
        } catch {
            strategies = []
        }
        isLoadingStrategies = false
    }

    private func initializeCanvas(strategyId: String) {
        let vm = CanvasWebViewModel(strategyId: strategyId, client: networkClient)
        canvasVM = vm

        // Load canvas graph state asynchronously
        Task {
            let apiCanvas = APICanvas(client: networkClient)
            if let strategyIntId = Int(strategyId) {
                do {
                    let canvasData = try await apiCanvas.load(strategyId: strategyIntId)
                    if let data = canvasData.graphJson.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        vm.loadDSL(json)
                    }
                } catch {
                    // Canvas may not exist yet — that's fine, start with empty
                }
            }

            // Also try loading latest version DSL
            let apiStrategy = APIStrategiesV2(client: networkClient)
            do {
                let versions = try await apiStrategy.listVersions(strategyId: strategyId)
                if let latest = versions.first {
                    let dsl = latest.ruleDsl.mapValues { $0.value }
                    vm.loadDSL(dsl)
                }
            } catch {
                // No versions yet — start with blank canvas
            }
        }
    }

    private func validateCurrentDSL() async {
        guard let vm = canvasVM, let dsl = vm.lastDSL else { return }
        await vm.validateAndSendResult(dsl: dsl)
    }

    private func saveCurrentVersion() async {
        guard let vm = canvasVM, let dsl = vm.lastDSL else { return }
        await vm.saveVersion(dsl: dsl)
        // Refresh strategy list after save
        await loadStrategies()
    }

    private func updateDSLPreview() {
        guard let vm = canvasVM, let dsl = vm.lastDSL else {
            dslPreviewText = ""
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: dsl, options: [.prettyPrinted, .sortedKeys])
            dslPreviewText = String(data: data, encoding: .utf8) ?? ""
        } catch {
            dslPreviewText = "// 无法序列化 DSL\n// \(error.localizedDescription)"
        }
    }

    private func copyDSLToClipboard() {
        guard !dslPreviewText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dslPreviewText, forType: .string)
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return PulseColors.accent
        case "draft": return PulseColors.amber
        case "paused": return Color.orange
        case "archived": return colors.textMuted
        default: return colors.textMuted
        }
    }
}

// MARK: - Preview

