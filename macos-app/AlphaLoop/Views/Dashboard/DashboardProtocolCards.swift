// DashboardProtocolCards.swift — Protocol 风格 Dashboard 卡片组件
// 严格对照 design-previews-v2/03-protocol.html 的布局结构:
// equity 大卡 / 权益曲线卡 / 运行时·就绪度·风险三卡 / 持仓表 / 双 feed。
// 全部绑定 DashboardViewModel 真实数据。

import SwiftUI
// UI Polish: numeric values use contentTransition for smooth updates

// MARK: - Protocol 卡片容器(VOLT: 炭卡 + 硬边框 + hover 上浮;支持 voltBorder 电光发光)
struct ProtocolCard<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    var padding: CGFloat = 22
    /// VOLT 招牌电光边框 — 加亮边框 + 电光黄发光阴影
    var voltBorder: Bool = false
    @ViewBuilder var content: () -> Content
    @State private var hover = false

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(voltBorder ? PulseColors.accent.opacity(0.4) : (hover ? colors.borderHover : colors.border),
                            lineWidth: voltBorder ? 1 : 1)
            )
            .shadow(color: voltBorder ? PulseColors.accent.opacity(hover ? 0.12 : 0.06) : .clear,
                    radius: voltBorder ? 32 : 0, y: 0)
            .applyShadow(hover ? PulseShadow.elevated(colors) : PulseShadow.card(colors))
            .offset(y: hover ? -3 : 0)
            .animation(PulseAnimation.hoverLift, value: hover)
            .onHover { hover = $0 }
    }
}

// MARK: - 卡片小标题(accent 图标 + mono 标签)
struct ProtocolCardTitle: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseColors.accentText)
            Text(text)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
    }
}

// MARK: - 状态 chip
struct ProtocolChip: View {
    enum Kind { case up, warn, neutral, down }
    let text: String
    var kind: Kind = .neutral
    @Environment(PulseColors.self) private var colors

    private var fg: Color {
        switch kind {
        case .up: return PulseColors.bullish
        case .warn: return PulseColors.warning
        case .down: return PulseColors.bearish
        case .neutral: return colors.textSecondary
        }
    }
    private var bg: Color {
        switch kind {
        case .up: return PulseColors.bullishSoft
        case .warn: return PulseColors.warningSoft
        case .down: return PulseColors.bearishSoft
        case .neutral: return colors.surface
        }
    }
    var body: some View {
        Text(text)
            .font(PulseFonts.body(11.5, .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(bg))
    }
}

// MARK: - ① Equity 大卡(VOLT: 56pt 超大数字 + 电路纹理 + 实心 delta chip)
struct ProtocolEquityCard: View {
    @Environment(PulseColors.self) private var colors
    let account: AccountOverviewResponse?
    let kpis: DashboardKPIsResponse?
    let runtime: RuntimeOverviewResponse?
    let available: Bool
    @State private var animatedEquity: Double = 0

    private var equity: Double { account?.equity ?? 0 }
    private var pnlPct: Double { account?.todayPnlPct ?? kpis?.pnlChangePct ?? 0 }
    private var pnlAbs: Double { kpis?.totalPnl ?? (equity * pnlPct / 100) }
    private var isUp: Bool { pnlPct >= 0 }

