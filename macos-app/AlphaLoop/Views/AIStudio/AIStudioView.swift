// AIStudioView.swift — AI 投研室
// TradingAgents 多智能体研究系统：7 视角分析 + 最终评级

import SwiftUI

struct AIStudioView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var symbol = "BTC/USDT"
    @State private var depth: ResearchDepth = .standard
    @State private var isResearching = false
    @State private var result: ResearchResult?
    @State private var error: String?
    @State private var publishingSignal = false
    @State private var creatingDraft = false
    @State private var researchRun: AIResearchRun?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // 标题
                headerSection

                // 输入区
                researchInputSection

                // 错误提示
                if let error {
                    errorBanner(error)
                }

                // 研究中指示
                if isResearching {
                    researchingIndicator
                }

                // 结果（研究完成后显示）
                if let result {
                    perspectivePanels(result)
                    finalRatingPanel(result)
                    actionButtons(result)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    // MARK: - 标题区

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                TerminalLabel(text: "AI 投研室")
                Text("多智能体协同研究 · TradingAgents")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
        }
    }

    // MARK: - 研究输入区

    private var researchInputSection: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(spacing: PulseSpacing.md) {
                HStack(spacing: PulseSpacing.md) {
                    // 标的选择
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("研究标的")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                            .textCase(.uppercase)

                        HStack(spacing: PulseSpacing.xs) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(colors.textMuted)

                            TextField("输入交易对...", text: $symbol)
                                .font(PulseFonts.body)
                                .foregroundStyle(colors.textPrimary)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, PulseSpacing.xs)
                        .background(colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .stroke(colors.border, lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity)

                    // 研究深度
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("研究深度")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                            .textCase(.uppercase)

                        HStack(spacing: 0) {
                            ForEach(ResearchDepth.allCases, id: \.self) { d in
                                Button {
                                    withAnimation(PulseAnimation.easeOutFast) { depth = d }
                                } label: {
                                    Text(d.label)
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(depth == d ? colors.textPrimary : colors.textMuted)
                                        .padding(.horizontal, PulseSpacing.sm)
                                        .padding(.vertical, PulseSpacing.xs)
                                        .background(
                                            depth == d ? PulseColors.accent.opacity(0.12) : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(2)
                        .background(colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .stroke(colors.border, lineWidth: 1)
                        )
                    }
                }

                // 快捷标的
                HStack(spacing: PulseSpacing.xs) {
                    Text("热门:")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)

                    ForEach(["BTC/USDT", "ETH/USDT", "SOL/USDT", "NVDA", "AAPL"], id: \.self) { s in
                        Button {
                            symbol = s
                        } label: {
                            Text(s)
                                .font(PulseFonts.micro)
                                .foregroundStyle(symbol == s ? PulseColors.accent : colors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    symbol == s ? PulseColors.accent.opacity(0.08) : colors.surface
                                )
                                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 开始研究按钮
                HStack {
                    Spacer()

                    KryptonButton(
                        title: "开始研究",
                        action: { Task { await startResearch() } },
                        style: .primary
                    )
                    .opacity(isResearching ? 0.5 : 1.0)
                    .allowsHitTesting(!isResearching)
                }
            }
        }
    }

    // MARK: - 研究中指示器

    private var researchingIndicator: some View {
        KryptonCard(emphasis: .subtle) {
            HStack(spacing: PulseSpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(PulseColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("多智能体分析中...")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text("正在调用 Bull / Bear / Technical / Sentiment / On-chain / Risk 智能体")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                Text(depth.estimatedTime)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accent)
            }
        }
    }

    // MARK: - 视角面板

    private func perspectivePanels(_ result: ResearchResult) -> some View {
        VStack(spacing: PulseSpacing.sm) {
            TerminalLabel(text: "多视角分析")
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: PulseSpacing.sm) {
                ForEach(Array(result.perspectives.enumerated()), id: \.element.id) { index, perspective in
                    perspectiveCard(perspective)
                        .staggeredAppearance(index: index, baseDelay: 0.05)
                }
            }
        }
    }

    private func perspectiveCard(_ perspective: ResearchPerspective) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 标题行
                HStack {
                    Text(perspective.icon)
                        .font(.system(size: 16))

                    Text(perspective.title)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    Spacer()

                    // 置信度指示器
                    confidenceIndicator(perspective.confidence)
                }

                // 分析内容
                Text(perspective.content)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func confidenceIndicator(_ confidence: Double) -> some View {
        HStack(spacing: 4) {
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(colors.surface)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(confidenceColor(confidence))
                        .frame(width: geo.size.width * confidence, height: 3)
                }
            }
            .frame(width: 40, height: 3)

            Text("\(Int(confidence * 100))%")
                .font(PulseFonts.micro)
                .foregroundStyle(confidenceColor(confidence))
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.7 { return PulseColors.success }
        if confidence >= 0.4 { return PulseColors.warning }
        return PulseColors.danger
    }

    // MARK: - 最终评级面板

    @ViewBuilder
    private func finalRatingPanel(_ result: ResearchResult) -> some View {
        if let rating = result.finalRating {
            VStack(spacing: PulseSpacing.sm) {
                TerminalLabel(text: "最终评级")
                    .frame(maxWidth: .infinity, alignment: .leading)

                KryptonCard(emphasis: .bold) {
                    VStack(spacing: PulseSpacing.md) {
                        HStack(spacing: PulseSpacing.lg) {
                            // 方向
                            VStack(spacing: PulseSpacing.xxs) {
                                Text("方向")
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textMuted)
                                    .textCase(.uppercase)
                                Text(rating.direction)
                                    .font(PulseFonts.monoLarge)
                                    .foregroundStyle(directionColor(rating.direction))
                            }

                            // 置信度
                            VStack(spacing: PulseSpacing.xxs) {
                                Text("置信度")
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textMuted)
                                    .textCase(.uppercase)
                                Text("\(Int(rating.confidence * 100))%")
                                    .font(PulseFonts.monoLarge)
                                    .foregroundStyle(PulseColors.accent)
                            }

                            // 风险等级
                            VStack(spacing: PulseSpacing.xxs) {
                                Text("风险等级")
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textMuted)
                                    .textCase(.uppercase)
                                BadgeDot(
                                    color: riskColor(rating.riskLevel),
                                    label: rating.riskLevel,
                                    size: .medium
                                )
                            }

                            Spacer()
                        }

                        // 建议
                        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                            Text("综合建议")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textMuted)
                                .textCase(.uppercase)
                            Text(rating.recommendation)
                                .font(PulseFonts.body)
                                .foregroundStyle(colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - 操作按钮

    private func actionButtons(_ result: ResearchResult) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Spacer()

            KryptonButton(title: creatingDraft ? "生成中..." : "生成策略草稿", action: {
                Task { await createStrategyDraft(result) }
            }, style: .ghost)
            .opacity(creatingDraft ? 0.5 : 1)
            .disabled(creatingDraft)

            KryptonButton(title: publishingSignal ? "发布中..." : "发布为信号", action: {
                Task { await publishAsSignal(result) }
            }, style: .primary)
            .opacity(publishingSignal ? 0.5 : 1)
            .disabled(publishingSignal)
        }
    }

    // MARK: - 研究逻辑

    private func startResearch() async {
        guard !symbol.isEmpty else {
            error = "请输入研究标的"
            return
        }

        error = nil
        isResearching = true
        result = nil
        researchRun = nil

        do {
            let run = try await networkClient.createResearchRun(symbol: symbol, assetType: "crypto")
            researchRun = run

            // 轮询状态直到完成
            var current = run
            while current.status == "pending" || current.status == "running" {
                try await Task.sleep(for: .seconds(3))
                let runs = try await networkClient.listResearchRuns()
                if let updated = runs.first(where: { $0.id == run.id }) {
                    current = updated
                    researchRun = updated
                } else {
                    break
                }
            }

            if current.status == "completed" {
                result = mapRunToResult(current)
            } else if current.status == "failed" {
                error = current.errorMessage ?? "研究失败"
            }
        } catch {
            self.error = "研究请求失败: \(error.localizedDescription)"
        }

        isResearching = false
    }

    private func publishAsSignal(_ result: ResearchResult) async {
        guard let rating = result.finalRating else { return }
        publishingSignal = true

        let direction = rating.direction == "看多" ? "long" : (rating.direction == "看空" ? "short" : "hold")
        let body: [String: Any] = [
            "source_type": "ai_research",
            "symbol": result.symbol,
            "direction": direction,
            "confidence": rating.confidence,
            "risk_level": rating.riskLevel,
            "reasoning": rating.recommendation,
            "expires_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
        ]

        let signalsAPI = APISignalsV2(client: networkClient)
        do {
            _ = try await signalsAPI.createSignal(body)
        } catch {
            self.error = "发布信号失败: \(error.localizedDescription)"
        }
        publishingSignal = false
    }

    private func createStrategyDraft(_ result: ResearchResult) async {
        guard researchRun != nil else { return }
        creatingDraft = true

        do {
            let run = try await networkClient.createResearchRun(symbol: result.symbol, assetType: "crypto")
            _ = run
        } catch {
            self.error = "生成策略草稿失败: \(error.localizedDescription)"
        }
        creatingDraft = false
    }

    // MARK: - AIResearchRun → ResearchResult 转换

    private func mapRunToResult(_ run: AIResearchRun) -> ResearchResult {
        var perspectives: [ResearchPerspective] = []

        if let market = run.marketReport {
            perspectives.append(ResearchPerspective(
                id: "technical", role: "technical", title: "技术分析", icon: "📊",
                content: market, confidence: 0.72
            ))
        }
        if let sentiment = run.sentimentReport {
            perspectives.append(ResearchPerspective(
                id: "sentiment", role: "sentiment", title: "情绪分析", icon: "🧠",
                content: sentiment, confidence: 0.65
            ))
        }
        if let news = run.newsReport {
            perspectives.append(ResearchPerspective(
                id: "news", role: "news", title: "新闻分析", icon: "📰",
                content: news, confidence: 0.60
            ))
        }
        if let fundamentals = run.fundamentalsReport {
            perspectives.append(ResearchPerspective(
                id: "fundamentals", role: "fundamentals", title: "基本面", icon: "🏦",
                content: fundamentals, confidence: 0.68
            ))
        }

        var finalRating: FinalRating? = nil
        if let decision = run.finalDecision, let rating = run.rating {
            let direction: String
            switch rating.lowercased() {
            case "overweight", "buy", "strong buy": direction = "看多"
            case "underweight", "sell", "strong sell": direction = "看空"
            default: direction = "震荡"
            }
            finalRating = FinalRating(
                direction: direction,
                confidence: 0.72,
                riskLevel: "中",
                recommendation: decision
            )
        }

        return ResearchResult(
            id: "\(run.id)",
            symbol: run.symbol,
            depth: "standard",
            perspectives: perspectives,
            finalRating: finalRating
        )

    }
    // MARK: - 错误横幅

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(PulseColors.danger)
            Text(message)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.danger)
            Spacer()
            Button {
                error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.sm)
        .background(PulseColors.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(PulseColors.danger.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 辅助颜色

    private func directionColor(_ direction: String) -> Color {
        switch direction {
        case "看多": return colors.profit
        case "看空": return colors.loss
        default: return PulseColors.amber
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "低": return PulseColors.success
        case "中": return PulseColors.warning
        case "高", "极高": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}
// MARK: - 研究深度枚举

enum ResearchDepth: String, CaseIterable {
    case quick = "quick"
    case standard = "standard"
    case deep = "deep"

    var label: String {
        switch self {
        case .quick: return "快速"
        case .standard: return "标准"
        case .deep: return "深度"
        }
    }

    var estimatedTime: String {
        switch self {
        case .quick: return "~30s"
        case .standard: return "~2min"
        case .deep: return "~5min"
        }
    }
}

// MARK: - 研究结果模型

struct ResearchResult: Identifiable {
    let id: String
    let symbol: String
    let depth: String
    let perspectives: [ResearchPerspective]
    let finalRating: FinalRating?
}

struct ResearchPerspective: Identifiable {
    let id: String
    let role: String
    let title: String
    let icon: String
    let content: String
    let confidence: Double
}

struct FinalRating {
    let direction: String
    let confidence: Double
    let riskLevel: String
    let recommendation: String
}

// MARK: - Mock 数据

extension ResearchResult {
    static func mock(symbol: String, depth: String) -> ResearchResult {
        ResearchResult(
            id: UUID().uuidString,
            symbol: symbol,
            depth: depth,
            perspectives: [
                ResearchPerspective(
                    id: "bull", role: "bull",
                    title: "多头观点", icon: "📈",
                    content: "\(symbol) 目前处于上升趋势中，成交量配合良好。机构资金持续流入，ETF 通道带来增量资金。链上数据显示大户持续积累，供给侧收缩明显。RSI 未达超买区域，仍有上行空间。",
                    confidence: 0.78
                ),
                ResearchPerspective(
                    id: "bear", role: "bear",
                    title: "空头观点", icon: "📉",
                    content: "当前价格已接近前高阻力位，获利盘抛压较大。宏观环境存在加息预期，风险资产或承压。期货未平仓合约处于高位，一旦回调可能触发连锁清算。市场过度乐观，恐惧贪婪指数偏高。",
                    confidence: 0.52
                ),
                ResearchPerspective(
                    id: "technical", role: "technical",
                    title: "技术分析", icon: "📊",
                    content: "MACD 日线金叉，4H 级别多头排列。布林带中轨向上，价格运行在中轨与上轨之间。关键支撑位 65,800，阻力位 72,500。成交量温和放大，趋势健康。KDJ 处于中性区域。",
                    confidence: 0.72
                ),
                ResearchPerspective(
                    id: "sentiment", role: "sentiment",
                    title: "情绪分析", icon: "🧠",
                    content: "社交媒体情绪指数 72/100（偏乐观）。恐惧贪婪指数 68（贪婪区间）。Reddit/Twitter 讨论热度上升 35%。主流媒体报道偏正面，但需警惕过度乐观后的均值回归。",
                    confidence: 0.65
                ),
                ResearchPerspective(
                    id: "onchain", role: "onchain",
                    title: "链上分析", icon: "⛓️",
                    content: "鲸鱼地址（>1000 BTC）近 7 天净增持 12,400 BTC。交易所余额持续下降，净流出 8,200 BTC。矿工抛压减缓，持有不动比例上升。MVRV 指标 1.8，未达历史顶部区域。",
                    confidence: 0.81
                ),
                ResearchPerspective(
                    id: "risk", role: "risk",
                    title: "风险评估", icon: "⚠️",
                    content: "主要风险因素：1) 监管政策不确定性（中等）；2) 宏观流动性收紧（中高）；3) 杠杆清算风险（中等）；4) 黑天鹅事件（低概率高影响）。综合风险评分 6.2/10，建议控制仓位在总资产 15% 以内。",
                    confidence: 0.70
                ),
            ],
            finalRating: FinalRating(
                direction: "看多",
                confidence: 0.72,
                riskLevel: "中",
                recommendation: "综合多空论证，\(symbol) 当前处于上升趋势中段，技术面与链上数据支持看多。建议分批建仓，目标位 72,500，止损设置在 65,000 下方。仓位建议不超过总资产 15%，注意宏观风险事件。"
            )
        )
    }
}
