// MarketStructureView.swift — SMC Research · Causal Storyboard
// Design spec: docs/superpowers/specs/2026-06-10-market-structure-causal-storyboard-design.md

import SwiftUI
import AppKit

// MARK: - Main View

struct MarketStructureView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var vm: MarketStructureViewModel?

    var body: some View {
        Group {
            if let vm = vm {
                MarketStructureContentView(vm: vm)
            } else {
                LoadingView(type: .detail)
                    .padding(PulseSpacing.lg)
            }
        }
        .task {
            if vm == nil {
                let model = MarketStructureViewModel(client: networkClient)
                vm = model
                await model.load()
            }
        }
    }
}

// MARK: - Content View

private struct MarketStructureContentView: View {
    @Bindable var vm: MarketStructureViewModel
    @Environment(PulseColors.self) private var colors

    @State private var symbolPickerOpen: Bool = false
    @AppStorage("market_structure.recent_symbols") private var recentSymbolsRaw: String = "BTC/USDT,ETH/USDT,SOL/USDT"

    private let allSymbols = [
        "BTC/USDT", "ETH/USDT", "SOL/USDT",
        "AVAX/USDT", "LINK/USDT", "ARB/USDT",
        "BNB/USDT", "XRP/USDT", "DOGE/USDT",
        "MATIC/USDT", "DOT/USDT", "ATOM/USDT",
    ]
    private let timeframes = ["5m", "15m", "1h", "4h"]

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                    headerSection
                        .staggeredAppearance(index: 0)

