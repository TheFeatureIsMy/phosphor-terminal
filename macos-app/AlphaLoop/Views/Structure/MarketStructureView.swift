// MarketStructureView.swift — 市场结构 (Redesigned)

import SwiftUI

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

    private let symbols = ["BTC/USDT", "ETH/USDT"]
    private let timeframes = ["5m", "15m", "1h", "4h"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                headerSection
                warningBanner
                summaryCardsRow
                structureZonesSection
                liquidityPoolsSection
                structureEventsSection
            }
            .padding(PulseSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center, spacing: PulseSpacing.sm) {
            Text(L10n.Structure.title)
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            Picker("", selection: $vm.selectedSymbol) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(PulseFonts.monoLabel)
                        .tag(symbol)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Picker("", selection: $vm.selectedTimeframe) {
                ForEach(timeframes, id: \.self) { tf in
                    Text(tf)
                        .font(PulseFonts.monoLabel)
                        .tag(tf)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseColors.accent)
                    .frame(width: 28, height: 28)
                    .background(PulseColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
            }
            .buttonStyle(.plain)
            .disabled(vm.isLoading)
        }
        .onChange(of: vm.selectedSymbol) { _, _ in
            Task { await vm.load() }
        }
        .onChange(of: vm.selectedTimeframe) { _, _ in
            Task { await vm.load() }
        }
    }

    // MARK: - Warning Banner

    @ViewBuilder
    private var warningBanner: some View {
        if let data = vm.data, data.state != "healthy", !data.reasonCodes.isEmpty {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PulseColors.StateColors.yellow)
                    .font(.system(size: 12))

                Text(L10n.Common.abnormal + ":")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(PulseColors.StateColors.yellow)

                Text(data.reasonCodes.joined(separator: " · "))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(PulseColors.StateColors.yellow.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(PulseColors.StateColors.yellow.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Summary Cards Row

    @ViewBuilder
    private var summaryCardsRow: some View {
        if vm.isLoading && vm.data == nil {
            LoadingView(type: .detail)
        } else {
            HStack(spacing: PulseSpacing.sm) {
                SummaryMetricCard(label: L10n.Structure.marketState) {
                    RegimeBadge(regime: vm.regime)
                }

                SummaryMetricCard(label: L10n.Structure.structureScore) {
                    ScoreGauge(score: vm.score)
                }

                SummaryMetricCard(label: L10n.Structure.premiumDiscount) {
                    PremiumDiscountBadge(value: vm.premiumDiscount)
                }

                SummaryMetricCard(label: L10n.Structure.activeZones) {
                    CountDisplay(
                        count: vm.zones.filter { $0.status == "active" }.count,
                        total: vm.zones.count,
                        icon: "square.stack.3d.up"
                    )
                }

                SummaryMetricCard(label: L10n.Structure.liquidityPools) {
                    CountDisplay(
                        count: vm.pools.filter { $0.status == "active" }.count,
                        total: vm.pools.count,
                        icon: "drop.fill"
                    )
                }
            }
        }
    }

    // MARK: - Structure Zones Section (Card Grid)

    @ViewBuilder
    private var structureZonesSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Structure.zones)

            if vm.zones.isEmpty {
                KryptonCard(emphasis: .subtle) {
                    EmptyStateView(
                        icon: "square.stack.3d.up",
                        title: L10n.Common.noData,
                        description: ""
                    )
                }
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: PulseSpacing.sm),
                    GridItem(.flexible(), spacing: PulseSpacing.sm),
                ]
                LazyVGrid(columns: columns, spacing: PulseSpacing.sm) {
                    ForEach(Array(vm.zones.enumerated()), id: \.element.id) { index, zone in
                        ZoneCard(zone: zone, isSelected: vm.selectedZone?.id == zone.id)
                            .staggeredAppearance(index: index)
                            .hoverEffect()
                            .onTapGesture {
                                vm.selectedZone = (vm.selectedZone?.id == zone.id) ? nil : zone
                            }
                    }
                }
            }
        }
    }

    // MARK: - Liquidity Pools Section (Horizontal Scroll)

    @ViewBuilder
    private var liquidityPoolsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Structure.liquidityPools)

            if vm.pools.isEmpty {
                KryptonCard(emphasis: .subtle) {
                    EmptyStateView(
                        icon: "drop.fill",
                        title: L10n.Common.noData,
                        description: ""
                    )
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PulseSpacing.sm) {
                        ForEach(Array(vm.pools.enumerated()), id: \.element.id) { index, pool in
                            PoolCard(pool: pool)
                                .staggeredAppearance(index: index)
                                .hoverEffect()
                        }
                    }
                    .padding(.vertical, PulseSpacing.xxs)
                }
            }
        }
    }

    // MARK: - Structure Events Section (Timeline)

    @ViewBuilder
    private var structureEventsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Structure.events)

            if vm.events.isEmpty {
                KryptonCard(emphasis: .subtle) {
                    EmptyStateView(
                        icon: "bolt.fill",
                        title: L10n.Common.noData,
                        description: ""
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.events.enumerated()), id: \.element.id) { index, event in
                        TimelineEventRow(event: event, isLast: index == vm.events.count - 1)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
    }
}