    var body: some View {
        ProtocolCard(voltBorder: true) {
            ZStack(alignment: .topTrailing) {
                // 电路纹理(VOLT 招牌装饰)
                CircuitTexture()
                    .offset(x: 20, y: 20)

                VStack(alignment: .leading, spacing: 16) {
                    // 徽章 + delta chip
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(PulseColors.bullish).frame(width: 6, height: 6)
                                .shadow(color: PulseColors.bullish.opacity(0.5), radius: 3)
                            Text(L10n.zh("实盘账户 · ", en: "Live Account · ") + (account?.currency ?? "USDT"))
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textSecondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(colors.surface))

                        Spacer()

                        // VOLT 实心 delta chip(up=实心绿黑字, down=实心红白字)
                        if available {
                            HStack(spacing: 5) {
                                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(isUp ? "+" : "")\(fmt2(pnlPct))% TODAY")
                                    .monospacedDigit()
                            }
                            .font(PulseFonts.mono(11, .semibold))
                            .foregroundStyle(isUp ? PulseColors.onBullish : PulseColors.onBearish)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(isUp ? PulseColors.bullish : PulseColors.bearish))
                        }
                    }

                    // VOLT 56pt 超大权益数字(Archivo 字重 800)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Dashboard.equity)
                            .font(PulseFonts.mono(10, .semibold))
                            .foregroundStyle(colors.textMuted)
                            .textCase(.uppercase)
                            .tracking(1.4)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(available ? fmt2(animatedEquity) : "—")
                                .font(PulseFonts.display(56, .black))
                                .foregroundStyle(colors.textPrimary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(account?.currency ?? "USDT")
                                .font(PulseFonts.display(16, .semibold))
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    // 辅助读数行
                    if available {
                        HStack(spacing: PulseSpacing.md) {
                            miniStat(L10n.zh("今日盈亏", en: "Today P&L"),
                                     "\(isUp ? "+" : "")\(fmt2(pnlAbs))",
                                     isUp ? PulseColors.bullish : PulseColors.bearish)
                            miniStat(L10n.zh("最大回撤", en: "Max DD"),
                                     String(format: "%.2f%%", account?.maxDrawdownPct ?? 0),
                                     PulseColors.bearish)
                            miniStat(L10n.zh("对账中", en: "Reconciling"),
                                     "\(runtime?.reconcilingCount ?? 0)",
                                     colors.textPrimary)
                        }
                    }

                    // 4 子指标
                    HStack(alignment: .top, spacing: 26) {
                        subItem(L10n.zh("活跃策略", en: "Active"), "\(kpis?.activeStrategies ?? runtime?.runningStrategies ?? 0)")
                        subItem(L10n.zh("开放持仓", en: "Positions"), "\(runtime?.openPositions ?? kpis?.openPositions ?? 0)")
                        subItem(L10n.zh("今日成交", en: "Trades"), "\(kpis?.todaysTrades ?? 0)")
                        subItem(L10n.zh("待处理单", en: "Pending"), "\(runtime?.pendingOrders ?? 0)")
                    }
                }
            }
        }
        .task(id: equity) {
            guard available else { return }
            let target = equity
            let steps = 40
            for i in 0...steps {
                let p = Double(i) / Double(steps)
                animatedEquity = target * (1 - pow(1 - p, 3))
                try? await Task.sleep(nanoseconds: 12_000_000)
            }
            animatedEquity = target
        }
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted).textCase(.uppercase).tracking(0.8)
            Text(value).font(PulseFonts.mono(13, .bold)).foregroundStyle(color).monospacedDigit()
        }
    }

    private func subItem(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(PulseFonts.mono(10, .medium)).foregroundStyle(colors.textMuted).textCase(.uppercase).tracking(0.8)
            Text(v).font(PulseFonts.display(19, .bold)).foregroundStyle(colors.textPrimary).monospacedDigit()
        }
    }
    private func fmt2(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "0.00"
    }
}

// MARK: - 电路纹理(VOLT 招牌装饰 — 极淡电光黄线条)
struct CircuitTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let c = PulseColors.accent.opacity(0.07)
            let w: CGFloat = 1
            // 横向主干
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.3, y: 0))
            path.addLine(to: CGPoint(x: size.width * 0.3, y: size.height * 0.4))
            path.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.4))
            path.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.8))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.8))
            ctx.stroke(path, with: .color(c), lineWidth: w)
            // 分支
            var p2 = Path()
            p2.move(to: CGPoint(x: size.width * 0.3, y: size.height * 0.4))
            p2.addLine(to: CGPoint(x: size.width * 0.1, y: size.height * 0.4))
            p2.addLine(to: CGPoint(x: size.width * 0.1, y: size.height * 0.9))
            ctx.stroke(p2, with: .color(c), lineWidth: w)
            // 节点
            for pt in [CGPoint(x: size.width * 0.3, y: size.height * 0.4),
                       CGPoint(x: size.width * 0.7, y: size.height * 0.4),
                       CGPoint(x: size.width * 0.7, y: size.height * 0.8)] {
                let r = CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)
                ctx.fill(Path(ellipseIn: r), with: .color(PulseColors.accent.opacity(0.15)))
            }
        }
        .frame(width: 200, height: 200)
        .allowsHitTesting(false)
    }
}

