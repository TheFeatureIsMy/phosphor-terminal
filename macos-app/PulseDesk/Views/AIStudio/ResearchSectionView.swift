// ResearchSectionView.swift — AI 研究委员会视图
// 多智能体投资研究与风险辩论

import SwiftUI

struct ResearchSectionView: View {
    @Environment(\.networkClient) private var client
    @Environment(PulseColors.self) private var colors
    @State private var runs: [AIResearchRun] = []
    @State private var isLoading = true
    @State private var symbol = "BTC/USDT"
    @State private var assetType = "crypto"
    @State private var selectedRun: AIResearchRun?

    var body: some View {
        VStack(spacing: 0) {
            // 输入区
            inputBar

            Divider().foregroundStyle(colors.border)

            // 内容区
            if isLoading {
                loadingView
            } else if runs.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "AI 研究委员会",
                    description: "运行多智能体市场研究，获取风险评估的投资建议"
                )
            } else {
                runsList
            }
        }
        .task { await loadRuns() }
    }

    // MARK: - 输入栏
    private var inputBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            TerminalLabel(text: "研究标的")

            TextField("BTC/USDT, NVDA", text: $symbol)
                .textFieldStyle(.plain)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, PulseSpacing.xs)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(colors.border, lineWidth: 1)
                )

            Picker("", selection: $assetType) {
                Text("加密货币").tag("crypto")
                Text("美股").tag("stock")
                Text("A股").tag("astock")
            }
            .pickerStyle(.menu)
            .darkPicker()
            .frame(width: 100)

            Button {
                Task { await createRun() }
            } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("运行研究")
                        .font(PulseFonts.monoLabel)
                        .textCase(.uppercase)
                }
                .foregroundStyle(colors.background)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(PulseColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
            }
            .buttonStyle(.plain)
            .pressEffect()
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - 研究列表
    private var runsList: some View {
        ScrollView {
            LazyVStack(spacing: PulseSpacing.sm) {
                ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                    ResearchRunCard(run: run)
                        .staggeredAppearance(index: index)
                        .onTapGesture { selectedRun = run }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .sheet(item: $selectedRun) { run in
            ResearchDetailSheet(run: run)
        }
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: PulseSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 120)
                    .shimmer()
            }
        }
        .padding(PulseSpacing.lg)
    }

    private func loadRuns() async {
        do {
            runs = try await client.listResearchRuns()
        } catch { }
        isLoading = false
    }

    private func createRun() async {
        do {
            let newRun = try await client.createResearchRun(symbol: symbol, assetType: assetType)
            runs.insert(newRun, at: 0)
        } catch { }
    }
}

// MARK: - 研究运行卡片
struct ResearchRunCard: View {
    let run: AIResearchRun
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.symbol)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    HStack(spacing: PulseSpacing.xxs) {
                        Text(run.assetType)
                        Text("·")
                        Text(run.analysisDate)
                        Text("·")
                        Text(run.status)
                    }
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                }

                Spacer()

                if let rating = run.rating {
                    BadgeDot(
                        color: ratingColor(rating),
                        label: rating,
                        size: .medium
                    )
                }
            }

            if let decision = run.finalDecision {
                Text(decision)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(3)
            }

            if let error = run.errorMessage {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PulseColors.danger)
                    Text(error)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger)
                }
            }
        }
        .cardStyle()
    }

    private func ratingColor(_ rating: String) -> Color {
        switch rating.lowercased() {
        case "buy", "overweight": return colors.profit
        case "hold": return PulseColors.warning
        case "sell", "underweight": return PulseColors.loss
        default: return colors.textMuted
        }
    }
}

// MARK: - 研究详情 Sheet
struct ResearchDetailSheet: View {
    let run: AIResearchRun
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                GradientText(text: run.symbol, font: PulseFonts.displayHeading)
                Spacer()
                if let rating = run.rating {
                    BadgeDot(color: PulseColors.accent, label: rating, size: .medium)
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(PulseSpacing.lg)

            Divider().foregroundStyle(colors.border)

            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                    if let decision = run.finalDecision {
                        reportSection(title: "最终决策", content: decision, icon: "checkmark.seal")
                    }
                    if let market = run.marketReport {
                        reportSection(title: "市场分析", content: market, icon: "chart.line.uptrend.xyaxis")
                    }
                    if let sentiment = run.sentimentReport {
                        reportSection(title: "情绪分析", content: sentiment, icon: "heart.text.square")
                    }
                    if let news = run.newsReport {
                        reportSection(title: "新闻分析", content: news, icon: "newspaper")
                    }
                    if let fundamentals = run.fundamentalsReport {
                        reportSection(title: "基本面", content: fundamentals, icon: "building.2")
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func reportSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(PulseColors.accent)
                TerminalLabel(text: title)
            }
            Text(content)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
        }
        .cardStyle()
    }
}
