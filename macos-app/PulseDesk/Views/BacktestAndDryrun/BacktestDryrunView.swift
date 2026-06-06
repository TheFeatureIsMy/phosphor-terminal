// BacktestDryrunView.swift — 回测 / 模拟 组合视图
// 两个标签页：回测引擎 + 模拟监控（复用 DryrunMonitorView）

import SwiftUI

struct BacktestDryrunView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var selectedTab = 0  // 0=回测, 1=模拟

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            tabBar

            Divider().foregroundStyle(colors.border)

            // 内容
            Group {
                switch selectedTab {
                case 0: BacktestSectionView()
                case 1: DryrunMonitorView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
    }

    // MARK: - 标签栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: "chart.line.uptrend.xyaxis", title: "回测引擎")
            tabButton(index: 1, icon: "play.circle", title: "模拟监控")

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xs)
    }

    private func tabButton(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedTab = index }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(selectedTab == index ? PulseFonts.bodyMedium : PulseFonts.body)
            }
            .foregroundStyle(selectedTab == index ? PulseColors.accent : colors.textSecondary)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.sm)
            .background(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(selectedTab == index ? PulseColors.accent : .clear)
                        .frame(height: 2)
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.95)
    }
}

// MARK: - 回测区

struct BacktestSectionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var selectedStrategyId: String = ""
    @State private var selectedVersion: Int = 1
    @State private var startDate = "2025-01-01"
    @State private var endDate = "2026-06-01"
    @State private var initialCapital = "100000"
    @State private var symbols = "BTC/USDT"
    @State private var isRunning = false
    @State private var backtestResult: BacktestDisplayResult?
    @State private var recentRuns: [BacktestRunV2] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // 配置区
                backtestConfigSection

                // 运行按钮
                HStack {
                    Spacer()
                    ProofAlphaButton(
                        title: isRunning ? "运行中..." : "启动回测",
                        action: { Task { await runBacktest() } },
                        style: .primary
                    )
                    .opacity(isRunning ? 0.5 : 1.0)
                    .allowsHitTesting(!isRunning)
                }

                // 结果区
                if let result = backtestResult {
                    backtestResultsSection(result)
                }

                // 历史回测
                if !recentRuns.isEmpty {
                    recentRunsSection
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            await loadRecentRuns()
        }
    }

    // MARK: - 配置区

    private var backtestConfigSection: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(spacing: PulseSpacing.md) {
                HStack {
                    TerminalLabel(text: "回测配置")
                    Spacer()
                }

                // 策略 + 版本
                HStack(spacing: PulseSpacing.md) {
                    configField(label: "策略版本", placeholder: "策略 ID", text: $selectedStrategyId)
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("版本号")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                            .textCase(.uppercase)
                        HStack(spacing: PulseSpacing.xs) {
                            Button {
                                if selectedVersion > 1 { selectedVersion -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 10))
                                    .foregroundStyle(colors.textSecondary)
                            }
                            .buttonStyle(.plain)

                            Text("v\(selectedVersion)")
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                                .frame(width: 30)

                            Button {
                                selectedVersion += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .foregroundStyle(colors.textSecondary)
                            }
                            .buttonStyle(.plain)
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
                }

                // 时间范围
                HStack(spacing: PulseSpacing.md) {
                    configField(label: "开始日期", placeholder: "2025-01-01", text: $startDate)
                    configField(label: "结束日期", placeholder: "2026-06-01", text: $endDate)
                }

                // 资金 + 标的
                HStack(spacing: PulseSpacing.md) {
                    configField(label: "初始资金 (USDT)", placeholder: "100000", text: $initialCapital)
                    configField(label: "交易标的", placeholder: "BTC/USDT, ETH/USDT", text: $symbols)
                }
            }
        }
    }

    private func configField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)

            TextField(placeholder, text: text)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .textFieldStyle(.plain)
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
    }

    // MARK: - 结果区

    private func backtestResultsSection(_ result: BacktestDisplayResult) -> some View {
        VStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: "回测结果")
                .frame(maxWidth: .infinity, alignment: .leading)

            // KPI 网格
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: PulseSpacing.sm) {
                kpiCard(title: "总收益率", value: "\(String(format: "%.2f", result.totalReturn))%", color: result.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
                kpiCard(title: "Sharpe 比率", value: "\(String(format: "%.2f", result.sharpeRatio))", color: result.sharpeRatio >= 1.5 ? PulseColors.success : PulseColors.warning)
                kpiCard(title: "最大回撤", value: "\(String(format: "%.2f", result.maxDrawdown))%", color: PulseColors.danger)
                kpiCard(title: "胜率", value: "\(String(format: "%.1f", result.winRate))%", color: result.winRate >= 50 ? PulseColors.success : PulseColors.warning)
                kpiCard(title: "盈亏比", value: "\(String(format: "%.2f", result.profitFactor))", color: result.profitFactor >= 1.5 ? PulseColors.success : colors.textSecondary)
                kpiCard(title: "总交易数", value: "\(result.totalTrades)", color: PulseColors.info)
            }

            // 权益曲线（简化表示）
            equityCurveSection(result)

            // 交易列表
            tradeListSection(result)
        }
    }

    private func kpiCard(title: String, value: String, color: Color) -> some View {
        ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(title)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func equityCurveSection(_ result: BacktestDisplayResult) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    Text("权益曲线")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Text("初始: \(String(format: "%.0f", result.initialCapital)) → 终值: \(String(format: "%.0f", result.finalEquity)) USDT")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                // 简化的权益曲线条形图
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(result.equityPoints.enumerated()), id: \.offset) { _, point in
                        let normalizedHeight = max(0.1, (point - result.initialCapital) / (result.finalEquity - result.initialCapital + 1))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(point >= result.initialCapital ? PulseColors.success.opacity(0.6) : PulseColors.danger.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 4)
                            .frame(height: max(4, CGFloat(normalizedHeight) * 60))
                    }
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }
        }
    }

    private func tradeListSection(_ result: BacktestDisplayResult) -> some View {
        ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    Text("最近交易")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Text("共 \(result.totalTrades) 笔")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                // 表头
                HStack(spacing: 0) {
                    Text("时间")
                        .frame(width: 100, alignment: .leading)
                    Text("方向")
                        .frame(width: 50, alignment: .center)
                    Text("价格")
                        .frame(width: 80, alignment: .trailing)
                    Text("数量")
                        .frame(width: 70, alignment: .trailing)
                    Text("盈亏")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .padding(.vertical, 2)

                Divider().foregroundStyle(colors.border)

                ForEach(Array(result.trades.prefix(8).enumerated()), id: \.offset) { _, trade in
                    HStack(spacing: 0) {
                        Text(trade.time)
                            .frame(width: 100, alignment: .leading)
                            .foregroundStyle(colors.textSecondary)
                        Text(trade.side)
                            .frame(width: 50, alignment: .center)
                            .foregroundStyle(trade.side == "买入" ? PulseColors.success : PulseColors.danger)
                        Text("\(String(format: "%.2f", trade.price))")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundStyle(colors.textPrimary)
                        Text("\(String(format: "%.4f", trade.quantity))")
                            .frame(width: 70, alignment: .trailing)
                            .foregroundStyle(colors.textSecondary)
                        Text("\(trade.pnl >= 0 ? "+" : "")\(String(format: "%.2f", trade.pnl))")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundStyle(trade.pnl >= 0 ? PulseColors.success : PulseColors.danger)
                    }
                    .font(PulseFonts.caption)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 历史回测

    private var recentRunsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "历史回测")

            VStack(spacing: PulseSpacing.xs) {
                ForEach(recentRuns) { run in
                    ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                        HStack(spacing: PulseSpacing.md) {
                            // 状态
                            Circle()
                                .fill(run.status == "completed" ? PulseColors.success : PulseColors.warning)
                                .frame(width: 6, height: 6)

                            // 信息
                            VStack(alignment: .leading, spacing: 1) {
                                Text(run.symbols.joined(separator: ", "))
                                    .font(PulseFonts.captionMedium)
                                    .foregroundStyle(colors.textPrimary)
                                Text("\(run.startDate) → \(run.endDate)")
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                            }

                            Spacer()

                            // 指标
                            HStack(spacing: PulseSpacing.md) {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("收益")
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(colors.textMuted)
                                    Text("\(String(format: "%.1f", run.totalReturn))%")
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
                                }
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("Sharpe")
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(colors.textMuted)
                                    Text("\(String(format: "%.2f", run.sharpeRatio))")
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(colors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 逻辑

    private func runBacktest() async {
        guard !selectedStrategyId.isEmpty else { return }
        isRunning = true
        backtestResult = nil

        do {
            let api = APIStrategiesV2(client: networkClient)
            let symbolsArray = symbols.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            let response = try await api.startBacktest(
                dsl: [:],
                timerange: "\(startDate)-\(endDate)",
                symbols: symbolsArray,
                initialCapital: Double(initialCapital) ?? 100000,
                strategyVersionId: selectedStrategyId
            )

            var commandStatus = "pending"
            while commandStatus == "pending" || commandStatus == "running" {
                try await Task.sleep(for: .seconds(3))
                let poll = try await api.backtestStatus(commandId: response.commandId)
                commandStatus = poll.commandStatus
                if commandStatus == "completed", let run = poll.backtestRun {
                    backtestResult = BacktestDisplayResult(
                        totalReturn: run.totalReturn,
                        sharpeRatio: run.sharpeRatio,
                        maxDrawdown: run.maxDrawdown,
                        winRate: run.winRate,
                        profitFactor: run.profitFactor,
                        totalTrades: run.totalTrades,
                        initialCapital: run.initialCapital,
                        finalEquity: run.initialCapital * (1 + run.totalReturn / 100),
                        equityPoints: [],
                        trades: []
                    )
                }
            }
        } catch { }
        isRunning = false
    }

    private func loadRecentRuns() async {
        let api = APIStrategiesV2(client: networkClient)
        recentRuns = (try? await api.listBacktests(limit: 10)) ?? []
    }
}

// MARK: - 回测显示结果

struct BacktestDisplayResult {
    let totalReturn: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let winRate: Double
    let profitFactor: Double
    let totalTrades: Int
    let initialCapital: Double
    let finalEquity: Double
    let equityPoints: [Double]
    let trades: [BacktestTrade]

    static func mock(initialCapital: Double) -> BacktestDisplayResult {
        let finalEquity = initialCapital * 1.425
        // 生成权益曲线点
        var points: [Double] = []
        var equity = initialCapital
        for _ in 0..<30 {
            equity += equity * Double.random(in: -0.03...0.05)
            points.append(equity)
        }
        points.append(finalEquity)

        return BacktestDisplayResult(
            totalReturn: 42.5,
            sharpeRatio: 1.85,
            maxDrawdown: -12.3,
            winRate: 58.2,
            profitFactor: 1.72,
            totalTrades: 156,
            initialCapital: initialCapital,
            finalEquity: finalEquity,
            equityPoints: points,
            trades: [
                BacktestTrade(time: "01-15 14:30", side: "买入", price: 42150.00, quantity: 0.5, pnl: 0),
                BacktestTrade(time: "01-18 09:15", side: "卖出", price: 43820.00, quantity: 0.5, pnl: 835.00),
                BacktestTrade(time: "02-03 16:45", side: "买入", price: 44200.00, quantity: 0.3, pnl: 0),
                BacktestTrade(time: "02-07 11:20", side: "卖出", price: 43100.00, quantity: 0.3, pnl: -330.00),
                BacktestTrade(time: "02-14 08:00", side: "买入", price: 46500.00, quantity: 0.4, pnl: 0),
                BacktestTrade(time: "02-20 22:10", side: "卖出", price: 48900.00, quantity: 0.4, pnl: 960.00),
                BacktestTrade(time: "03-05 13:30", side: "买入", price: 51200.00, quantity: 0.35, pnl: 0),
                BacktestTrade(time: "03-12 17:45", side: "卖出", price: 53800.00, quantity: 0.35, pnl: 910.00),
            ]
        )
    }
}

struct BacktestTrade {
    let time: String
    let side: String
    let price: Double
    let quantity: Double
    let pnl: Double
}
