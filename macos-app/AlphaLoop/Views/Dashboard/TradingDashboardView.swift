// TradingDashboardView.swift — OKX-inspired quant dashboard (design reference)
//
// Self-contained: relies only on the module's existing `Color(hex:)` extension
// (defined in DesignSystem/DesignTokens.swift) and native SwiftUI. No PulseColors
// dependency, so it previews and drops in cleanly.
//
// Design tenets (OKX dark terminal):
//   • Near-black surfaces, hairline dividers, tiny uppercase labels.
//   • Green/red are SEMANTIC only (buy/sell, profit/loss, health) — never chrome.
//   • Every number is .monospacedDigit() so rapid updates never shift the layout.
//   • Sharp corners (2–4pt). Single-layer borders. Dense 4/8/12 spacing.

import SwiftUI

// MARK: - Palette

private enum Desk {
    static let bg          = Color(hex: "121418") // deep slate black
    static let panel       = Color(hex: "1C1E22") // card surface
    static let field       = Color(hex: "24272E") // inset track (segmented / inputs)
    static let border      = Color(hex: "2C2F36") // dividers & borders
    static let textPrimary = Color(hex: "F5F5F5")
    static let textMuted   = Color(hex: "8A8D93")
    static let textFaint   = Color(hex: "5C5F66")

    static let buy         = Color(hex: "20B26C") // long / profit / healthy
    static let sell        = Color(hex: "EF454A") // short / loss / danger
    static let warn        = Color(hex: "F0A020") // medium risk

    // Type helpers — data faces always carry tabular figures.
    static func num(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

private let corner: CGFloat = 4

// MARK: - Root

struct TradingDashboardView: View {
    @State private var model = DashboardModel.sample

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SystemStatusHeader(status: model.status)
                StrategyControlPanel(
                    engineRunning: $model.engineRunning,
                    risk: $model.risk,
                    metrics: model.engineMetrics
                )
                MarketTickerSection(tickers: model.tickers)
                TransactionLogPanel(orders: model.orders)
            }
            .padding(12)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity) // center the column
        }
        .background(Desk.bg)
        .task { await model.runLiveFeed() } // drives the monospaced-digit demo
    }
}

// MARK: - Reusable panel container (single border, consistent padding)

private struct Panel<Content: View>: View {
    var title: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title { SectionLabel(title) }
                    Spacer(minLength: 8)
                    if let trailing { trailing }
                }
            }
            content()
        }
        .padding(12)
        .background(Desk.panel, in: RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(Desk.border, lineWidth: 1)
        )
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Desk.text(10, .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Desk.textFaint)
    }
}

// MARK: - 1. System status header

private struct SystemStatusHeader: View {
    let status: DeskSystemStatus

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                PulseDot(color: Desk.buy)
                VStack(alignment: .leading, spacing: 1) {
                    Text("AlphaLoop")
                        .font(Desk.text(14, .semibold))
                        .foregroundStyle(Desk.textPrimary)
                    Text("Live · \(status.venue)")
                        .font(Desk.text(11))
                        .foregroundStyle(Desk.textMuted)
                }
            }

            Spacer(minLength: 12)

            StatCell(label: "API", value: "\(status.latencyMs)", unit: "ms",
                     tint: status.latencyMs < 60 ? Desk.buy : Desk.warn)
            Divider().frame(height: 24).overlay(Desk.border)
            StatCell(label: "Bots", value: "\(status.activeBots)", unit: "/\(status.totalBots)",
                     tint: Desk.textPrimary)
            Divider().frame(height: 24).overlay(Desk.border)
            StatCell(label: "24h Vol", value: status.volume, unit: "USDT",
                     tint: Desk.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Desk.panel, in: RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(Desk.border, lineWidth: 1)
        )
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(Desk.text(9, .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Desk.textFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Desk.num(14, .medium))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(Desk.num(10))
                    .foregroundStyle(Desk.textMuted)
            }
        }
    }
}