// MARK: - ③ 运行时卡(VOLT: mono 标签 + 大号数字)
struct ProtocolRuntimeCard: View {
    @Environment(PulseColors.self) private var colors
    let runtime: RuntimeOverviewResponse?
    let kpis: DashboardKPIsResponse?
    let online: Bool
    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ProtocolCardTitle(icon: "clock", text: L10n.zh("运行时", en: "Runtime"))
                    Spacer()
                    ProtocolChip(text: online ? L10n.zh("在线", en: "Online") : L10n.zh("离线", en: "Offline"), kind: online ? .up : .neutral)
                }
                VStack(spacing: 12) {
                    statRow(L10n.zh("活跃策略", en: "Active strategies"), "\(runtime?.runningStrategies ?? kpis?.activeStrategies ?? 0)")
                    statRow(L10n.zh("开放持仓", en: "Open positions"), "\(runtime?.openPositions ?? 0)")
                    statRow(L10n.zh("待处理单", en: "Pending orders"), "\(runtime?.pendingOrders ?? 0)")
                    statRow(L10n.zh("对账中", en: "Reconciling"), "\(runtime?.reconcilingCount ?? 0)")
                }
            }
        }
    }
    private func statRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .font(PulseFonts.mono(10, .medium))
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text(v)
                .font(PulseFonts.display(19, .bold))
                .foregroundStyle(colors.textPrimary)
                .monospacedDigit()
        }
    }
}

// MARK: - ③ 实盘就绪度卡(VOLT: 电光进度条 + 发光效果)
struct ProtocolReadinessCard: View {
    @Environment(PulseColors.self) private var colors
    let readiness: LiveReadinessResponse?
    let available: Bool
    @State private var barWidth: CGFloat = 0

