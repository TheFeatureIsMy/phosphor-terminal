// StopProtectionView.swift — 止损保护（War Room 风格重新设计）

import SwiftUI

struct StopProtectionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var viewModel: RiskCenterViewModel?
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Atmospheric background
            atmosphericBackground

            VStack(spacing: 0) {
                if let vm = viewModel {
                    if vm.isLoading && vm.stopProtection == nil {
                        LoadingView(type: .detail)
                            .padding(PulseSpacing.lg)
                    } else if let data = vm.stopProtection {
                        // Header
                        headerSection(vm, data: data)

                        Divider().foregroundStyle(colors.border)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: PulseSpacing.lg) {
                                // State banner
                                stateBanner(data)

                                // Position cards
                                ForEach(Array(data.positions.enumerated()), id: \.element.id) { index, position in
                                    positionCard(position)
                                        .staggeredAppearance(index: index)
                                }

                                if data.positions.isEmpty {
                                    EmptyStateView(
                                        icon: "shield.lefthalf.filled",
                                        title: L10n.zh("暂无持仓", en: "No Positions"),
                                        description: L10n.zh("当前没有需要止损保护的持仓", en: "No positions currently require stop protection")
                                    )
                                }
                            }
                            .padding(PulseSpacing.xl)
                        }
                        .scrollEdgeEffectStyle(.soft, for: .vertical)
                    } else if let error = vm.error {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: L10n.zh("加载失败", en: "Load Failed"),
                            description: error,
                            primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.loadStopProtection() } })
                        )
                        .padding(PulseSpacing.lg)
                    } else {
                        EmptyStateView(
                            icon: "shield.lefthalf.filled",
                            title: L10n.zh("暂无止损数据", en: "No Stop Data"),
                            description: L10n.zh("止损保护系统尚未返回数据", en: "Stop protection system has not returned data")
                        )
                        .padding(PulseSpacing.lg)
                    }
                }
            }
        }
        .task {
            let vm = RiskCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadStopProtection()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        let stateColor = overallStateColor
        return ZStack {
            colors.background

            RadialGradient(
                colors: [
                    stateColor.opacity(0.06 + pulsePhase * 0.03),
                    stateColor.opacity(0.01),
                    Color.clear,
                ],
                center: .top,
                startRadius: 40,
                endRadius: 450
            )

            // Subtle scanlines
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.006)))
                }
            }
        }
        .ignoresSafeArea()
    }

    private var overallStateColor: Color {
        guard let data = viewModel?.stopProtection else { return PulseColors.accent }
        switch data.state {
        case "healthy": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "emergency", "locked": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.orange
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: RiskCenterViewModel, data: StopProtectionBFFResponse) -> some View {
        HStack {
            TerminalLabel(text: L10n.zh("止损保护", en: "STOP PROTECTION"))

            // Position count badge
            Text("\(data.positions.count)")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(colors.surface)
                .clipShape(Capsule())

            Spacer()

            Button {
                Task { await vm.loadStopProtection() }
            } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text(L10n.zh("刷新全部", en: "Refresh All"))
                        .font(PulseFonts.monoLabel)
                }
                .foregroundStyle(PulseColors.accent)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    // MARK: - State Banner

    @ViewBuilder
    private func stateBanner(_ data: StopProtectionBFFResponse) -> some View {
        if data.state != "healthy" {
            HStack(spacing: PulseSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(PulseColors.StateColors.orange.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Circle()
                        .stroke(PulseColors.StateColors.orange.opacity(0.3 * pulsePhase), lineWidth: 1.5)
                        .frame(width: 38, height: 38)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PulseColors.StateColors.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.zh("止损保护异常", en: "Stop Protection Anomaly"))
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !data.reasonCodes.isEmpty {
                        HStack(spacing: PulseSpacing.xs) {
                            ForEach(data.reasonCodes, id: \.self) { code in
                                Text(code)
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(PulseColors.StateColors.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PulseColors.StateColors.orange.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Spacer()

                Text(data.state.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(PulseColors.StateColors.orange)
                    .tracking(1.5)
            }
            .padding(PulseSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(PulseColors.StateColors.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .stroke(PulseColors.StateColors.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Position Card

    private func positionCard(_ position: PositionStopResponse) -> some View {
        let sideColor = position.side.lowercased() == "long" ? PulseColors.StateColors.green : PulseColors.StateColors.red

        return KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // Top: Symbol + Side + Volatility Lock
                HStack(alignment: .center) {
                    // Symbol
                    Text(position.symbol)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)

                    // Side badge
                    Text(position.side.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(sideColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(sideColor.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    // Volatility lock badge
                    if position.stops.volatilityLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text(L10n.zh("波动率锁定", en: "VOL LOCKED"))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(PulseColors.StateColors.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PulseColors.StateColors.red.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PulseColors.StateColors.red.opacity(0.4 * pulsePhase), lineWidth: 1.5)
                        )
                    }

                    // Action buttons
                    HStack(spacing: PulseSpacing.xs) {
                        Button {
                            // Refresh action placeholder
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseColors.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            // Force lock placeholder
                        } label: {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseColors.StateColors.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Main content: Price ladder + Stop levels
                HStack(alignment: .top, spacing: PulseSpacing.lg) {
                    // Left: Visual price ladder
                    priceLadder(position)
                        .frame(width: 140)

                    // Right: Stop levels grid
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text(L10n.zh("止损层级", en: "STOP LEVELS"))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .tracking(1)

                        stopLevelPill(
                            label: L10n.zh("原始结构止损", en: "Raw Structure"),
                            value: position.stops.rawStructureStop,
                            color: PulseColors.StateColors.gray,
                            icon: "square.stack.3d.up"
                        )
                        stopLevelPill(
                            label: L10n.zh("最后已知好止损", en: "Last Known Good"),
                            value: position.stops.lastKnownGoodStop,
                            color: PulseColors.StateColors.yellow,
                            icon: "bookmark.fill"
                        )
                        stopLevelPill(
                            label: L10n.zh("安全运行时止损", en: "Secure Runtime"),
                            value: position.stops.secureRuntimeStop,
                            color: PulseColors.StateColors.green,
                            icon: "shield.checkered"
                        )
                        stopLevelPill(
                            label: L10n.zh("交易所保护止损", en: "Exchange Protective"),
                            value: position.stops.exchangeProtectiveStop,
                            color: PulseColors.StateColors.red,
                            icon: "exclamationmark.octagon.fill"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Bottom: Reason codes
                if !position.reasonCodes.isEmpty {
                    Divider().foregroundStyle(colors.border.opacity(0.5))

                    HStack(spacing: PulseSpacing.xs) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(colors.textMuted)

                        ForEach(position.reasonCodes, id: \.self) { code in
                            HStack(spacing: 3) {
                                Image(systemName: reasonCodeIcon(code))
                                    .font(.system(size: 9))
                                Text(code)
                                    .font(PulseFonts.micro)
                            }
                            .foregroundStyle(reasonCodeColor(code))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(reasonCodeColor(code).opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Price Ladder

    private func priceLadder(_ position: PositionStopResponse) -> some View {
        let allPrices = collectPrices(position)
        let minPrice = allPrices.min() ?? 0
        let maxPrice = allPrices.max() ?? 1
        let range = max(maxPrice - minPrice, 0.01)

        return VStack(spacing: 0) {
            // Price range labels
            HStack {
                Text(L10n.zh("价格梯", en: "LADDER"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .tracking(1)
                Spacer()
            }
            .padding(.bottom, PulseSpacing.xs)

            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colors.surface)
                        .frame(width: 4)
                        .frame(maxHeight: .infinity)
                        .position(x: 12, y: height / 2)

                    // Entry price marker
                    priceLadderMarker(
                        price: position.entryPrice,
                        label: L10n.zh("入场", en: "ENTRY"),
                        color: colors.textSecondary,
                        minPrice: minPrice,
                        range: range,
                        height: height,
                        width: width
                    )

                    // Current price marker
                    priceLadderMarker(
                        price: position.currentPrice,
                        label: L10n.zh("当前", en: "NOW"),
                        color: PulseColors.accent,
                        minPrice: minPrice,
                        range: range,
                        height: height,
                        width: width,
                        emphasized: true
                    )

                    // Stop level markers
                    if let raw = position.stops.rawStructureStop {
                        priceLadderNotch(price: raw, color: PulseColors.StateColors.gray, minPrice: minPrice, range: range, height: height)
                    }
                    if let lkg = position.stops.lastKnownGoodStop {
                        priceLadderNotch(price: lkg, color: PulseColors.StateColors.yellow, minPrice: minPrice, range: range, height: height)
                    }
                    if let secure = position.stops.secureRuntimeStop {
                        priceLadderNotch(price: secure, color: PulseColors.StateColors.green, minPrice: minPrice, range: range, height: height)
                    }
                    if let exch = position.stops.exchangeProtectiveStop {
                        priceLadderNotch(price: exch, color: PulseColors.StateColors.red, minPrice: minPrice, range: range, height: height)
                    }
                }
            }
            .frame(height: 140)
        }
    }

    private func priceLadderMarker(price: Double, label: String, color: Color, minPrice: Double, range: Double, height: CGFloat, width: CGFloat, emphasized: Bool = false) -> some View {
        let yPos = height - ((price - minPrice) / range) * height

        return HStack(spacing: 4) {
            // Dot on the bar
            Circle()
                .fill(color)
                .frame(width: emphasized ? 10 : 7, height: emphasized ? 10 : 7)
                .shadow(color: emphasized ? color.opacity(0.5) : .clear, radius: 4)

            // Label + value
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.8))
                Text(String(format: "%.2f", price))
                    .font(.system(size: 10, weight: emphasized ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
        .position(x: width / 2 + 10, y: max(12, min(height - 12, yPos)))
    }

    private func priceLadderNotch(price: Double, color: Color, minPrice: Double, range: Double, height: CGFloat) -> some View {
        let yPos = height - ((price - minPrice) / range) * height

        return RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 14, height: 3)
            .shadow(color: color.opacity(0.4), radius: 2)
            .position(x: 12, y: max(4, min(height - 4, yPos)))
    }

    private func collectPrices(_ position: PositionStopResponse) -> [Double] {
        var prices: [Double] = [position.entryPrice, position.currentPrice]
        if let v = position.stops.rawStructureStop { prices.append(v) }
        if let v = position.stops.lastKnownGoodStop { prices.append(v) }
        if let v = position.stops.secureRuntimeStop { prices.append(v) }
        if let v = position.stops.exchangeProtectiveStop { prices.append(v) }
        return prices.filter { $0 > 0 }
    }

    // MARK: - Stop Level Pill

    private func stopLevelPill(label: String, value: Double?, color: Color, icon: String) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 20)

            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                if let v = value {
                    Text(String(format: "%.2f", v))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color)
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(colors.textMuted.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.vertical, PulseSpacing.xxs)
        .padding(.horizontal, PulseSpacing.xs)
        .background(color.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Helpers

    private func reasonCodeIcon(_ code: String) -> String {
        if code.contains("valid") || code.contains("intact") {
            return "checkmark.circle.fill"
        } else if code.contains("violated") || code.contains("breach") {
            return "xmark.circle.fill"
        } else if code.contains("warning") || code.contains("stale") {
            return "exclamationmark.triangle.fill"
        }
        return "info.circle.fill"
    }

    private func reasonCodeColor(_ code: String) -> Color {
        if code.contains("valid") || code.contains("intact") {
            return PulseColors.StateColors.green
        } else if code.contains("violated") || code.contains("breach") {
            return PulseColors.StateColors.red
        } else if code.contains("warning") || code.contains("stale") {
            return PulseColors.StateColors.yellow
        }
        return PulseColors.StateColors.gray
    }
}
