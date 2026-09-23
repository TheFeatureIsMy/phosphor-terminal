// TickerTapeView.swift — VOLT 报价跑马灯
// 横向无缝滚动行情带；无数据时自动隐藏（诚实空态）。

import SwiftUI

struct TapeItem: Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let last: Double
    let changePct: Double?
}

struct TickerTapeView: View {
    let items: [TapeItem]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0

    private let speed: Double = 55 // pt/s

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let half = max(contentWidth / 2, 1)
                let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince1970
                let phase = CGFloat(elapsed * speed).truncatingRemainder(dividingBy: half)
                HStack(spacing: 44) {
                    ForEach(items + items) { item in
                        tapeCell(item)
                    }
                }
                .fixedSize()
                .offset(x: -phase)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in contentWidth = w }
                    }
                )
            }
            .frame(height: 34)
            .clipped()
            .background(PulseColors.StateColors.card)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(hex: "26262C")).frame(height: 1)
            }
        }
    }

    private func tapeCell(_ item: TapeItem) -> some View {
        HStack(spacing: 6) {
            Text(item.symbol)
                .font(PulseFonts.mono(11, .medium))
                .foregroundStyle(Color(hex: "9BA0AE"))
            Text(formatPrice(item.last))
                .font(PulseFonts.mono(11, .semibold))
                .foregroundStyle(Color(hex: "F5F6F8"))
            if let c = item.changePct {
                Text(String(format: "%+.2f%%", c))
                    .font(PulseFonts.mono(11, .medium))
                    .foregroundStyle(c >= 0 ? PulseColors.bullish : PulseColors.bearish)
            }
        }
    }

    private func formatPrice(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1f", v) }
        if v >= 10 { return String(format: "%.2f", v) }
        return String(format: "%.4f", v)
    }
}