    private var score: Int { readiness?.score ?? 0 }
    private var checks: [ReadinessCheckResponse] { readiness?.checks ?? [] }
    private var passed: Int { checks.filter { $0.status.lowercased() == "pass" || $0.status.lowercased() == "ok" }.count }

    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ProtocolCardTitle(icon: "checkmark.shield", text: L10n.zh("实盘就绪度", en: "Live Readiness"))
                    Spacer()
                    Text("GATE")
                        .font(PulseFonts.mono(10, .semibold))
                        .foregroundStyle(PulseColors.accentText)
                        .textCase(.uppercase)
                        .tracking(1.4)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(available ? "\(score)" : "—")
                        .font(PulseFonts.display(46, .black))
                        .foregroundStyle(PulseColors.accentText)
                        .monospacedDigit()
                    Text("/ 100")
                        .font(PulseFonts.display(14, .semibold))
                        .foregroundStyle(colors.textMuted)
                    if !checks.isEmpty {
                        Spacer()
                        Text("\(passed) / \(checks.count) " + L10n.zh("检查通过", en: "checks"))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                // VOLT 电光进度条(发光效果)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5).fill(colors.surface).frame(height: 10)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(colors: [PulseColors.accentText, PulseColors.bullish], startPoint: .leading, endPoint: .trailing))
                            .frame(width: barWidth, height: 10)
                            .shadow(color: PulseColors.accentText.opacity(0.35), radius: 8)
                    }
                    .onAppear {
                        withAnimation(PulseAnimation.protocolEase) {
                            barWidth = geo.size.width * CGFloat(min(score, 100)) / 100
                        }
                    }
                }
                .frame(height: 10)

                // 检查项(最多 3)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(checks.prefix(3), id: \.key) { ck in
                        let ok = ck.status.lowercased() == "pass" || ck.status.lowercased() == "ok"
                        HStack(spacing: 9) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(ok ? PulseColors.bullish : PulseColors.warning)
                            Text(ck.label)
                                .font(PulseFonts.body(13.5))
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                            Text(ok ? L10n.zh("已通过", en: "passed") : L10n.zh("待确认", en: "pending"))
                                .font(PulseFonts.body(12.5))
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ③ 全局风险卡(VOLT: mono 标签 + 26pt 大号数字 + 2×2 网格)
struct ProtocolRiskCard: View {
    @Environment(PulseColors.self) private var colors
    let risk: RiskOverviewResponse?
    let account: AccountOverviewResponse?
    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ProtocolCardTitle(icon: "shield.lefthalf.filled", text: L10n.zh("全局风险", en: "Global Risk"))
                    Spacer()
                    ProtocolChip(text: (risk?.emergencyLocked ?? false) ? L10n.zh("已锁定", en: "Locked") : L10n.zh("正常", en: "Normal"),
                                 kind: (risk?.emergencyLocked ?? false) ? .down : .neutral)
                }
                let cols = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
                    riskItem(L10n.zh("当前回撤", en: "Drawdown"), fmtPct(account?.maxDrawdownPct ?? 0), .down)
                    riskItem(L10n.zh("日损剩余", en: "Daily left"), fmtPct(risk?.dailyLossRemainingPct ?? 0), .warn)
                    riskItem(L10n.zh("周损剩余", en: "Weekly left"), fmtPct(risk?.weeklyLossRemainingPct ?? 0), .normal)
                    riskItem(L10n.zh("熔断事件", en: "Breakers"), "\(risk?.reasonCodes.count ?? 0)", .normal)
                }
            }
        }
    }
    enum Tone { case down, warn, normal }
    private func riskItem(_ k: String, _ v: String, _ tone: Tone) -> some View {
        let color: Color = tone == .down ? PulseColors.bearish : tone == .warn ? PulseColors.warning : colors.textPrimary
        return VStack(alignment: .leading, spacing: 4) {
            Text(k)
                .font(PulseFonts.mono(10, .medium))
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(v)
                .font(PulseFonts.display(26, .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
    private func fmtPct(_ v: Double) -> String { String(format: "%.2f%%", v) }
}

// MARK: - ② 权益曲线卡(tabs + 平滑品牌色面积曲线)
struct ProtocolEquityCurveCard: View {
    @Environment(PulseColors.self) private var colors
    let points: [EquityPoint]
    let available: Bool
    @State private var selectedRange = 30
    @State private var drawProgress: CGFloat = 0
    private let ranges = [7, 30, 90]

    private var filtered: [EquityPoint] {
        selectedRange >= points.count ? points : Array(points.suffix(selectedRange))
    }

    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ProtocolCardTitle(icon: "chart.line.uptrend.xyaxis", text: L10n.zh("权益曲线", en: "Equity Curve"))
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(ranges, id: \.self) { r in
                            let on = selectedRange == r
                            Text("\(r)D")
                                .font(PulseFonts.body(12.5, .semibold))
                                .foregroundStyle(on ? PulseColors.accentText : colors.textSecondary)
                                .padding(.horizontal, 11).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(on ? PulseColors.accentSoft : .clear))
                                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { selectedRange = r } }
                        }
                    }
                }

                if available && filtered.count >= 2 {
                    GeometryReader { geo in
                        curve(in: geo.size)
                    }
                    .frame(height: 210)
                    .padding(.top, 8)
                    .task(id: selectedRange) {
                        drawProgress = 0
                        withAnimation(PulseAnimation.drawIn) { drawProgress = 1 }
                    }

                    HStack {
                        Text(filtered.first?.date ?? "").font(PulseFonts.body(11.5)).foregroundStyle(colors.textSecondary)
                        Spacer()
                        Text(L10n.zh("今日", en: "Today")).font(PulseFonts.body(11.5)).foregroundStyle(colors.textSecondary)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(colors.surface)
                        .frame(height: 210)
                        .overlay(Text(L10n.zh("暂无曲线数据", en: "No curve data")).font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary))
                        .padding(.top, 8)
                }
            }
        }
    }

    private func curvePoints(in size: CGSize) -> [CGPoint] {
        let vals = filtered.map(\.value)
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 1
        let span = max(maxV - minV, 0.0001)
        let pad: CGFloat = 8
        let h = size.height
        let w = size.width
        return (0..<vals.count).map { i in
            let x = w * CGFloat(i) / CGFloat(max(vals.count - 1, 1))
            let y = h - pad - CGFloat((vals[i] - minV) / span) * (h - pad * 2)
            return CGPoint(x: x, y: y)
        }
    }

    @ViewBuilder
    private func curve(in size: CGSize) -> some View {
        let h = size.height
        let w = size.width
        let pts = curvePoints(in: size)

        ZStack {
            // 网格线
            ForEach([0.25, 0.5, 0.75], id: \.self) { f in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * f)); p.addLine(to: CGPoint(x: w, y: h * f))
                }.stroke(colors.border, lineWidth: 1)
            }
            // 面积填充
            smoothPath(pts, closed: true, height: h)
                .fill(LinearGradient(colors: [PulseColors.accent.opacity(0.20), PulseColors.accent.opacity(0.0)],
                                     startPoint: .top, endPoint: .bottom))
                .opacity(drawProgress)
            // 描边线
            smoothPath(pts, closed: false, height: h)
                .trim(from: 0, to: drawProgress)
                .stroke(PulseColors.accentText, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            // 末端点
            if let last = pts.last {
                Circle().fill(PulseColors.accentText)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(colors.cardBackground, lineWidth: 2.5))
                    .position(last)
                    .opacity(drawProgress > 0.9 ? 1 : 0)
            }
        }
    }

    private func smoothPath(_ pts: [CGPoint], closed: Bool, height: CGFloat) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for i in 1..<pts.count {
                let p0 = pts[i-1], p1 = pts[i]
                let cx = (p0.x + p1.x) / 2
                p.addCurve(to: p1, control1: CGPoint(x: cx, y: p0.y), control2: CGPoint(x: cx, y: p1.y))
            }
            if closed, let last = pts.last, let first = pts.first {
                p.addLine(to: CGPoint(x: last.x, y: height))
                p.addLine(to: CGPoint(x: first.x, y: height))
                p.closeSubpath()
            }
        }
    }
}