private struct PulseDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 1)
                    .scaleEffect(on ? 2.4 : 1)
                    .opacity(on ? 0 : 0.7)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    on = true
                }
            }
    }
}

// MARK: - 2. Strategy control panel

private struct StrategyControlPanel: View {
    @Binding var engineRunning: Bool
    @Binding var risk: RiskLevel
    let metrics: EngineMetrics

    var body: some View {
        Panel(title: "Strategy engine") {
            HStack(alignment: .top, spacing: 16) {
                // Master start/stop — green to start, red to stop (semantic).
                Button {
                    engineRunning.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: engineRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(engineRunning ? "Stop engine" : "Start engine")
                            .font(Desk.text(13, .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(engineRunning ? Desk.sell : Desk.buy)
                    .background((engineRunning ? Desk.sell : Desk.buy).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: corner))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .strokeBorder((engineRunning ? Desk.sell : Desk.buy).opacity(0.5),
                                          lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(width: 180)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Risk profile")
                    RiskSegmentedControl(selection: $risk)
                }
            }

            Divider().overlay(Desk.border).padding(.vertical, 2)

            // Engine readouts — all tabular.
            HStack(spacing: 0) {
                MetricReadout(label: "Net exposure", value: metrics.exposure, tint: Desk.textPrimary)
                MetricReadout(label: "Open PnL", value: metrics.openPnl,
                              tint: metrics.openPnlPositive ? Desk.buy : Desk.sell)
                MetricReadout(label: "Max drawdown", value: metrics.maxDrawdown, tint: Desk.sell)
                MetricReadout(label: "Leverage", value: metrics.leverage, tint: Desk.textPrimary)
            }
        }
    }
}

private struct MetricReadout: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Desk.text(10))
                .foregroundStyle(Desk.textMuted)
            Text(value)
                .font(Desk.num(15, .medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RiskSegmentedControl: View {
    @Binding var selection: RiskLevel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RiskLevel.allCases) { level in
                let active = level == selection
                Button {
                    selection = level
                } label: {
                    Text(level.title)
                        .font(Desk.text(12, active ? .semibold : .regular))
                        .foregroundStyle(active ? level.tint : Desk.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(active ? level.tint.opacity(0.14) : .clear)
                }
                .buttonStyle(.plain)

                if level != RiskLevel.allCases.last {
                    Rectangle().fill(Desk.border).frame(width: 1)
                }
            }
        }
        .background(Desk.field, in: RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(Desk.border, lineWidth: 1)
        )
    }
}

// MARK: - 3. Market ticker

private struct MarketTickerSection: View {
    let tickers: [Ticker]

    var body: some View {
        Panel(title: "Markets") {
            HStack(spacing: 10) {
                ForEach(tickers) { TickerCard(ticker: $0) }
            }
        }
    }
}

private struct TickerCard: View {
    let ticker: Ticker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticker.pair)
                    .font(Desk.text(12, .semibold))
                    .foregroundStyle(Desk.textPrimary)
                Spacer()
                Text(ticker.changeFormatted)
                    .font(Desk.num(11, .medium))
                    .foregroundStyle(ticker.up ? Desk.buy : Desk.sell)
            }

            Text(ticker.lastFormatted)
                .font(Desk.num(20, .semibold))
                .foregroundStyle(ticker.up ? Desk.buy : Desk.sell)
                .contentTransition(.numericText())

            HStack(spacing: 0) {
                BidAskCell(tag: "BID", value: ticker.bidFormatted, tint: Desk.buy)
                Rectangle().fill(Desk.border).frame(width: 1, height: 22)
                BidAskCell(tag: "ASK", value: ticker.askFormatted, tint: Desk.sell)
            }
            .background(Desk.field, in: RoundedRectangle(cornerRadius: 2))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Desk.bg, in: RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(Desk.border, lineWidth: 1)
        )
    }
}

