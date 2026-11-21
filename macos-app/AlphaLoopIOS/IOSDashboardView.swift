import SwiftUI

struct IOSDashboardView: View {
    let client: LiveNetworkClient
    let onLogout: () -> Void

    @State private var viewModel: DashboardViewModel
    @State private var refreshID = UUID()

    init(client: LiveNetworkClient, onLogout: @escaping () -> Void) {
        self.client = client
        self.onLogout = onLogout
        _viewModel = State(initialValue: DashboardViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IOSTheme.backgroundView
                if viewModel.isLoading && viewModel.account == nil {
                    ProgressView("加载中…").tint(IOSTheme.accent)
                } else if viewModel.isDataSourceUnavailable && viewModel.account == nil {
                    unavailable
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: refreshID) { await viewModel.load() }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageHeader
                statusStrip
                heroCard
                accountCard
                runtimeCard
                readinessCard
                positionsCard
                if let error = viewModel.error {
                    Text(error).font(IOSTheme.mono).foregroundStyle(IOSTheme.bear)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
        .background(IOSTheme.background)
        .refreshable { await viewModel.refresh() }
    }

    // MARK: Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(IOSTheme.accent)
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(IOSTheme.onAccent))
                    Text("ALPHALOOP").font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("模拟 PAPER")
                        .font(IOSTheme.monoLabel)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(IOSTheme.accent.opacity(0.12))
                        .foregroundStyle(IOSTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Button { Task { await viewModel.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(IOSTheme.accent)
                Button("退出") { onLogout() }
                    .font(IOSTheme.mono)
                    .foregroundStyle(IOSTheme.bear)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("// DESK")
                    .font(IOSTheme.monoLabel)
                    .tracking(1.2)
                    .foregroundStyle(IOSTheme.textMuted)
                Text("总览")
                    .font(IOSTheme.title)
                    .foregroundStyle(IOSTheme.text)
                Text("15 分钟行情、正在跑的模拟，以及还没通过的实盘门禁")
                    .font(IOSTheme.mono)
                    .foregroundStyle(IOSTheme.textSecondary)
            }
        }
    }

    private var statusStrip: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
            alignment: .leading,
            spacing: 8
        ) {
            statusDot("PROVIDER", value: providerLabel, ok: (viewModel.providerHealth?.totalError ?? 0) == 0)
            statusDot("交易所", value: (viewModel.system?.exchangeState ?? "unknown").uppercased(), ok: viewModel.system?.exchangeState == "ok")
            statusDot("缓存", value: viewModel.system.map { "\($0.redisRttMs)ms" } ?? "—", ok: (viewModel.system?.redisRttMs ?? 999) < 100)
            statusDot("交易引擎", value: (viewModel.system?.freqtradeState ?? "unknown").uppercased(), ok: viewModel.system?.freqtradeState == "ok")
            statusDot("风险", value: (viewModel.risk?.globalState ?? "unknown").uppercased(), ok: viewModel.risk?.globalState == "normal")
            statusDot("持仓", value: "\(viewModel.positions.count)", ok: true)
        }
    }

    private func statusDot(_ label: String, value: String, ok: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(ok ? IOSTheme.bull : IOSTheme.bear).frame(width: 5, height: 5)
            Text(label).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textMuted)
            Text(value).font(IOSTheme.monoLabel).foregroundStyle(ok ? IOSTheme.textSecondary : IOSTheme.bear)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    // MARK: Cards

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    IOSSectionLabel(text: "ACCOUNT EQUITY")
                    Text(viewModel.account?.currency ?? "USDT")
                        .font(IOSTheme.monoLabel)
                        .foregroundStyle(IOSTheme.textMuted)
                    Text(money(viewModel.account?.equity))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(IOSTheme.text)
                    HStack(spacing: 14) {
                        pnl("今日", viewModel.account?.todayPnlPct)
                        pnl("本周", viewModel.account?.weekPnlPct)
                        pnl("回撤", viewModel.account?.maxDrawdownPct)
                    }
                }
                Spacer()
                Text(lastUpdatedText)
                    .font(IOSTheme.monoLabel)
                    .foregroundStyle(IOSTheme.textMuted)
            }
            .padding(18)

            Divider().overlay(IOSTheme.border)

            if viewModel.equityCurve.count > 1 {
                sparkline
                    .frame(height: 110)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(IOSTheme.textMuted)
                    Text("K 线没有取到，刷新页面再试。")
                        .font(IOSTheme.mono)
                        .foregroundStyle(IOSTheme.textSecondary)
                    Spacer()
                }
                .frame(height: 90)
                .padding(.horizontal, 18)
            }
        }
        .background(IOSTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(IOSTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let values = viewModel.equityCurve.map(\.value)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(maxV - minV, 0.0001)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((value - minV) / span))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(IOSTheme.accent, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height))
                for (index, value) in values.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((value - minV) / span))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [IOSTheme.accent.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            let engineOK = viewModel.system?.freqtradeState == "ok"
            cardHeader("账户", trailing: engineOK ? "运行中" : "未连接", bad: !engineOK)
            VStack(spacing: 0) {
                statRow("估值", money(viewModel.account?.equity))
                statRow("持仓", "\(viewModel.runtime?.openPositions ?? viewModel.positions.count)")
                statRow("已平仓", "\(viewModel.runtime?.reconcilingCount ?? 0)")
                statRow("Sharpe", viewModel.account?.sharpeRatio.map { String(format: "%.2f", $0) } ?? "—")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .iosCard()
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("运行状态", trailing: viewModel.state.uppercased(), bad: viewModel.state != "healthy")
            HStack(spacing: 8) {
                metric("策略", viewModel.runtime?.runningStrategies ?? 0)
                metric("持仓", viewModel.runtime?.openPositions ?? 0)
                metric("挂单", viewModel.runtime?.pendingOrders ?? 0)
                metric("对账", viewModel.runtime?.reconcilingCount ?? 0)
            }
        }
        .iosCard()
    }

    private var readinessCard: some View {
        let failed = (viewModel.liveReadiness?.checks ?? []).filter { $0.status == "failed" || $0.status == "warning" }
        let canStart = viewModel.liveReadiness?.canStartLiveSmall ?? false
        return VStack(alignment: .leading, spacing: 0) {
            cardHeader("实盘门禁", trailing: canStart ? "可以启动" : "未通过", bad: !canStart)
            if failed.isEmpty {
                Text(viewModel.liveReadiness == nil ? "门禁数据不可用" : "没有未通过的检查。")
                    .font(IOSTheme.mono).foregroundStyle(IOSTheme.textSecondary)
                    .padding(18)
            } else {
                ForEach(failed.prefix(5)) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(check.status == "failed" ? IOSTheme.bear : IOSTheme.warning).frame(width: 5, height: 5).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.label).font(IOSTheme.mono).foregroundStyle(IOSTheme.text)
                            if !check.detail.isEmpty {
                                Text(check.detail).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textMuted)
                            }
                        }
                        Spacer()
                        Text(check.value).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    if check.id != failed.prefix(5).last?.id { Divider().overlay(IOSTheme.border) }
                }
            }
        }
        .iosCard()
    }

    private var positionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("持仓", trailing: "\(viewModel.positions.count)", bad: false)
            if viewModel.positions.isEmpty {
                Text("没有持仓。")
                    .font(IOSTheme.mono).foregroundStyle(IOSTheme.textSecondary)
                    .padding(18)
            } else {
                ForEach(viewModel.positions) { position in
                    HStack(spacing: 10) {
                        Text(position.symbol).font(IOSTheme.mono).foregroundStyle(IOSTheme.text)
                        Text(position.isLong ? "LONG" : "SHORT")
                            .font(IOSTheme.monoLabel)
                            .foregroundStyle(position.isLong ? IOSTheme.bull : IOSTheme.bear)
                        Spacer()
                        Text(String(format: "%.4f", position.size)).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textSecondary)
                        Text("\(position.pnl >= 0 ? "+" : "")\(String(format: "%.2f", position.pnl))")
                            .font(IOSTheme.mono)
                            .foregroundStyle(position.pnl >= 0 ? IOSTheme.bull : IOSTheme.bear)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    if position.id != viewModel.positions.last?.id { Divider().overlay(IOSTheme.border) }
                }
            }
        }
        .iosCard()
    }

    // MARK: Helpers

    private var unavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(IOSTheme.warning)
            Text("数据源不可用").font(IOSTheme.title).foregroundStyle(IOSTheme.text)
            Text(viewModel.reasonCodes.joined(separator: ", ")).font(IOSTheme.mono).foregroundStyle(IOSTheme.textMuted)
        }
    }

    private var providerLabel: String {
        guard let health = viewModel.providerHealth else { return "—" }
        if health.totalError > 0 { return "\(health.totalError) ERR" }
        return "\(health.totalActive) OK"
    }

    private var lastUpdatedText: String {
        guard let date = viewModel.lastUpdated else { return "" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private func cardHeader(_ title: String, trailing: String, bad: Bool) -> some View {
        HStack {
            IOSSectionLabel(text: title)
            Spacer()
            Text(trailing)
                .font(IOSTheme.monoLabel)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background((bad ? IOSTheme.bear : IOSTheme.bull).opacity(0.12))
                .foregroundStyle(bad ? IOSTheme.bear : IOSTheme.bull)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(IOSTheme.border).frame(height: 1) }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(IOSTheme.mono).foregroundStyle(IOSTheme.textSecondary)
            Spacer()
            Text(value).font(IOSTheme.mono).foregroundStyle(IOSTheme.text)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(IOSTheme.border.opacity(0.6)).frame(height: 1) }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textMuted)
            Text("\(value)").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundStyle(IOSTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pnl(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(IOSTheme.monoLabel).foregroundStyle(IOSTheme.textMuted)
            Text(value.map { String(format: "%+.2f%%", $0) } ?? "—")
                .font(IOSTheme.mono)
                .foregroundStyle((value ?? 0) < 0 ? IOSTheme.bear : IOSTheme.bull)
        }
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}