// MARK: - feed 行(VOLT: mono 时间 + 标签芯片 + 紧凑布局)
private struct ProtocolFeedRow: View {
    @Environment(PulseColors.self) private var colors
    enum Tone { case accent, up, warn, down }
    let icon: String
    let tone: Tone
    let title: String
    let detail: String
    var tags: [String] = []
    var time: String = ""

    private var fg: Color {
        switch tone { case .accent: return PulseColors.accent; case .up: return PulseColors.bullish
        case .warn: return PulseColors.warning; case .down: return PulseColors.bearish }
    }
    private var bg: Color {
        switch tone { case .accent: return PulseColors.accentSoft; case .up: return PulseColors.bullishSoft
        case .warn: return PulseColors.warningSoft; case .down: return PulseColors.bearishSoft }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 10).fill(bg)
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(fg))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(PulseFonts.body(14, .semibold)).foregroundStyle(colors.textPrimary)
                    if !time.isEmpty {
                        Text(time)
                            .font(PulseFonts.mono(10, .medium))
                            .foregroundStyle(colors.textMuted)
                    }
                }
                Text(detail).font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary).lineLimit(2)
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { t in
                            Text(t)
                                .font(PulseFonts.mono(9, .medium))
                                .foregroundStyle(colors.textMuted)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(colors.surface))
                        }
                    }
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - ⑤ AI 决策流 feed
struct ProtocolDecisionFeed: View {
    @Environment(PulseColors.self) private var colors
    let decisions: [RecentDecisionResponse]
    let signals: [DashboardSignalRef]
    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 0) {
                ProtocolCardTitle(icon: "sparkles", text: L10n.zh("AI 决策流", en: "AI Decision Stream"))
                    .padding(.bottom, 6)
                if signals.isEmpty && decisions.isEmpty {
                    emptyRow
                } else {
                    ForEach(Array(signals.prefix(4).enumerated()), id: \.element.id) { idx, s in
                        if idx > 0 { Divider().overlay(colors.border) }
                        ProtocolFeedRow(
                            icon: (s.direction?.lowercased() == "short") ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis",
                            tone: (s.direction?.lowercased() == "short") ? .down : .up,
                            title: "\(s.symbol) · \(s.rating ?? s.direction ?? "")",
                            detail: s.content,
                            tags: [s.overallScore.map { String(format: "%@ %.2f", L10n.zh("评分", en: "score"), $0) } ?? "",
                                   s.sourceAgent ?? ""].filter { !$0.isEmpty },
                            time: shortTime(s.createdAt)
                        )
                    }
                }
            }
        }
    }
    private var emptyRow: some View {
        Text(L10n.zh("暂无决策数据", en: "No decisions yet"))
            .font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary)
            .padding(.vertical, 20)
    }
    private func shortTime(_ iso: String) -> String {
        String(iso.suffix(8).prefix(5))
    }
}

// MARK: - ⑤ 风险告警 feed
struct ProtocolAlertFeed: View {
    @Environment(PulseColors.self) private var colors
    let alerts: [AlertResponse]
    var body: some View {
        ProtocolCard {
            VStack(alignment: .leading, spacing: 0) {
                ProtocolCardTitle(icon: "exclamationmark.triangle", text: L10n.zh("风险告警", en: "Risk Alerts"))
                    .padding(.bottom, 6)
                if alerts.isEmpty {
                    Text(L10n.zh("暂无告警", en: "No alerts"))
                        .font(PulseFonts.body(13)).foregroundStyle(colors.textSecondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(alerts.prefix(4).enumerated()), id: \.offset) { idx, a in
                        if idx > 0 { Divider().overlay(colors.border) }
                        ProtocolFeedRow(
                            icon: iconFor(a.level),
                            tone: toneFor(a.level),
                            title: a.title,
                            detail: a.symbol,
                            time: a.time.map { String($0.suffix(8).prefix(5)) } ?? ""
                        )
                    }
                }
            }
        }
    }
    private func iconFor(_ l: String) -> String {
        switch l.lowercased() { case "critical", "error", "danger": return "chart.line.downtrend.xyaxis"
        case "warning", "warn": return "exclamationmark.circle"; default: return "checkmark.circle" }
    }
    private func toneFor(_ l: String) -> ProtocolFeedRow.Tone {
        switch l.lowercased() { case "critical", "error", "danger": return .down
        case "warning", "warn": return .warn; default: return .up }
    }
}

