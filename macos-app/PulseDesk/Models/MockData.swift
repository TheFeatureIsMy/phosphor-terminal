// MockData.swift — 模拟数据生成器
// 与 src/api/mock-data.ts 完全对齐，保证视觉一致性

import Foundation

struct MockData {
    // MARK: - 辅助函数
    private static func randomBetween(_ min: Double, _ max: Double) -> Double {
        min + Double.random(in: 0..<1) * (max - min)
    }

    private static func randomChoice<T>(_ arr: [T]) -> T {
        arr[Int.random(in: 0..<arr.count)]
    }

    private static func dateDaysAgo(_ days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dateISO(_ daysAgo: Double) -> String {
        let date = Date().addingTimeInterval(-daysAgo * 86400)
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    // MARK: - 权益曲线生成器（与 TS 版完全一致）
    static func generateEquityCurve(days: Int, initial: Double = 10000) -> [EquityPoint] {
        var points: [EquityPoint] = []
        var value = initial
        var peak = initial
        for i in 0..<days {
            let change = value * randomBetween(-0.03, 0.04)
            value = max(value + change, initial * 0.5)
            peak = max(peak, value)
            let date = dateDaysAgo(days - i)
            points.append(EquityPoint(
                date: date,
                value: (value * 100).rounded() / 100,
                drawdown: ((value - peak) / peak * 10000).rounded() / 100,
                dataSource: nil
            ))
        }
        return points
    }

    // MARK: - 策略名称
    private static let strategyNames = [
        "RSI均值回归", "MACD趋势跟踪", "布林带突破", "网格交易-BTC",
        "ETH/BTC配对交易", "资金费率套利", "链上鲸鱼追踪", "情绪反转策略"
    ]

    // MARK: - 交易对
    static let symbols = ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]

    // MARK: - 模拟策略列表
    static func mockStrategies() -> [Strategy] {
        let types: [StrategyType] = [.maCross, .breakout, .grid, .meanReversion, .ragGenerated]
        let statuses: [StrategyStatus] = [.active, .active, .paused, .paused, .backtested, .backtested, .draft, .draft]
        let sources: [StrategySource] = [.manual, .manual, .manual, .manual, .manual, .manual, .optimized, .ragGenerated]

        return strategyNames.enumerated().map { i, name in
            Strategy(
                id: i + 1,
                userId: 1,
                name: name,
                type: types[i % 5],
                parameters: [
                    "period": AnyCodable([14, 20, 50, 100].randomElement()!),
                    "threshold": AnyCodable(randomBetween(0.01, 0.05))
                ],
                source: sources[i],
                market: "crypto",
                exchange: "binance",
                version: Int(randomBetween(1, 5)),
                status: statuses[i],
                sharpeRatio: (randomBetween(0.5, 2.5) * 100).rounded() / 100,
                maxDrawdown: (randomBetween(5, 25) * 100).rounded() / 100,
                freqtradeStrategyId: nil,
                createdAt: dateISO(randomBetween(1, 90)),
                updatedAt: dateISO(randomBetween(0, 7))
            )
        }
    }

    // MARK: - 模拟订单
    static func mockOrders(count: Int = 50) -> [Order] {
        (0..<count).map { i in
            let side: OrderSide = Double.random(in: 0..<1) > 0.5 ? .buy : .sell
            let price = randomBetween(100, 70000)
            let profit = randomBetween(-500, 800)
            return Order(
                id: i + 1,
                strategyId: Int(randomBetween(1, 5)),
                symbol: randomChoice(symbols),
                side: side,
                orderType: Double.random(in: 0..<1) > 0.3 ? .market : .limit,
                quantity: (randomBetween(0.001, 2) * 1000).rounded() / 1000,
                price: (price * 100).rounded() / 100,
                filledPrice: (price * (1 + randomBetween(-0.005, 0.005)) * 100).rounded() / 100,
                fee: (price * 0.001 * 100).rounded() / 100,
                slippage: (randomBetween(0, price * 0.002) * 100).rounded() / 100,
                timestamp: dateISO(randomBetween(0, 30)),
                status: Double.random(in: 0..<1) > 0.05 ? .filled : (Double.random(in: 0..<1) > 0.5 ? .cancelled : .failed),
                profit: (profit * 100).rounded() / 100,
                pnlPct: ((profit / (price * 0.01)) * 100).rounded() / 100,
                dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - 模拟持仓
    static func mockPositions() -> [Position] {
        [
            Position(id: 1, userId: 1, strategyId: 1, symbol: "BTC/USDT", side: .long, quantity: 0.5, avgPrice: 62350, unrealizedPnl: 1250, stopLossPrice: 60000, takeProfitPrice: 68000, status: .open, openedAt: dateISO(2), closedAt: nil, dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)),
            Position(id: 2, userId: 1, strategyId: 2, symbol: "ETH/USDT", side: .long, quantity: 5, avgPrice: 3420, unrealizedPnl: -180, stopLossPrice: 3200, takeProfitPrice: 3800, status: .open, openedAt: dateISO(1), closedAt: nil, dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)),
            Position(id: 3, userId: 1, strategyId: 3, symbol: "SOL/USDT", side: .short, quantity: 20, avgPrice: 178, unrealizedPnl: 340, stopLossPrice: 190, takeProfitPrice: nil, status: .open, openedAt: dateISO(3), closedAt: nil, dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)),
        ]
    }

    // MARK: - 模拟回测指标
    static func mockBacktestMetrics() -> BacktestMetrics {
        BacktestMetrics(
            totalReturn: 34.7, sharpeRatio: 1.82, maxDrawdown: 12.3, winRate: 62.5,
            profitFactor: 1.95, totalTrades: 128, avgTradeDuration: "4h 23m",
            bestTrade: 850, worstTrade: -320
        )
    }

    // MARK: - 模拟回测
    static func mockBacktest() -> Backtest {
        Backtest(
            id: 1, strategyId: 1,
            config: BacktestConfig(startDate: "2025-01-01", endDate: "2025-12-31", initialCapital: 10000, symbols: ["BTC/USDT"]),
            result: BacktestResult(equityCurve: generateEquityCurve(days: 365, initial: 10000), trades: mockOrders(count: 30), metrics: mockBacktestMetrics()),
            sharpeRatio: 1.82, maxDrawdown: 12.3, winRate: 62.5, totalReturn: 34.7,
            passed: true, createdAt: ISO8601DateFormatter().string(from: Date()),
            dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)
        )
    }