                    if vm.isLoading && vm.data == nil {
                        LoadingView(type: .detail)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PulseSpacing.xl)
                    } else if let error = vm.error {
                        errorState(error)
                    } else {
                        contextChapter
                            .staggeredAppearance(index: 1)

                        eventThreadChapter
                            .staggeredAppearance(index: 2)

                        futureSlotPlaceholder
                            .staggeredAppearance(index: 3)

                        activeZonesChapter
                            .staggeredAppearance(index: 4)

                        liquidityPoolsChapter
                            .staggeredAppearance(index: 5)
                    }
                }
                .padding(.horizontal, PulseSpacing.xl)
                .padding(.vertical, PulseSpacing.lg)
                .frame(maxWidth: 1200, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if symbolPickerOpen {
                symbolPickerOverlay
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .onChange(of: vm.selectedSymbol) { _, new in
            pushRecent(new)
            Task { await vm.load() }
        }
        .onChange(of: vm.selectedTimeframe) { _, _ in
            Task { await vm.load() }
        }
        .background(
            // ⌘K shortcut
            Button("") { symbolPickerOpen.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center, spacing: PulseSpacing.md) {
            // α glyph
            ZStack {
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(
                        LinearGradient(
                            colors: [PulseColors.accent.opacity(0.25), PulseColors.accent.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(PulseColors.accent.opacity(0.4), lineWidth: 1)
                    )
                Text("α")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(PulseColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Structure.title)
                    .font(PulseFonts.displayHeading)
                    .foregroundStyle(colors.textPrimary)
                Text("SMC RESEARCH")
                    .font(PulseFonts.micro)
                    .tracking(2)
                    .foregroundStyle(PulseColors.accent.opacity(0.7))
            }

            Spacer()

            // Symbol trigger
            Button {
                symbolPickerOpen = true
            } label: {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                    Text(vm.selectedSymbol)
                        .font(PulseFonts.tabular)
                        .foregroundStyle(colors.textPrimary)
                    Text("⌘K")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(colors.textMuted.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(colors.surfaceHover.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .stroke(colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Timeframe segmented
            HStack(spacing: 2) {
                ForEach(timeframes, id: \.self) { tf in
                    Button {
                        vm.selectedTimeframe = tf
                    } label: {
                        Text(tf)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(vm.selectedTimeframe == tf ? colors.textPrimary : colors.textSecondary)
                            .padding(.horizontal, PulseSpacing.sm)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(vm.selectedTimeframe == tf ? PulseColors.accent.opacity(0.18) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(colors.surfaceHover.opacity(0.4))
            )

            // Refresh
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseColors.accent)
                    .frame(width: 30, height: 30)
                    .background(PulseColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                    .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                    .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
            }
            .buttonStyle(.plain)
            .disabled(vm.isLoading)
        }
    }

    // MARK: - Chapter I · CONTEXT

    @ViewBuilder
    private var contextChapter: some View {
        chapterScaffold(
            numeral: "I",
            title: L10n.zh("背景", en: "CONTEXT"),
            pose: L10n.zh("我们处在什么样的市场？", en: "what kind of market are we in?")
        ) {
            HStack(alignment: .top, spacing: PulseSpacing.xl) {
                // Regime
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    Text(regimeWord)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(regimeColor)
                        .tracking(-1)
                    Text(regimeNarrative)
                        .font(.system(size: 13, weight: .regular, design: .serif).italic())
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 280, alignment: .leading)

                Spacer(minLength: PulseSpacing.lg)

                // Meters
                HStack(spacing: PulseSpacing.md) {
                    meterTile(
                        label: L10n.Structure.structureScore,
                        value: "\(Int(vm.score))",
                        suffix: "/ 100",
                        bar: vm.score / 100.0,
                        color: scoreColor
                    )
                    .frame(width: 160)

                    meterTile(
                        label: L10n.Structure.premiumDiscount,
                        value: pdLabel,
                        suffix: nil,
                        bar: nil,
                        color: pdColor
                    )
                    .frame(width: 130)

                    meterTile(
                        label: L10n.zh("活跃库存", en: "ACTIVE INVENTORY"),
                        value: "\(activeZoneCount)z · \(activePoolCount)p",
                        suffix: nil,
                        bar: nil,
                        color: PulseColors.accent
                    )
                    .frame(width: 130)
                }
            }
        }
    }

    @ViewBuilder
    private func meterTile(label: String, value: String, suffix: String?, bar: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(label.uppercased())
                .font(PulseFonts.micro)
                .tracking(1.5)
                .foregroundStyle(colors.textMuted)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                if let suffix = suffix {
                    Text(suffix)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }

            if let bar = bar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.textMuted.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.5), color],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(max(0, min(1, bar))))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // MARK: - Chapter II · EVENT THREAD

    @ViewBuilder
    private var eventThreadChapter: some View {
        chapterScaffold(
            numeral: "II",
            title: L10n.zh("我们如何走到这里", en: "HOW WE GOT HERE"),
            pose: L10n.zh("近期结构事件，由旧到新", en: "recent structural events, oldest first")
        ) {
            if vm.events.isEmpty {
                emptyChapter(icon: "bolt.slash", text: L10n.zh("此周期暂无结构事件", en: "no structural events in this timeframe"))
            } else {
                let ordered = vm.events.sorted { $0.timestamp < $1.timestamp }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, event in
                        eventThreadRow(event: event, isLast: index == ordered.count - 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventThreadRow(event: StructureEventResponse, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(eventColor(event).opacity(0.18))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(eventColor(event))
                        .frame(width: 8, height: 8)
                        .shadow(color: eventColor(event).opacity(0.6), radius: 4)
                }
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [eventColor(event).opacity(0.5), colors.textMuted.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack(spacing: PulseSpacing.sm) {
                    Text(eventLabel(event))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(eventColor(event))

                    Text(formatPrice(event.price))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)

                    Image(systemName: event.direction == "bullish" ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(event.direction == "bullish" ? PulseColors.StateColors.green : PulseColors.StateColors.red)

                    Text(event.timeframe)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(colors.textMuted.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Spacer()

                    Text(formatTimestamp(event.timestamp))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Text(eventNarrative(event))
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : PulseSpacing.md)
        }
    }

    // MARK: - Future slot

    @ViewBuilder
    private var futureSlotPlaceholder: some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 14))
                .foregroundStyle(colors.textMuted.opacity(0.5))
            Text(L10n.zh("即将上线：价格走势叠加", en: "coming soon · price sparkline overlay"))
                .font(.system(size: 12, weight: .regular, design: .serif).italic())
                .foregroundStyle(colors.textMuted)
            Spacer()
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .foregroundStyle(colors.textMuted.opacity(0.3))
        )
    }

    // MARK: - Chapter III · ACTIVE ZONES

    @ViewBuilder
    private var activeZonesChapter: some View {
        chapterScaffold(
            numeral: "III",
            title: L10n.zh("当下活跃区域", en: "WHAT'S ACTIVE NOW"),
            pose: L10n.zh("价格尚未完全反应的区域，按距离排序", en: "zones price has yet to fully react to · ranked by distance")
        ) {
            if vm.zones.isEmpty {
                emptyChapter(icon: "square.stack.3d.up.slash", text: L10n.zh("此周期暂无活跃区域", en: "no active zones in this timeframe"))
            } else {
                let sorted = vm.zones.sorted { absDistance($0) < absDistance($1) }
                let columns = [
                    GridItem(.flexible(), spacing: PulseSpacing.md),
                    GridItem(.flexible(), spacing: PulseSpacing.md),
                ]
                LazyVGrid(columns: columns, spacing: PulseSpacing.md) {
                    ForEach(sorted, id: \.id) { zone in
                        zoneStoryCard(zone: zone)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zoneStoryCard(zone: StructureZoneResponse) -> some View {
        let dist = signedDistance(zone)
        let above = dist >= 0
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            // Lede: distance from now
            HStack(alignment: .lastTextBaseline, spacing: PulseSpacing.xs) {
                Text(String(format: "%@%.2f%%", above ? "+" : "−", abs(dist) * 100))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(zoneDirectionColor(zone))

                Text(above ? L10n.zh("高于现价", en: "ABOVE NOW") : L10n.zh("低于现价", en: "BELOW NOW"))
                    .font(PulseFonts.micro)
                    .tracking(1.2)
                    .foregroundStyle(colors.textMuted)
            }

            // Subtitle: type · TF · direction
            HStack(spacing: PulseSpacing.xs) {
                Text(zoneTypeLabel(zone))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(zoneDirectionColor(zone))
                Text("·")
                    .foregroundStyle(colors.textMuted)
                Text(zone.timeframe)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textSecondary)
                Text("·")
                    .foregroundStyle(colors.textMuted)
                Text(zoneRoleLabel(zone))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textSecondary)

                Spacer()

                zoneStatusBadge(status: zone.status)
            }

            // Narrative
            Text(zoneNarrative(zone))
                .font(.system(size: 12.5, weight: .regular, design: .serif).italic())
                .foregroundStyle(colors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Strength + Mitigation bars
            VStack(alignment: .leading, spacing: 6) {
                barRow(label: L10n.Structure.strength, value: zone.currentStrength, color: zoneDirectionColor(zone))
                if zone.zoneType == "fvg" {
                    barRow(label: L10n.Structure.fillRate, value: zone.filledRatio, color: PulseColors.warning)
                }
            }

            // Price range footer
            HStack(spacing: 4) {
                Text(formatPrice(zone.priceBottom))
                Text("–")
                    .foregroundStyle(colors.textMuted)
                Text(formatPrice(zone.priceTop))
            }
            .font(PulseFonts.micro)
            .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surfaceHover.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(zoneDirectionColor(zone).opacity(0.25), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            // Accent stripe
            RoundedRectangle(cornerRadius: 1.5)
                .fill(zoneDirectionColor(zone))
                .frame(width: 3, height: 28)
                .offset(x: 0, y: PulseSpacing.md)
        }
    }

    @ViewBuilder
    private func barRow(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Text(label.uppercased())
                .font(PulseFonts.micro)
                .tracking(1)
                .foregroundStyle(colors.textMuted)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(colors.textMuted.opacity(0.15))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                }
            }
            .frame(height: 3)
            Text("\(Int(value * 100))%")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func zoneStatusBadge(status: String) -> some View {
        Text(statusLabel(status))
            .font(PulseFonts.micro)
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(statusColor(status).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
    }

    // MARK: - Chapter IV · LIQUIDITY POOLS

    @ViewBuilder
    private var liquidityPoolsChapter: some View {
        chapterScaffold(
            numeral: "IV",
            title: L10n.zh("流动性池", en: "LIQUIDITY POOLS"),
            pose: L10n.zh("止损聚集之处 — 价格的磁石", en: "where stops cluster — magnets for price")
        ) {
            if vm.pools.isEmpty {
                emptyChapter(icon: "drop.degreesign.slash", text: L10n.zh("暂无流动性池", en: "no liquidity pools"))
            } else {
                VStack(spacing: 1) {
                    ForEach(vm.pools, id: \.id) { pool in
                        poolStoryRow(pool: pool)
                    }
                }
                .background(colors.border.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            }
        }
    }

    @ViewBuilder
    private func poolStoryRow(pool: LiquidityPoolBFFResponse) -> some View {
        HStack(spacing: PulseSpacing.md) {
            // Direction icon
            Image(systemName: pool.side == "buy_side" ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(poolSideColor(pool))
                .frame(width: 16)

            // Price
            Text(formatPrice(pool.priceLevel))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
                .frame(width: 90, alignment: .leading)

            // Narrative
            Text(poolNarrative(pool))
                .font(.system(size: 12.5, weight: .regular, design: .serif).italic())
                .foregroundStyle(colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // Touch count
            HStack(spacing: 2) {
                Text("×\(pool.touchedCount)")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textSecondary)
            }
            .frame(width: 36, alignment: .trailing)

            // Strength
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(colors.textMuted.opacity(0.15))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(poolSideColor(pool))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, pool.currentStrength))))
                }
            }
            .frame(width: 80, height: 3)

            Text("\(Int(pool.currentStrength * 100))%")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
        .background(colors.surfaceHover.opacity(0.35))
    }

    // MARK: - Chapter scaffolding

    @ViewBuilder
    private func chapterScaffold<C: View>(numeral: String, title: String, pose: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.sm) {
                Text(numeral + ".")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(PulseColors.accent.opacity(0.8))
                    .frame(width: 28, alignment: .leading)

                Text(title)
                    .font(PulseFonts.headline)
                    .tracking(0.5)
                    .foregroundStyle(colors.textPrimary)

                Text("— " + pose)
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(colors.textMuted)

                Spacer()
            }

            content()
                .padding(.leading, 28 + PulseSpacing.sm)
        }
    }

    @ViewBuilder
    private func emptyChapter(icon: String, text: String) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(colors.textMuted.opacity(0.5))
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(colors.textMuted)
            Spacer()
        }
        .padding(.vertical, PulseSpacing.md)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(alignment: .center, spacing: PulseSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(PulseColors.danger)
            Text(L10n.Common.abnormal)
                .font(PulseFonts.headline)
                .foregroundStyle(colors.textPrimary)
            Text(message)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
            Button(L10n.zh("重试", en: "Retry")) {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.xxl)
    }

    // MARK: - Symbol Picker

    private var recentSymbols: [String] {
        recentSymbolsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private func pushRecent(_ symbol: String) {
        var list = recentSymbols
        list.removeAll { $0 == symbol }
        list.insert(symbol, at: 0)
        recentSymbolsRaw = Array(list.prefix(5)).joined(separator: ",")
    }

    @ViewBuilder
    private var symbolPickerOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { symbolPickerOpen = false }

            SymbolPickerPanel(
                allSymbols: allSymbols,
                recent: recentSymbols,
                currentSymbol: vm.selectedSymbol,
                onSelect: { sym in
                    vm.selectedSymbol = sym
                    symbolPickerOpen = false
                },
                onCancel: { symbolPickerOpen = false }
            )
            .padding(.top, 60)
        }
        .background(
            // ESC shortcut
            Button("") { symbolPickerOpen = false }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Derived display values

    private var regimeWord: String {
        switch vm.regime {
        case "trend_up": return L10n.zh("上升趋势", en: "TRENDING ↑")
        case "trend_down": return L10n.zh("下降趋势", en: "TRENDING ↓")
        case "range": return L10n.zh("震荡", en: "RANGING")
        case "high_volatility": return L10n.zh("高波动", en: "VOLATILE")
        case "panic": return L10n.zh("恐慌", en: "PANIC")
        default: return "—"
        }
    }

    private var regimeNarrative: String {
        switch vm.regime {
        case "trend_up":
            return L10n.zh("HTF 摆动逐次抬高 — 多头节奏成立。", en: "HTF swings stepping higher — bullish rhythm intact.")
        case "trend_down":
            return L10n.zh("HTF 摆动逐次走低 — 空头节奏成立。", en: "HTF swings stepping lower — bearish rhythm intact.")
        case "range":
            return L10n.zh("价格在区间内振荡，等待方向选择。", en: "price oscillates within a range, awaiting resolution.")
        case "high_volatility":
            return L10n.zh("波动率扩张 — 结构信号易失真。", en: "volatility expanded — structure signals are noisier.")
        case "panic":
            return L10n.zh("情绪性甩卖 — 防御为先。", en: "emotional flush — defense first.")
        default:
            return L10n.zh("尚未识别状态。", en: "regime not yet identified.")
        }
    }

    private var regimeColor: Color {
        switch vm.regime {
        case "trend_up": return PulseColors.StateColors.green
        case "trend_down": return PulseColors.StateColors.red
        case "range": return PulseColors.StateColors.yellow
        case "high_volatility": return PulseColors.StateColors.orange
        case "panic": return PulseColors.StateColors.orangeRed
        default: return colors.textSecondary
        }
    }

    private var scoreColor: Color {
        if vm.score >= 70 { return PulseColors.StateColors.green }
        if vm.score >= 40 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.red
    }

    private var pdLabel: String {
        switch vm.premiumDiscount {
        case "premium": return L10n.Structure.premium
        case "discount": return L10n.Structure.discount
        case "equilibrium": return L10n.Structure.equilibrium
        default: return "—"
        }
    }

    private var pdColor: Color {
        switch vm.premiumDiscount {
        case "premium": return PulseColors.StateColors.red
        case "discount": return PulseColors.StateColors.green
        case "equilibrium": return colors.textSecondary
        default: return colors.textMuted
        }
    }

    private var activeZoneCount: Int { vm.zones.filter { $0.status == "active" }.count }
    private var activePoolCount: Int { vm.pools.filter { $0.status == "active" }.count }

    private var currentPrice: Double {
        // Use midpoint of nearest zone as proxy when ticker is absent
        guard !vm.zones.isEmpty else { return 0 }
        let mids = vm.zones.map { ($0.priceTop + $0.priceBottom) / 2 }
        return mids.reduce(0, +) / Double(mids.count)
    }

    private func signedDistance(_ zone: StructureZoneResponse) -> Double {
        let mid = (zone.priceTop + zone.priceBottom) / 2
        guard currentPrice > 0 else { return 0 }
        return (mid - currentPrice) / currentPrice
    }

    private func absDistance(_ zone: StructureZoneResponse) -> Double {
        abs(signedDistance(zone))
    }

    private func zoneTypeLabel(_ zone: StructureZoneResponse) -> String {
        switch zone.zoneType {
        case "fvg": return "FVG"
        case "order_block": return "OB"
        case "liquidity_pool": return "LP"
        default: return zone.zoneType.uppercased()
        }
    }

    private func zoneRoleLabel(_ zone: StructureZoneResponse) -> String {
        zone.direction == "bullish"
            ? L10n.zh("需求", en: "DEMAND")
            : L10n.zh("供给", en: "SUPPLY")
    }

    private func zoneDirectionColor(_ zone: StructureZoneResponse) -> Color {
        switch zone.zoneType {
        case "fvg": return PulseColors.cyan
        case "liquidity_pool": return PulseColors.purple
        default:
            return zone.direction == "bullish" ? PulseColors.StateColors.green : PulseColors.StateColors.red
        }
    }

    private func zoneNarrative(_ zone: StructureZoneResponse) -> String {
        let direction = zone.direction == "bullish"
            ? L10n.zh("多头", en: "bullish")
            : L10n.zh("空头", en: "bearish")
        switch zone.zoneType {
        case "order_block":
            return L10n.zh(
                "\(direction)订单块 — 机构在此布单留下的足迹。",
                en: "\(direction) order block — institutional footprint left at this level."
            )
        case "fvg":
            let pct = Int(zone.filledRatio * 100)
            return L10n.zh(
                "公允价值缺口 · 已填充 \(pct)% — 失衡仍在等待回补。",
                en: "fair value gap · \(pct)% filled — imbalance still waiting to be rebalanced."
            )
        case "liquidity_pool":
            return L10n.zh("流动性聚集 — 触发后或反转或继续。", en: "liquidity cluster — reaction here decides reversal or continuation.")
        default:
            return zone.reasonCodes.first ?? ""
        }
    }

    private func eventLabel(_ event: StructureEventResponse) -> String {
        switch event.eventType {
        case "bos": return "BoS"
        case "choch": return "CHoCH"
        case "sweep": return "Sweep"
        case "fvg_fill": return "FVG Fill"
        default: return event.eventType.uppercased()
        }
    }

    private func eventColor(_ event: StructureEventResponse) -> Color {
        switch event.eventType {
        case "bos": return event.direction == "bullish" ? PulseColors.StateColors.green : PulseColors.StateColors.red
        case "choch": return PulseColors.StateColors.yellow
        case "sweep": return PulseColors.StateColors.orangeRed
        case "fvg_fill": return PulseColors.cyan
        default: return colors.textSecondary
        }
    }

    private func eventNarrative(_ event: StructureEventResponse) -> String {
        let side = event.direction == "bullish"
            ? L10n.zh("买方", en: "buy-side")
            : L10n.zh("卖方", en: "sell-side")
        switch event.eventType {
        case "sweep":
            return L10n.zh("\(side)流动性被横扫 — 止损被收割。", en: "\(side) liquidity swept — stops harvested above prior extreme.")
        case "bos":
            return L10n.zh("突破前摆动结构 — 趋势延续确认。", en: "broke prior swing — confirms trend continuation.")
        case "choch":
            return L10n.zh("结构特征反转 — 趋势可能转向。", en: "character of structure flipped — trend may rotate.")
        case "fvg_fill":
            return L10n.zh("填补冲量留下的失衡缺口。", en: "filled the imbalance left by an impulsive leg.")
        default:
            return ""
        }
    }

    private func poolNarrative(_ pool: LiquidityPoolBFFResponse) -> String {
        let typeText: String
        switch pool.poolType {
        case "equal_high": typeText = L10n.zh("等高点", en: "equal highs")
        case "equal_low": typeText = L10n.zh("等低点", en: "equal lows")
        case "swing_high": typeText = L10n.zh("波段高点", en: "swing high")
        case "swing_low": typeText = L10n.zh("波段低点", en: "swing low")
        default: typeText = pool.poolType
        }
        let sideText = pool.side == "buy_side"
            ? L10n.zh("买方止损", en: "buy-side stops")
            : L10n.zh("卖方止损", en: "sell-side stops")
        return "\(typeText) · \(sideText)"
    }

    private func poolSideColor(_ pool: LiquidityPoolBFFResponse) -> Color {
        pool.side == "buy_side" ? PulseColors.StateColors.green : PulseColors.StateColors.red
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "active": return L10n.Common.active
        case "touched": return L10n.zh("已触及", en: "TOUCHED")
        case "mitigated": return L10n.zh("已缓解", en: "MITIGATED")
        case "invalidated": return L10n.zh("失效", en: "INVALIDATED")
        case "swept": return L10n.zh("被扫", en: "SWEPT")
        default: return status.uppercased()
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return PulseColors.StateColors.green
        case "touched": return PulseColors.StateColors.orange
        case "mitigated": return PulseColors.StateColors.yellow
        case "invalidated": return PulseColors.StateColors.gray
        case "swept": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }
}

// MARK: - Symbol Picker Panel

private struct SymbolPickerPanel: View {
    let allSymbols: [String]
    let recent: [String]
    let currentSymbol: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @Environment(PulseColors.self) private var colors
    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !q.isEmpty else { return allSymbols }
        return allSymbols.filter { $0.uppercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(colors.textMuted)
                TextField(L10n.zh("搜索交易对…", en: "Search symbol…"), text: $query)
                    .textFieldStyle(.plain)
                    .font(PulseFonts.body)
                    .focused($focused)
                    .onSubmit {
                        if let first = filtered.first {
                            onSelect(first)
                        }
                    }
            }
            .padding(PulseSpacing.md)
            .background(colors.surfaceHover.opacity(0.5))

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if query.isEmpty && !recent.isEmpty {
                        sectionHeader(L10n.zh("最近", en: "RECENT"))
                        ForEach(recent.prefix(5), id: \.self) { sym in
                            symbolRow(sym, isCurrent: sym == currentSymbol)
                        }
                        sectionHeader(L10n.zh("全部", en: "ALL SYMBOLS"))
                    } else if !query.isEmpty {
                        sectionHeader(L10n.zh("结果", en: "RESULTS"))
                    } else {
                        sectionHeader(L10n.zh("全部", en: "ALL SYMBOLS"))
                    }

                    let listSource = query.isEmpty ? allSymbols : filtered
                    ForEach(listSource, id: \.self) { sym in
                        symbolRow(sym, isCurrent: sym == currentSymbol)
                    }

                    if !query.isEmpty && filtered.isEmpty {
                        HStack {
                            Text(L10n.zh("未找到匹配的交易对", en: "No matching symbol"))
                                .font(.system(size: 13, design: .serif).italic())
                                .foregroundStyle(colors.textMuted)
                            Spacer()
                        }
                        .padding(PulseSpacing.md)
                    }
                }
            }
            .frame(maxHeight: 360)

            Divider().opacity(0.3)

            // Shortcut footer
            HStack(spacing: PulseSpacing.md) {
                shortcutHint("↵", L10n.zh("选择", en: "Select"))
                shortcutHint("↑↓", L10n.zh("移动", en: "Navigate"))
                shortcutHint("ESC", L10n.zh("关闭", en: "Close"))
                Spacer()
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(colors.surfaceHover.opacity(0.3))
        }
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.lg)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.lg)
                .stroke(colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .tracking(2)
            .foregroundStyle(colors.textMuted)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.top, PulseSpacing.sm)
            .padding(.bottom, PulseSpacing.xxs)
    }

    @ViewBuilder
    private func symbolRow(_ symbol: String, isCurrent: Bool) -> some View {
        Button {
            onSelect(symbol)
        } label: {
            HStack(spacing: PulseSpacing.sm) {
                Text(symbol)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                }
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isCurrent
                ? PulseColors.accent.opacity(0.08)
                : Color.clear
        )
    }

    @ViewBuilder
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(PulseFonts.micro)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(colors.textMuted.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(colors.textSecondary)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }
}

// MARK: - Helpers

private func formatPrice(_ value: Double) -> String {
    if value >= 1000 {
        return String(format: "%.1f", value)
    } else if value >= 1 {
        return String(format: "%.2f", value)
    } else {
        return String(format: "%.4f", value)
    }
}

private func formatTimestamp(_ ts: String) -> String {
    if let range = ts.range(of: #"\d{2}:\d{2}:\d{2}"#, options: .regularExpression) {
        return String(ts[range])
    }
    return String(ts.suffix(8))
}
