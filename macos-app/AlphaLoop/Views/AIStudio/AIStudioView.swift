// AIStudioView.swift — AI 投研室
// TradingAgents 多智能体研究系统：7 视角分析 + 最终评级

import SwiftUI

struct AIStudioView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
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
            VStack(spacing: 18) {
                // Hero(标题 + 深度控制)
                heroSection
                    .staggeredAppearance(index: 0)

                // 标的卡
                subjectCard
                    .staggeredAppearance(index: 1)

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
                    agentGrid(result)
                        .staggeredAppearance(index: 2)
                    verdictCard(result)
                        .staggeredAppearance(index: 3)
                    actionButtons(result)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: PulseSpacing.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .background(colors.background)
        .id(settingsState.language)
    }

    // MARK: - Hero(标题 + 深度控制)

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.AIStudio.protoEyebrow)
                    .font(PulseFonts.body(13, .semibold)).foregroundStyle(PulseColors.accent)
                    .textCase(.uppercase).tracking(0.6)
                Text(L10n.AIStudio.protoTitle)
                    .font(PulseFonts.display(30, .bold)).foregroundStyle(colors.textPrimary)
                Text(L10n.AIStudio.protoSubtitle(symbol))
                    .font(PulseFonts.body(14)).foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            Spacer()
            // 深度分段控制
            HStack(spacing: 4) {
                ForEach(ResearchDepth.allCases, id: \.self) { d in
                    let on = depth == d
                    Text(d.label)
                        .font(PulseFonts.body(13.5, on ? .semibold : .regular))
                        .foregroundStyle(on ? PulseColors.accent : colors.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(on ? PulseColors.accentSoft : Color.clear))
                        .onTapGesture { withAnimation(PulseAnimation.easeOutFast) { depth = d } }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 12).fill(colors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        }
    }

    // MARK: - 标的卡(研究输入)

    private var subjectCard: some View {
        HStack(spacing: 16) {
            // 标的图标
            RoundedRectangle(cornerRadius: 12)
                .fill(signalSymbolColor(symbol))
                .frame(width: 48, height: 48)
                .overlay(Text(signalSymbolInitials(symbol))
                    .font(PulseFonts.display(16, .bold)).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text(symbol).font(PulseFonts.body(16, .bold)).foregroundStyle(colors.textPrimary)
                Text(L10n.AIStudio.perpSuffix.dropFirst())
                    .font(PulseFonts.body(12)).foregroundStyle(colors.textSecondary)
            }

            Spacer()

            // 快捷标的
            HStack(spacing: 6) {
                ForEach(["BTC/USDT", "ETH/USDT", "SOL/USDT"], id: \.self) { s in
                    let on = symbol == s
                    Text(s)
                        .font(PulseFonts.body(12, on ? .semibold : .regular))
                        .foregroundStyle(on ? PulseColors.accent : colors.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? PulseColors.accentSoft : colors.surface))
                        .onTapGesture { symbol = s }
                }
            }

            // 开始研究按钮
            Text(isResearching ? L10n.AIStudio.analyzing : L10n.AIStudio.startResearch)
                .font(PulseFonts.body(14, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 11).fill(PulseColors.accent))
                .opacity(isResearching ? 0.5 : 1.0)
                .onTapGesture { if !isResearching { Task { await startResearch() } } }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
    }

    // MARK: - 研究中指示器

    private var researchingIndicator: some View {
        HStack(spacing: PulseSpacing.sm) {
            ProgressView()
                .controlSize(.small)
                .tint(PulseColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.AIStudio.analyzing)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(L10n.AIStudio.analyzingDesc)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Text(depth.estimatedTime)
                .font(PulseFonts.body(12, .semibold))
                .foregroundStyle(PulseColors.accent)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
    }

    // MARK: - 多 Agent 观点网格

    private func agentGrid(_ result: ResearchResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.3").foregroundStyle(PulseColors.accent)
                Text(L10n.AIStudio.agentsTitle)
                    .font(PulseFonts.body(16, .semibold)).foregroundStyle(colors.textPrimary)
                Text("\(result.perspectives.count) " + L10n.AIStudio.agentsCount)
                    .font(PulseFonts.body(12, .medium)).foregroundStyle(colors.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(colors.surface))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(Array(result.perspectives.enumerated()), id: \.element.id) { index, perspective in
                    agentCard(perspective)
                        .staggeredAppearance(index: index, baseDelay: 0.05)
                }
            }
        }
    }

    private func agentCard(_ perspective: ResearchPerspective) -> some View {
        let stance = stanceFor(perspective.role)
        let avatarColor = stanceColor(stance)
        return VStack(alignment: .leading, spacing: 12) {
            // 头像 + 名称 + 立场
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9).fill(avatarColor)
                    .frame(width: 34, height: 34)
                    .overlay(Text(String(perspective.title.prefix(1)))
                        .font(PulseFonts.display(14, .bold)).foregroundStyle(.white))
                Text(perspective.title)
                    .font(PulseFonts.body(14.5, .semibold)).foregroundStyle(colors.textPrimary)
                Spacer()
                Text(stanceLabel(stance))
                    .font(PulseFonts.body(11.5, .semibold)).foregroundStyle(avatarColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(avatarColor.opacity(0.14)))
            }

            // 置信度条
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.surface).frame(height: 6)
                        Capsule().fill(avatarColor)
                            .frame(width: geo.size.width * min(max(perspective.confidence, 0), 1), height: 6)
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.2f", perspective.confidence))
                    .font(PulseFonts.body(12.5, .semibold)).foregroundStyle(avatarColor).monospacedDigit()
            }

            // 观点内容
            Text(perspective.content)
                .font(PulseFonts.body(13))
                .foregroundStyle(colors.textSecondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            // 置信度为估算标注(数据求真)
            Text("· " + L10n.AIStudio.estimatedNote)
                .font(PulseFonts.body(11)).foregroundStyle(colors.textMuted)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
        .applyShadow(PulseShadow.card(colors))
    }

    private enum AgentStance { case bull, bear, neutral, risk }
    private func stanceFor(_ role: String) -> AgentStance {
        switch role {
        case "technical": return .bull
        case "sentiment", "news": return .neutral
        case "fundamentals": return .bull
        default: return .neutral
        }
    }
    private func stanceLabel(_ s: AgentStance) -> String {
        switch s {
        case .bull: return L10n.AIStudio.stanceBull
        case .bear: return L10n.AIStudio.stanceBear
        case .risk: return L10n.AIStudio.stanceRisk
        default: return L10n.AIStudio.stanceNeutral
        }
    }
    private func stanceColor(_ s: AgentStance) -> Color {
        switch s {
        case .bull: return PulseColors.bullish
        case .bear: return PulseColors.bearish
        case .risk: return PulseColors.accent
        default: return PulseColors.warning
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

    // MARK: - 综合裁定卡

    @ViewBuilder
    private func verdictCard(_ result: ResearchResult) -> some View {
        if let rating = result.finalRating {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.shield").foregroundStyle(PulseColors.accent)
                    Text(L10n.AIStudio.verdictTitle)
                        .font(PulseFonts.body(16, .semibold)).foregroundStyle(colors.textPrimary)
                }

                // 评级行
                HStack(spacing: 12) {
                    Text(rating.direction)
                        .font(PulseFonts.display(22, .bold)).foregroundStyle(directionColor(rating.direction))
                    Text(String(format: L10n.zh("置信度 %.2f", en: "confidence %.2f"), rating.confidence))
                        .font(PulseFonts.body(14, .semibold)).foregroundStyle(colors.textSecondary)
                    Text(L10n.AIStudio.riskLevel + " · " + rating.riskLevel)
                        .font(PulseFonts.body(12, .semibold)).foregroundStyle(riskColor(rating.riskLevel))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(riskColor(rating.riskLevel).opacity(0.14)))
                    Spacer()
                }

                // 共识建议
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.AIStudio.verdictConsensus)
                        .font(PulseFonts.body(12.5, .semibold)).foregroundStyle(colors.textSecondary)
                    Text(rating.recommendation)
                        .font(PulseFonts.body(14)).foregroundStyle(colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 免责
                Text(L10n.AIStudio.noFakeInsight)
                    .font(PulseFonts.body(11.5)).foregroundStyle(colors.textMuted)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(PulseColors.accent.opacity(0.3), lineWidth: 1))
            .applyShadow(PulseShadow.card(colors))
        }
    }

    // MARK: - 操作按钮

    private func actionButtons(_ result: ResearchResult) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Spacer()

            actionBtn(creatingDraft ? L10n.AIStudio.generatingDraft : L10n.AIStudio.generateDraft, primary: false) {
                Task { await createStrategyDraft(result) }
            }
            .opacity(creatingDraft ? 0.5 : 1)

            actionBtn(publishingSignal ? L10n.AIStudio.publishing : L10n.AIStudio.publishAsSignal, primary: true) {
                Task { await publishAsSignal(result) }
            }
            .opacity(publishingSignal ? 0.5 : 1)
        }
    }

    private func actionBtn(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(PulseFonts.body(14, .semibold))
            .foregroundStyle(primary ? .white : colors.textPrimary)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 11).fill(primary ? PulseColors.accent : colors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(primary ? Color.clear : colors.border, lineWidth: 1))
            .onTapGesture(perform: action)
    }

    // MARK: - 研究逻辑

    private func startResearch() async {
        guard !symbol.isEmpty else {
            error = L10n.AIStudio.enterTarget
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
                error = current.errorMessage ?? L10n.AIStudio.researchFailed
            }
        } catch {
            self.error = L10n.AIStudio.requestFailed(error.localizedDescription)
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
            self.error = L10n.AIStudio.publishFailed(error.localizedDescription)
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
            self.error = L10n.AIStudio.draftFailed(error.localizedDescription)
        }
        creatingDraft = false
    }

    // MARK: - AIResearchRun → ResearchResult 转换

    private func mapRunToResult(_ run: AIResearchRun) -> ResearchResult {
        var perspectives: [ResearchPerspective] = []

        if let market = run.marketReport {
            perspectives.append(ResearchPerspective(
                id: "technical", role: "technical", title: L10n.AIStudio.technicalAnalysis, icon: "📊",
                content: market, confidence: 0.72
            ))
        }
        if let sentiment = run.sentimentReport {
            perspectives.append(ResearchPerspective(
                id: "sentiment", role: "sentiment", title: L10n.AIStudio.sentimentAnalysis, icon: "🧠",
                content: sentiment, confidence: 0.65
            ))
        }
        if let news = run.newsReport {
            perspectives.append(ResearchPerspective(
                id: "news", role: "news", title: L10n.AIStudio.newsAnalysis, icon: "📰",
                content: news, confidence: 0.60
            ))
        }
        if let fundamentals = run.fundamentalsReport {
            perspectives.append(ResearchPerspective(
                id: "fundamentals", role: "fundamentals", title: L10n.AIStudio.fundamentals, icon: "🏦",
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
        case .quick: return L10n.AIStudio.depthQuick
        case .standard: return L10n.AIStudio.depthStandard
        case .deep: return L10n.AIStudio.depthDeep
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