// MARK: - Zone Card (Grid Item)

private struct ZoneCard: View {
    let zone: StructureZoneResponse
    let isSelected: Bool
    @Environment(PulseColors.self) private var colors
    @State private var showPopover = false

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Top: zone type icon + label + direction badge
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: zoneTypeIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(directionColor)

                    TermText(term: zoneTypeLabel, fontSize: 11)

                    Spacer()

                    // Direction badge
                    HStack(spacing: 2) {
                        Image(systemName: zone.direction == "bullish" ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(zone.direction == "bullish" ? L10n.Structure.bullish : L10n.Structure.bearish)
                            .font(PulseFonts.micro)
                    }
                    .foregroundStyle(directionColor)
                    .padding(.horizontal, PulseSpacing.xxs)
                    .padding(.vertical, 2)
                    .background(directionColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
                }

                // Middle: price range visualization bar
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack {
                        Text(formatPrice(zone.priceBottom))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(colors.textSecondary)
                        Spacer()
                        Text(formatPrice(zone.priceTop))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(colors.textSecondary)
                    }

                    // Price range bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colors.textMuted.opacity(0.1))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [directionColor.opacity(0.6), directionColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * rangeWidth, height: 6)
                                .offset(x: geo.size.width * rangeOffset)
                        }
                    }
                    .frame(height: 6)
                }

                // Bottom: strength bar + fill rate + status badge
                HStack(spacing: PulseSpacing.sm) {
                    StrengthBar(value: zone.currentStrength)
                        .frame(maxWidth: .infinity)

                    if zone.zoneType == "fvg" {
                        Text("\(Int(zone.filledRatio * 100))%")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    ZoneStatusBadge(status: zone.status)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(isSelected ? PulseColors.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ZoneDetailPopover(zone: zone)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { showPopover = true }
        )
    }

    private var rangeWidth: CGFloat {
        // Normalized width between 0.3 and 1.0 based on strength
        CGFloat(0.3 + zone.currentStrength * 0.7)
    }

    private var rangeOffset: CGFloat {
        // Center the range bar
        CGFloat((1.0 - (0.3 + zone.currentStrength * 0.7)) * 0.5)
    }

    private var zoneTypeIcon: String {
        switch zone.zoneType {
        case "fvg": return "rectangle.split.3x1"
        case "order_block": return "square.stack.3d.up"
        case "liquidity_pool": return "drop.fill"
        default: return "square.dashed"
        }
    }

    private var zoneTypeLabel: String {
        switch zone.zoneType {
        case "fvg": return "FVG"
        case "order_block": return "OB"
        case "liquidity_pool": return "LP"
        default: return zone.zoneType.uppercased()
        }
    }

    private var directionColor: Color {
        zone.direction == "bullish" ? PulseColors.StateColors.green : PulseColors.StateColors.red
    }
}

// MARK: - Zone Detail Popover

