// TickerTapeView.swift — 行情轮播条
import SwiftUI

struct TickerTapeView: View {
    @Environment(PulseColors.self) private var colors

    struct TickerItem: Identifiable {
        let id = UUID()
        let symbol: String
        let price: String
        let change: String
        let isPositive: Bool
    }

    private let tickers = [
        TickerItem(symbol: "BTC/USDT", price: "68,420.50", change: "+2.45%", isPositive: true),
        TickerItem(symbol: "ETH/USDT", price: "3,840.12", change: "+1.82%", isPositive: true),
        TickerItem(symbol: "SOL/USDT", price: "156.45", change: "-0.53%", isPositive: false),
        TickerItem(symbol: "BNB/USDT", price: "582.30", change: "+0.95%", isPositive: true),
        TickerItem(symbol: "AVAX/USDT", price: "32.18", change: "-1.45%", isPositive: false)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.md) {
                ForEach(tickers) { ticker in
                    tickerCell(ticker)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(KryptonColor.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }

    private func tickerCell(_ ticker: TickerItem) -> some View {
        HStack(spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker.symbol)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textSecondary)
                Text(ticker.price)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)
                    .fontWeight(.semibold)
            }

            Spacer()

            VStack(spacing: 3) {
                Text(ticker.change)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(ticker.isPositive ? KryptonColor.green : KryptonColor.red)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((ticker.isPositive ? KryptonColor.green : KryptonColor.red).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))

                sparkline(up: ticker.isPositive)
                    .frame(width: 42, height: 14)
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, 8)
        .frame(minWidth: 190)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
    }

    private func sparkline(up: Bool) -> some View {
        let points = up ? "M0,12 L8,10 L16,13 L24,6 L32,8 L42,1" : "M0,3 L8,7 L16,4 L24,11 L32,9 L42,13"
        return Path { path in
            let parts = points.split(separator: " ")
            for (index, part) in parts.enumerated() {
                let coords = part.split(separator: ",")
                guard coords.count == 2,
                      let x = Double(coords[0]),
                      let y = Double(coords[1]) else { continue }
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(up ? KryptonColor.green : KryptonColor.red, lineWidth: 1.5)
    }
}
