// DataSourcesView.swift — 数据源管理
// 数据源总览 + 分类过滤 + 连接测试 + 启用/禁用

import SwiftUI

struct DataSourcesView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: DataSourcesViewModel?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                if let vm = viewModel {
                    if vm.isLoading && vm.data == nil {
                        LoadingView(type: .grid)
                    } else if vm.data != nil {
                        // 状态警告横幅
                        stateBanner(vm)

                        // 页面标题
                        headerSection(vm)

                        // 汇总卡片
                        summaryCardsRow(vm)

                        // 分类筛选
                        categoryFilterSection(vm)

                        // 数据源卡片网格
                        sourceCardsGrid(vm)
                    } else if let error = vm.error {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: L10n.zh("加载失败", en: "Load Failed"),
                            description: error,
                            primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.load() } })
                        )
                    } else {
                        EmptyStateView(
                            icon: "externaldrive.connected.to.line.below",
                            title: L10n.zh("暂无数据源", en: "No Data Sources"),
                            description: L10n.zh("尚未配置任何数据源", en: "No data sources configured yet")
                        )
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .id(settingsState.language)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            let vm = DataSourcesViewModel(client: networkClient)
            viewModel = vm
            await vm.load()
        }
    }

    // MARK: - 状态警告横幅

    @ViewBuilder
    private func stateBanner(_ vm: DataSourcesViewModel) -> some View {
        if let data = vm.data, data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: data.state == "error" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(PulseFonts.body)
                    .foregroundStyle(data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "error" ? L10n.zh("系统异常", en: "System Error") : L10n.zh("部分数据源异常", en: "Some Data Sources Degraded"))
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !data.reasonCodes.isEmpty {
                        Text(data.reasonCodes.joined(separator: ", "))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                Spacer()
            }
            .padding(PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill((data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke((data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange).opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - 页面标题

    private func headerSection(_ vm: DataSourcesViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                TerminalLabel(text: L10n.zh("数据源管理", en: "Data Sources"))
                Text(L10n.zh("行情 · 链上 · 情绪 · 新闻 — 全链路数据接入", en: "Market · On-Chain · Sentiment · News — Full Pipeline Data Ingestion"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            HStack(spacing: PulseSpacing.sm) {
                Button {
                    Task { await testAllConnections(vm) }
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(PulseFonts.caption)
                        Text(L10n.zh("测试所有连接", en: "Test All Connections"))
                            .font(PulseFonts.monoLabel)
                    }
                    .foregroundStyle(PulseColors.accent)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(PulseFonts.label)
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
                .help(L10n.zh("刷新", en: "Refresh"))
            }
        }
    }

    // MARK: - 汇总卡片

    private func summaryCardsRow(_ vm: DataSourcesViewModel) -> some View {
        let totalSources = vm.data?.sources.count ?? 0
        let categoryCount = vm.categories.count

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PulseSpacing.sm), count: 4), spacing: PulseSpacing.sm) {
            summaryCard(label: L10n.zh("总数据源", en: "Total Sources"), value: "\(totalSources)", color: colors.textPrimary, icon: "externaldrive.connected.to.line.below")
                .staggeredAppearance(index: 0)
            summaryCard(label: L10n.zh("活跃", en: "Active"), value: "\(vm.totalActive)", color: PulseColors.StateColors.green, icon: "checkmark.circle")
                .staggeredAppearance(index: 1)
            summaryCard(label: L10n.zh("异常", en: "Error"), value: "\(vm.totalError)", color: PulseColors.StateColors.red, icon: "exclamationmark.triangle")
                .staggeredAppearance(index: 2)
            summaryCard(label: L10n.zh("分类数", en: "Categories"), value: "\(categoryCount)", color: PulseColors.info, icon: "square.grid.2x2")
                .staggeredAppearance(index: 3)
        }
    }

    private func summaryCard(label: String, value: String, color: Color, icon: String) -> some View {
        KryptonCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: icon)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(color.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    Text(value)
                        .font(PulseFonts.tabularLarge)
                        .foregroundStyle(color)
                }

                Spacer()
            }
        }
    }

    // MARK: - 分类筛选

    private func categoryFilterSection(_ vm: DataSourcesViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.xs) {
                categoryChip(label: L10n.zh("全部", en: "All"), category: nil, vm: vm)
                ForEach(allCategories, id: \.key) { cat in
                    categoryChip(label: cat.label, category: cat.key, vm: vm)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func categoryChip(label: String, category: String?, vm: DataSourcesViewModel) -> some View {
        let isSelected = vm.selectedCategory == category

        return Button {
            withAnimation(PulseAnimation.easeOutMedium) {
                vm.selectedCategory = category
            }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                if let cat = category {
                    Image(systemName: iconForCategory(cat))
                        .font(PulseFonts.monoLabel)
                }
                Text(label)
                    .font(PulseFonts.captionMedium)
            }
            .foregroundStyle(isSelected ? PulseColors.accent : colors.textSecondary)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .fill(isSelected ? PulseColors.accent.opacity(0.10) : colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(isSelected ? PulseColors.accent.opacity(0.3) : colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据源卡片网格

    private func sourceCardsGrid(_ vm: DataSourcesViewModel) -> some View {
        let filteredSources = vm.sources

        return Group {
            if filteredSources.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: L10n.zh("无匹配数据源", en: "No Matching Sources"),
                    description: L10n.zh("当前分类下没有数据源", en: "No data sources in this category")
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: PulseSpacing.sm), GridItem(.flexible(), spacing: PulseSpacing.sm)], spacing: PulseSpacing.sm) {
                    ForEach(Array(filteredSources.enumerated()), id: \.element.id) { index, source in
                        sourceCard(source, vm: vm)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }

    private func sourceCard(_ source: DataSourceItemResponse, vm: DataSourcesViewModel) -> some View {
        let isTesting = vm.testingSourceId == source.sourceId

        return KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 头部：图标 + 名称 + 状态
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: iconForCategory(source.category))
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(statusColor(source.status).opacity(0.9))
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(source.name)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)
                        Text(source.provider)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    Spacer()

                    BadgeDot(color: statusColor(source.status), label: statusLabel(source.status))
                }

                // 指标行：延迟 + 新鲜度 + 最后获取
                HStack(spacing: PulseSpacing.md) {
                    // 延迟
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.zh("延迟", en: "Latency"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(source.latencyMs > 0 ? "\(source.latencyMs)ms" : "—")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(latencyColor(source.latencyMs))
                    }

                    // 新鲜度
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.zh("新鲜度", en: "Freshness"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        BadgeDot(color: freshnessColor(source.freshness), label: freshnessLabel(source.freshness))
                    }

                    Spacer()

                    // 最后获取时间
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(L10n.zh("最后获取", en: "Last Fetch"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(relativeTime(source.lastFetch))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                // reason_codes 警告
                if !source.reasonCodes.isEmpty {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(PulseFonts.micro)
                        Text(source.reasonCodes.joined(separator: ", "))
                            .font(PulseFonts.micro)
                            .lineLimit(1)
                    }
                    .foregroundStyle(PulseColors.StateColors.orange)
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 3)
                    .background(PulseColors.StateColors.orange.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                }

                // 操作按钮
                HStack(spacing: PulseSpacing.sm) {
                    Spacer()

                    // 测试连接按钮
                    Button {
                        Task { await vm.testConnection(source.sourceId) }
                    } label: {
                        HStack(spacing: 3) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.horizontal")
                                    .font(PulseFonts.monoLabel)
                            }
                            Text(L10n.zh("测试", en: "Test"))
                                .font(PulseFonts.monoLabel)
                        }
                        .foregroundStyle(isTesting ? colors.textMuted : PulseColors.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)

                    // 启用/禁用 toggle
                    Button {
                        Task { await vm.toggleSource(source) }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: source.status == "active" ? "pause.circle" : "play.circle")
                                .font(PulseFonts.monoLabel)
                            Text(source.status == "active" ? L10n.zh("禁用", en: "Disable") : L10n.zh("启用", en: "Enable"))
                                .font(PulseFonts.monoLabel)
                        }
                        .foregroundStyle(source.status == "active" ? PulseColors.StateColors.orange : PulseColors.StateColors.green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func testAllConnections(_ vm: DataSourcesViewModel) async {
        guard let sources = vm.data?.sources else { return }
        for source in sources where source.status != "inactive" {
            await vm.testConnection(source.sourceId)
        }
    }

    // 分类定义
    private var allCategories: [(key: String, label: String)] {
        [
            ("exchange_kline", L10n.zh("行情K线", en: "Kline")),
            ("orderbook", L10n.zh("订单簿", en: "Order Book")),
            ("funding", L10n.zh("资金费率", en: "Funding Rate")),
            ("open_interest", L10n.zh("持仓量", en: "Open Interest")),
            ("news", L10n.zh("新闻", en: "News")),
            ("whale", L10n.zh("巨鲸", en: "Whale")),
            ("on_chain", L10n.zh("链上数据", en: "On-Chain")),
            ("research", L10n.zh("研究报告", en: "Research")),
            ("social", L10n.zh("社交情绪", en: "Social Sentiment")),
        ]
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "exchange_kline": return "chart.line.uptrend.xyaxis"
        case "orderbook": return "book.pages"
        case "funding": return "dollarsign.arrow.circlepath"
        case "open_interest": return "chart.bar"
        case "news": return "newspaper"
        case "whale": return "fish"
        case "on_chain": return "link.circle"
        case "research": return "doc.text.magnifyingglass"
        case "social": return "bubble.left.and.bubble.right"
        default: return "questionmark.circle"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return PulseColors.StateColors.green
        case "inactive": return PulseColors.StateColors.gray
        case "error": return PulseColors.StateColors.red
        case "rate_limited": return PulseColors.StateColors.orange
        default: return PulseColors.StateColors.gray
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "active": return L10n.zh("活跃", en: "Active")
        case "inactive": return L10n.zh("已禁用", en: "Disabled")
        case "error": return L10n.zh("异常", en: "Error")
        case "rate_limited": return L10n.zh("限流", en: "Rate Limited")
        default: return status
        }
    }

    private func freshnessColor(_ freshness: String) -> Color {
        switch freshness {
        case "fresh": return PulseColors.StateColors.green
        case "stale": return PulseColors.StateColors.yellow
        case "expired": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }

    private func freshnessLabel(_ freshness: String) -> String {
        switch freshness {
        case "fresh": return L10n.zh("新鲜", en: "Fresh")
        case "stale": return L10n.zh("陈旧", en: "Stale")
        case "expired": return L10n.zh("过期", en: "Expired")
        default: return freshness
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case 0: return colors.textMuted
        case 1..<100: return PulseColors.StateColors.green
        case 100..<300: return PulseColors.StateColors.yellow
        default: return PulseColors.StateColors.orange
        }
    }

    private func relativeTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Try with fractional seconds first, then without
        guard let date = formatter.date(from: isoString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: isoString)
        }() else {
            return isoString.isEmpty ? "—" : isoString
        }

        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:
            return L10n.zh("刚刚", en: "Just now")
        case ..<3600:
            return "\(Int(interval / 60)) \(L10n.zh("分钟前", en: "min ago"))"
        case ..<86400:
            return "\(Int(interval / 3600)) \(L10n.zh("小时前", en: "hr ago"))"
        default:
            return "\(Int(interval / 86400)) \(L10n.zh("天前", en: "d ago"))"
        }
    }
}