private struct BidAskCell: View {
    let tag: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(tag)
                .font(Desk.text(8, .semibold))
                .tracking(0.8)
                .foregroundStyle(Desk.textFaint)
            Text(value)
                .font(Desk.num(12, .medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 4. Transaction log

private struct TransactionLogPanel: View {
    let orders: [OrderLog]

    // Fixed column widths keep header + rows aligned; price flexes.
    private let wTime: CGFloat = 60
    private let wPair: CGFloat = 84
    private let wSide: CGFloat = 44
    private let wQty:  CGFloat = 72
    private let wPnl:  CGFloat = 92

    var body: some View {
        Panel(
            title: "Order log",
            trailing: AnyView(
                Text("\(orders.count) fills")
                    .font(Desk.num(10))
                    .foregroundStyle(Desk.textFaint)
            )
        ) {
            VStack(spacing: 0) {
                headerRow
                Rectangle().fill(Desk.border).frame(height: 1)

                LazyVStack(spacing: 0) {
                    ForEach(orders) { order in
                        row(order)
                        Rectangle().fill(Desk.border.opacity(0.5)).frame(height: 1)
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            colHeader("Time", width: wTime, align: .leading)
            colHeader("Pair", width: wPair, align: .leading)
            colHeader("Side", width: wSide, align: .leading)
            colHeader("Price", width: nil, align: .trailing)
            colHeader("Qty", width: wQty, align: .trailing)
            colHeader("PnL", width: wPnl, align: .trailing)
        }
        .padding(.vertical, 6)
    }

    private func colHeader(_ t: String, width: CGFloat?, align: Alignment) -> some View {
        Text(t)
            .font(Desk.text(9, .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Desk.textFaint)
            .frame(width: width, alignment: align)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
    }

    private func row(_ o: OrderLog) -> some View {
        HStack(spacing: 0) {
            Text(o.time)
                .font(Desk.num(11))
                .foregroundStyle(Desk.textMuted)
                .frame(width: wTime, alignment: .leading)

            Text(o.pair)
                .font(Desk.text(12, .medium))
                .foregroundStyle(Desk.textPrimary)
                .frame(width: wPair, alignment: .leading)

            Text(o.side.title)
                .font(Desk.text(10, .bold))
                .foregroundStyle(o.side == .buy ? Desk.buy : Desk.sell)
                .frame(width: wSide, alignment: .leading)

            Text(o.priceFormatted)
                .font(Desk.num(12))
                .foregroundStyle(Desk.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(o.qtyFormatted)
                .font(Desk.num(12))
                .foregroundStyle(Desk.textMuted)
                .frame(width: wQty, alignment: .trailing)

            Text(o.pnlFormatted)
                .font(Desk.num(12, .medium))
                .foregroundStyle(o.pnl >= 0 ? Desk.buy : Desk.sell)
                .frame(width: wPnl, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

// MARK: - Models + sample data

private enum RiskLevel: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    var tint: Color {
        switch self {
        case .low: return Desk.buy
        case .medium: return Desk.warn
        case .high: return Desk.sell
        }
    }
}

private enum Side { case buy, sell
    var title: String { self == .buy ? "BUY" : "SELL" }
}

private struct DeskSystemStatus {
    var venue: String
    var latencyMs: Int
    var activeBots: Int
    var totalBots: Int
    var volume: String
}

private struct EngineMetrics {
    var exposure: String
    var openPnl: String
    var openPnlPositive: Bool
    var maxDrawdown: String
    var leverage: String
}

private struct Ticker: Identifiable {
    let id = UUID()
    var pair: String
    var last: Double
    var change: Double // percent
    var bid: Double
    var ask: Double

    var up: Bool { change >= 0 }
    var lastFormatted: String { last.grouped(2) }
    var bidFormatted: String { bid.grouped(1) }
    var askFormatted: String { ask.grouped(1) }
    var changeFormatted: String { (change >= 0 ? "+" : "") + String(format: "%.2f%%", change) }
}

private struct OrderLog: Identifiable {
    let id = UUID()
    var time: String
    var pair: String
    var side: Side
    var price: Double
    var qty: Double
    var pnl: Double

    var priceFormatted: String { price.grouped(2) }
    var qtyFormatted: String { String(format: "%.3f", qty) }
    var pnlFormatted: String { (pnl >= 0 ? "+" : "") + pnl.grouped(2) }
}

private extension Double {
    func grouped(_ decimals: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: self)) ?? String(self)
    }
}

@Observable
private final class DashboardModel {
    var status: DeskSystemStatus
    var engineRunning: Bool
    var risk: RiskLevel
    var engineMetrics: EngineMetrics
    var tickers: [Ticker]
    var orders: [OrderLog]

    init(status: DeskSystemStatus, engineRunning: Bool, risk: RiskLevel,
         engineMetrics: EngineMetrics, tickers: [Ticker], orders: [OrderLog]) {
        self.status = status
        self.engineRunning = engineRunning
        self.risk = risk
        self.engineMetrics = engineMetrics
        self.tickers = tickers
        self.orders = orders
    }

    // Gentle random walk so monospaced-digit stability is visible in the preview.
    @MainActor
    func runLiveFeed() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            status.latencyMs = max(12, min(140, status.latencyMs + Int.random(in: -6...6)))
            for i in tickers.indices {
                let drift = tickers[i].last * Double.random(in: -0.0008...0.0008)
                tickers[i].last += drift
                tickers[i].bid = tickers[i].last - tickers[i].last * 0.00002
                tickers[i].ask = tickers[i].last + tickers[i].last * 0.00002
                tickers[i].change += Double.random(in: -0.04...0.04)
            }
        }
    }

    static var sample: DashboardModel {
        DashboardModel(
            status: DeskSystemStatus(venue: "OKX Perp", latencyMs: 24,
                                 activeBots: 3, totalBots: 5, volume: "1.84M"),
            engineRunning: true,
            risk: .medium,
            engineMetrics: EngineMetrics(
                exposure: "42,180.00", openPnl: "+1,204.62", openPnlPositive: true,
                maxDrawdown: "-3.18%", leverage: "5.0×"
            ),
            tickers: [
                Ticker(pair: "BTC-USDT", last: 64213.5, change: 1.24, bid: 64213.4, ask: 64213.6),
                Ticker(pair: "ETH-USDT", last: 3142.18, change: -0.63, bid: 3142.10, ask: 3142.24),
                Ticker(pair: "SOL-USDT", last: 148.72, change: 3.41, bid: 148.71, ask: 148.73),
            ],
            orders: [
                OrderLog(time: "14:32:07", pair: "BTC-USDT", side: .buy,  price: 64180.0, qty: 0.125, pnl: 42.18),
                OrderLog(time: "14:31:52", pair: "SOL-USDT", side: .sell, price: 148.42, qty: 12.400, pnl: -8.06),
                OrderLog(time: "14:31:19", pair: "ETH-USDT", side: .buy,  price: 3140.55, qty: 1.800, pnl: 15.34),
                OrderLog(time: "14:30:44", pair: "BTC-USDT", side: .sell, price: 64250.0, qty: 0.080, pnl: 61.90),
                OrderLog(time: "14:29:58", pair: "SOL-USDT", side: .buy,  price: 147.90, qty: 20.000, pnl: 26.40),
                OrderLog(time: "14:29:12", pair: "ETH-USDT", side: .sell, price: 3138.20, qty: 0.900, pnl: -4.11),
                OrderLog(time: "14:28:35", pair: "BTC-USDT", side: .buy,  price: 64090.0, qty: 0.200, pnl: 88.02),
            ]
        )
    }
}

// MARK: - Preview

#if DEBUG
struct TradingDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        TradingDashboardView()
            .frame(width: 900, height: 820)
    }
}
#endif
