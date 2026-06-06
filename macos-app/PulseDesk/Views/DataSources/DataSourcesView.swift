// DataSourcesView.swift — 数据源管理
// 数据源总览 + 分类过滤 + 连接测试 + 启用/禁用

import SwiftUI

struct DataSourcesView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
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
                            title: "加载失败",
                            description: error,
                            primaryAction: (title: "重试", action: { Task { await vm.load() } })
                        )
                    } else {
                        EmptyStateView(
                            icon: "externaldrive.connected.to.line.below",
                            title: "暂无数据源",
                            description: "尚未配置任何数据源"
                        )
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
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
                    .font(.system(size: 14))
                    .foregroundStyle(data.state == "error" ? PulseColors.StateColors.red : PulseColors.StateColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.state == "error" ? "系统异常" : "部分数据源异常")
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
                TerminalLabel(text: "数据源管理")
                Text("行情 · 链上 · 情绪 · 新闻 — 全链路数据接入")
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
                            .font(.system(size: 11))
                        Text("测试所有连接")
                            .font(PulseFonts.monoLabel)
                    }
                    .foregroundStyle(PulseColors.accent)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
                .help("刷新")
            }
        }
    }

    // MARK: - 汇总卡片

    private func summaryCardsRow(_ vm: DataSourcesViewModel) -> some View {
        let totalSources = vm.data?.sources.count ?? 0
        let categoryCount = vm.categories.count

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PulseSpacing.sm), count: 4), spacing: PulseSpacing.sm) {
            summaryCard(label: "总数据源", value: "\(totalSources)", color: colors.textPrimary, icon: "externaldrive.connected.to.line.below")
                .staggeredAppearance(index: 0)
            summaryCard(label: "活跃", value: "\(vm.totalActive)", color: PulseColors.StateColors.green, icon: "checkmark.circle")
                .staggeredAppearance(index: 1)
            summaryCard(label: "异常", value: "\(vm.totalError)", color: PulseColors.StateColors.red, icon: "exclamationmark.triangle")
                .staggeredAppearance(index: 2)
            summaryCard(label: "分类数", value: "\(categoryCount)", color: PulseColors.info, icon: "square.grid.2x2")
                .staggeredAppearance(index: 3)
        }
    }

    private func summaryCard(label: String, value: String, color: Color, icon: String) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
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
                categoryChip(label: "全部", category: nil, vm: vm)
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
                        .font(.system(size: 10))
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
                    title: "无匹配数据源",
                    description: "当前分类下没有数据源"
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

        return ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 头部：图标 + 名称 + 状态
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: iconForCategory(source.category))
                        .font(.system(size: 18))
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
                        Text("延迟")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Text(source.latencyMs > 0 ? "\(source.latencyMs)ms" : "—")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(latencyColor(source.latencyMs))
                    }

                    // 新鲜度
                    VStack(alignment: .leading, spacing: 1) {
                        Text("新鲜度")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        BadgeDot(color: freshnessColor(source.freshness), label: freshnessLabel(source.freshness))
                    }

                    Spacer()

                    // 最后获取时间
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("最后获取")
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
                            .font(.system(size: 9))
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
                                    .font(.system(size: 10))
                            }
                            Text("测试")
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
                                .font(.system(size: 10))
                            Text(source.status == "active" ? "禁用" : "启用")
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
            ("exchange_kline", "行情K线"),
            ("orderbook", "订单簿"),
            ("funding", "资金费率"),
            ("open_interest", "持仓量"),
            ("news", "新闻"),
            ("whale", "巨鲸"),
            ("on_chain", "链上数据"),
            ("research", "研究报告"),
            ("social", "社交情绪"),
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
        case "active": return "活跃"
        case "inactive": return "已禁用"
        case "error": return "异常"
        case "rate_limited": return "限流"
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
        case "fresh": return "新鲜"
        case "stale": return "陈旧"
        case "expired": return "过期"
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
            return "刚刚"
        case ..<3600:
            return "\(Int(interval / 60)) 分钟前"
        case ..<86400:
            return "\(Int(interval / 3600)) 小时前"
        default:
            return "\(Int(interval / 86400)) 天前"
        }
    }
}