private struct ZoneDetailPopover: View {
    let zone: StructureZoneResponse
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                TermText(term: zoneTypeLabel, fontSize: 13)
                Spacer()
                ZoneStatusBadge(status: zone.status)
            }

            Divider().opacity(0.3)

            LabeledContent(L10n.Structure.direction) {
                Text(zone.direction == "bullish" ? L10n.Structure.bullish : L10n.Structure.bearish)
                    .font(PulseFonts.captionMedium)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            LabeledContent(L10n.Structure.priceRange) {
                Text("\(formatPrice(zone.priceBottom)) – \(formatPrice(zone.priceTop))")
                    .font(PulseFonts.tabular)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            LabeledContent(L10n.Structure.strength) {
                Text(String(format: "%.0f%%", zone.currentStrength * 100))
                    .font(PulseFonts.tabular)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            if zone.zoneType == "fvg" {
                LabeledContent(L10n.Structure.fillRate) {
                    Text(String(format: "%.0f%%", zone.filledRatio * 100))
                        .font(PulseFonts.tabular)
                }
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
            }

            LabeledContent(L10n.Structure.timeframe) {
                Text(zone.timeframe)
                    .font(PulseFonts.monoLabel)
            }
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)

            if !zone.reasonCodes.isEmpty {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    ForEach(zone.reasonCodes, id: \.self) { code in
                        Text(code)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.StateColors.yellow)
                            .padding(.horizontal, PulseSpacing.xxs)
                            .padding(.vertical, 1)
                            .background(PulseColors.StateColors.yellow.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .frame(width: 260)
    }

    private var zoneTypeLabel: String {
        switch zone.zoneType {
        case "fvg": return "FVG"
        case "order_block": return "OB"
        case "liquidity_pool": return "LP"
        default: return zone.zoneType.uppercased()
        }
    }
}

// MARK: - Pool Card (Horizontal Scroll Item)

private struct PoolCard: View {
    let pool: LiquidityPoolBFFResponse
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Pool type icon + label
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: poolTypeIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(sideColor)

                    Text(poolTypeLabel)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                }

                // Side badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(sideColor)
                        .frame(width: 6, height: 6)
                    Text(sideLabel)
                        .font(PulseFonts.micro)
                        .foregroundStyle(sideColor)
                }
                .padding(.horizontal, PulseSpacing.xxs)
                .padding(.vertical, 2)
                .background(sideColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

                // Price level
                Text(formatPrice(pool.priceLevel))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)

                // Strength gauge
                StrengthBar(value: pool.currentStrength)

                // Touch count
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.textMuted)
                    Text("\(pool.touchedCount)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textSecondary)
                    Text(L10n.Structure.touchCount)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .frame(width: 200)
    }

    private var poolTypeIcon: String {
        switch pool.poolType {
        case "equal_high": return "equal"
        case "equal_low": return "equal"
        case "swing_high": return "chart.line.uptrend.xyaxis"
        case "swing_low": return "chart.line.downtrend.xyaxis"
        default: return "drop.fill"
        }
    }

    private var poolTypeLabel: String {
        switch pool.poolType {
        case "equal_high": return L10n.Structure.equalHigh
        case "equal_low": return L10n.Structure.equalLow
        case "swing_high": return L10n.Structure.swingHigh
        case "swing_low": return L10n.Structure.swingLow
        default: return pool.poolType
        }
    }

    private var sideColor: Color {
        pool.side == "buy_side" ? PulseColors.StateColors.green : PulseColors.StateColors.red
    }

    private var sideLabel: String {
        pool.side == "buy_side" ? L10n.Structure.buySide : L10n.Structure.sellSide
    }
}

// MARK: - Timeline Event Row

private struct TimelineEventRow: View {
    let event: StructureEventResponse
    let isLast: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Left side: timeline line + dot
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: eventColor.opacity(0.4), radius: 3)

                if !isLast {
                    Rectangle()
                        .fill(PulseColors.accent.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Right side: content card
            KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.sm) {
                    // Event type badge
                    HStack(spacing: 3) {
                        Image(systemName: eventIcon)
                            .font(.system(size: 9, weight: .semibold))
                        TermText(term: eventLabel, fontSize: 9)
                    }
                    .foregroundStyle(eventColor)
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 3)
                    .background(eventColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

                    // Direction arrow
                    Image(systemName: event.direction == "bullish" ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(event.direction == "bullish" ? PulseColors.StateColors.green : PulseColors.StateColors.red)

                    // Timeframe
                    Text(event.timeframe)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, PulseSpacing.xxs)
                        .padding(.vertical, 1)
                        .background(colors.textMuted.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))

                    // Price
                    Text(formatPrice(event.price))
                        .font(PulseFonts.tabular)
                        .foregroundStyle(colors.textPrimary)

                    Spacer()

                    // Timestamp
                    Text(formatTimestamp(event.timestamp))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .frame(minHeight: 48)
    }

    private var eventIcon: String {
        switch event.eventType {
        case "bos": return "arrow.up.right"
        case "choch": return "arrow.triangle.swap"
        case "sweep": return "wind"
        case "fvg_fill": return "rectangle.compress.vertical"
        default: return "circle.fill"
        }
    }

    private var eventLabel: String {
        switch event.eventType {
        case "bos": return "BOS"
        case "choch": return "CHoCH"
        case "sweep": return "Sweep"
        case "fvg_fill": return "FVG"
        default: return event.eventType.uppercased()
        }
    }

    private var eventColor: Color {
        switch event.eventType {
        case "bos": return PulseColors.StateColors.green
        case "choch": return PulseColors.StateColors.yellow
        case "sweep": return PulseColors.StateColors.orangeRed
        case "fvg_fill": return colors.textSecondary
        default: return colors.textMuted
        }
    }

    private func formatTimestamp(_ ts: String) -> String {
        if let range = ts.range(of: #"\d{2}:\d{2}:\d{2}"#, options: .regularExpression) {
            return String(ts[range])
        }
        return String(ts.suffix(8))
    }
}