    // MARK: - 模拟仪表盘 KPI
    static func mockDashboardKPIs() -> DashboardKPIs {
        DashboardKPIs(
            totalPnl: 12450.80, pnlChangePct: 5.2, sharpeRatio: 1.82, maxDrawdown: 12.3,
            winRate: 62.5, activeStrategies: 2, todaysTrades: 8, openPositions: 3,
            dataSource: DataSourceStatus(source: "freqtrade_db", simulated: false, available: true, detail: nil)
        )
    }

    // MARK: - 模拟系统状态
    static func mockSystemStatus() -> SystemStatus {
        SystemStatus(
            uptime: "3d 14h 22m", activeStrategies: 2, openPositions: 3, pendingOrders: 1,
            lastDataUpdate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-30)),
            apiStatus: .connected,
            dataSource: DataSourceStatus(source: "freqtrade", simulated: false, available: true, detail: nil)
        )
    }

    // MARK: - 模拟风险事件
    static func mockRiskEvents() -> [RiskEvent] {
        [
            RiskEvent(id: 1, eventType: .stopLoss, strategyId: 1, severity: .medium, description: "BTC/USDT 触发止损，浮亏超过5%", actionTaken: "自动平仓", createdAt: dateISO(0.04)),
            RiskEvent(id: 2, eventType: .correlationWarning, strategyId: nil, severity: .medium, description: "BTC/USDT 与 ETH/USDT 相关系数 0.92，组合集中度过高", actionTaken: "建议减仓", createdAt: dateISO(0.08)),
            RiskEvent(id: 3, eventType: .apiError, strategyId: nil, severity: .high, description: "Binance API 请求超时，已自动重试", actionTaken: "重连成功", createdAt: dateISO(1)),
        ]
    }

    // MARK: - 模拟相关性
    static func mockCorrelation() -> [CorrelationSnapshot] {
        [
            CorrelationSnapshot(id: 1, symbolA: "BTC/USDT", symbolB: "ETH/USDT", correlation: 0.92, windowDays: 30, alertLevel: .red, createdAt: ISO8601DateFormatter().string(from: Date())),
            CorrelationSnapshot(id: 2, symbolA: "BTC/USDT", symbolB: "SOL/USDT", correlation: 0.78, windowDays: 30, alertLevel: .normal, createdAt: ISO8601DateFormatter().string(from: Date())),
            CorrelationSnapshot(id: 3, symbolA: "ETH/USDT", symbolB: "SOL/USDT", correlation: 0.85, windowDays: 30, alertLevel: .yellow, createdAt: ISO8601DateFormatter().string(from: Date())),
            CorrelationSnapshot(id: 4, symbolA: "BTC/USDT", symbolB: "BNB/USDT", correlation: 0.71, windowDays: 30, alertLevel: .normal, createdAt: ISO8601DateFormatter().string(from: Date())),
        ]
    }

    // MARK: - 模拟仪表盘权益曲线
    static func mockEquityCurve() -> [EquityPoint] {
        generateEquityCurve(days: 90, initial: 10000)
    }

    // MARK: - 模拟通知
    static func mockNotifications() -> [AppNotification] {
        let now = Date()
        return [
            AppNotification(
                id: UUID(), type: .riskAlert, title: "BTC/USDT 触发止损",
                message: "浮亏超过5%，已自动平仓。建议检查策略参数。",
                severity: .critical, isRead: false,
                actionRoute: "risk", actionPayload: nil,
                createdAt: now.addingTimeInterval(-5 * 60)
            ),
            AppNotification(
                id: UUID(), type: .tradeExecuted, title: "ETH/USDT 买入成交",
                message: "MACD趋势跟踪策略以 $3,420 买入 2.5 ETH。",
                severity: .info, isRead: false,
                actionRoute: "orders", actionPayload: nil,
                createdAt: now.addingTimeInterval(-22 * 60)
            ),
            AppNotification(
                id: UUID(), type: .aiInsight, title: "AI 发现潜在机会",
                message: "SOL/USDT 链上鲸鱼活动异常，建议关注支撑位 $175。",
                severity: .info, isRead: false,
                actionRoute: "ai", actionPayload: nil,
                createdAt: now.addingTimeInterval(-45 * 60)
            ),
            AppNotification(
                id: UUID(), type: .systemAlert, title: "API 连接中断",
                message: "Binance API 请求超时，已自动重试并恢复。",
                severity: .warning, isRead: true,
                actionRoute: nil, actionPayload: nil,
                createdAt: now.addingTimeInterval(-3 * 3600)
            ),
            AppNotification(
                id: UUID(), type: .strategyUpdate, title: "网格交易策略已优化",
                message: "AI 根据近7日波动率调整了网格间距，预计收益提升 12%。",
                severity: .info, isRead: true,
                actionRoute: "strategies", actionPayload: nil,
                createdAt: now.addingTimeInterval(-8 * 3600)
            ),
            AppNotification(
                id: UUID(), type: .riskAlert, title: "相关性警告",
                message: "BTC/USDT 与 ETH/USDT 相关系数 0.92，组合集中度过高。",
                severity: .warning, isRead: true,
                actionRoute: "risk", actionPayload: nil,
                createdAt: now.addingTimeInterval(-24 * 3600)
            ),
        ]
    }

    // MARK: - 模拟认证
    static func mockTokenResponse() -> TokenResponse {
        TokenResponse(
            accessToken: "mock-access-token-\(UUID().uuidString.prefix(8))",
            refreshToken: "mock-refresh-token-\(UUID().uuidString.prefix(8))",
            tokenType: "bearer"
        )
    }

    static func mockRegisterUser() -> User {
        User(
            id: 1, name: "newuser", email: "newuser@pulsedesk.io",
            telegramId: nil, role: "trader",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
