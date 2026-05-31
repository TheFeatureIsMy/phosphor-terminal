// SignalsSectionView.swift — Agent 信号中心视图
// AI 代理信号聚合、评分与追踪

import SwiftUI

struct SignalsSectionView: View {
    @Environment(\.networkClient) private var client
    @Environment(PulseColors.self) private var colors
    @State private var signals: [AgentSignal] = []
    @State private var agents: [AgentProfile] = []
    @State private var isLoading = true
    @State private var filterSymbol = ""

    var filteredSignals: [AgentSignal] {
        if filterSymbol.isEmpty { return signals }
        return signals.filter { $0.symbol.localizedCaseInsensitiveContains(filterSymbol) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 概览指标
            overviewBar

            Divider().foregroundStyle(colors.border)

            // 过滤栏
            filterBar

            Divider().foregroundStyle(colors.border)

            // 信号列表
            if isLoading {
                loadingView
            } else if signals.isEmpty {
                EmptyStateView(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Agent 信号中心",
                    description: "运行 AI 研究委员会后，将研究结果发布为信号"
                )
            } else {
                signalList
            }
        }
        .task { await loadData() }
    }

    // MARK: - 概览栏
    private var overviewBar: some View {
        HStack(spacing: PulseSpacing.lg) {
            KPIBlock(label: "代理数", value: "\(agents.count)", color: PulseColors.accent)
            KPIBlock(label: "信号数", value: "\(signals.count)", color: PulseColors.cyan)
            KPIBlock(label: "平均评分", value: avgScore, color: PulseColors.warning)
            KPIBlock(label: "模式", value: "只读", color: colors.textMuted)
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    private var avgScore: String {
        let scores = signals.compactMap { $0.overallScore }
        guard !scores.isEmpty else { return "N/A" }
        return String(format: "%.1f", scores.reduce(0, +) / Double(scores.count))
    }

    // MARK: - 过滤栏
    private var filterBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(colors.textMuted)

            TextField("搜索标的...", text: $filterSymbol)
                .textFieldStyle(.plain)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)

            if !filterSymbol.isEmpty {
                Button { filterSymbol = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
    }

    // MARK: - 信号列表
    private var signalList: some View {
        ScrollView {
            LazyVStack(spacing: PulseSpacing.xs) {
                ForEach(Array(filteredSignals.enumerated()), id: \.element.id) { index, signal in
                    SignalCard(signal: signal)
                        .staggeredAppearance(index: index)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: PulseSpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 80)
                    .shimmer()
            }
        }
        .padding(PulseSpacing.lg)
    }

    private func loadData() async {
        do {
            async let s = client.listAgentSignals()
            async let a = client.listAgentProfiles()
            signals = try await s
            agents = try await a
        } catch { }
        isLoading = false
    }
}

// MARK: - KPI 区块
private struct KPIBlock: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TerminalLabel(text: label)
            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(color)
        }
    }
}

// MARK: - 信号卡片
struct SignalCard: View {
    let signal: AgentSignal
    @Environment(PulseColors.self) private var colors

    var body: some View {
        GlassCard {
            HStack(spacing: PulseSpacing.md) {
                // 左侧：评分
                VStack(spacing: 2) {
                    if let score = signal.overallScore {
                        ZStack {
                            Circle()
                                .stroke(colors.surface, lineWidth: 3)
                                .frame(width: 44, height: 44)

                            Circle()
                                .trim(from: 0, to: score / 5.0)
                                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))

                            Text(String(format: "%.1f", score))
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textPrimary)
                        }
                    }
                }

                // 中间：信号内容
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack(spacing: PulseSpacing.xxs) {
                        Text(signal.symbol)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)

                        Text(signal.market)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)

                        if let dir = signal.direction {
                            BadgeDot(
                                color: dir == "long" ? colors.profit : PulseColors.loss,
                                label: dir.uppercased(),
                                size: .small
                            )
                        }
                    }

                    Text(signal.content)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    HStack(spacing: PulseSpacing.xs) {
                        if let tp = signal.targetPrice {
                            Label("TP: \(formatPrice(tp))", systemImage: "target")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.profit)
                        }
                        if let sl = signal.stopLoss {
                            Label("SL: \(formatPrice(sl))", systemImage: "shield")
                                .font(PulseFonts.micro)
                                .foregroundStyle(PulseColors.loss)
                        }
                    }
                }

                Spacer()

                // 右侧：时间
                VStack(alignment: .trailing, spacing: 2) {
                    Text(signal.source)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    Text(formatDate(signal.createdAt))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 4 { return colors.profit }
        if score >= 3 { return PulseColors.warning }
        return PulseColors.loss
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 { return String(format: "%.0f", price) }
        return String(format: "%.2f", price)
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        let display = DateFormatter()
        display.dateFormat = "MM-dd HH:mm"
        return display.string(from: date)
    }
}