// MARK: - Supporting Components

private struct SummaryMetricCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PulseSpacing.sm)
        }
    }
}

private struct RegimeBadge: View {
    let regime: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Circle()
                .fill(regimeColor)
                .frame(width: 6, height: 6)
            Text(regimeLabel)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(regimeColor)
        }
    }

    private var regimeLabel: String {
        switch regime {
        case "trend_up", "trend_down": return L10n.Structure.trending
        case "range": return L10n.Structure.ranging
        case "high_volatility": return L10n.Structure.volatile
        case "panic": return L10n.Common.danger
        default: return "—"
        }
    }

    private var regimeColor: Color {
        switch regime {
        case "trend_up": return PulseColors.StateColors.green
        case "trend_down": return PulseColors.StateColors.red
        case "range": return PulseColors.StateColors.yellow
        case "high_volatility": return PulseColors.StateColors.orange
        case "panic": return PulseColors.StateColors.orangeRed
        default: return PulseColors.StateColors.gray
        }
    }
}

private struct ScoreGauge: View {
    let score: Double
    @Environment(PulseColors.self) private var colors
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            ZStack {
                // Background track
                Circle()
                    .stroke(colors.textMuted.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)

                // Score arc
                Circle()
                    .trim(from: 0, to: score / 100.0)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Animated glow
                Circle()
                    .trim(from: 0, to: score / 100.0)
                    .stroke(gaugeColor.opacity(glowOpacity), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 4)

                Text("\(Int(score))")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(gaugeColor)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.6
                }
            }

            Text("/ 100")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    private var gaugeColor: Color {
        if score >= 70 { return PulseColors.StateColors.green }
        if score >= 40 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.red
    }
}

private struct PremiumDiscountBadge: View {
    let value: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: badgeIcon)
                .font(.system(size: 9, weight: .semibold))
            Text(badgeLabel)
                .font(PulseFonts.monoLabel)
        }
        .foregroundStyle(badgeColor)
    }

    private var badgeLabel: String {
        switch value {
        case "premium": return L10n.Structure.premium
        case "discount": return L10n.Structure.discount
        case "equilibrium": return L10n.Structure.equilibrium
        default: return "—"
        }
    }

    private var badgeIcon: String {
        switch value {
        case "premium": return "arrow.up.circle"
        case "discount": return "arrow.down.circle"
        case "equilibrium": return "equal.circle"
        default: return "minus.circle"
        }
    }

    private var badgeColor: Color {
        switch value {
        case "premium": return PulseColors.StateColors.red
        case "discount": return PulseColors.StateColors.green
        case "equilibrium": return colors.textSecondary
        default: return colors.textMuted
        }
    }
}

private struct CountDisplay: View {
    let count: Int
    let total: Int
    let icon: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(PulseColors.accent.opacity(0.7))
            Text("\(count)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
            Text("/ \(total)")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }
}

private struct StrengthBar: View {
    let value: Double
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.textMuted.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.6), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1.0)), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 60, height: 16)

            Text(String(format: "%.0f%%", value * 100))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if value >= 0.7 { return PulseColors.StateColors.green }
        if value >= 0.4 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.red
    }
}

private struct ZoneStatusBadge: View {
    let status: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        Text(statusLabel)
            .font(PulseFonts.micro)
            .foregroundStyle(statusColor)
            .padding(.horizontal, PulseSpacing.xxs)
            .padding(.vertical, 1)
            .background(statusColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
    }

    private var statusLabel: String {
        switch status {
        case "active": return L10n.Common.active
        case "touched": return L10n.Structure.touchCount
        case "mitigated": return L10n.Structure.stateHealthy
        case "invalidated": return L10n.Common.disabled
        case "swept": return L10n.Structure.sweep
        default: return status
        }
    }

    private var statusColor: Color {
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
