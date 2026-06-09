// StructureMatrixView.swift — Structure Matrix · HTF Tribunal
// Design spec: docs/superpowers/specs/2026-06-10-structure-matrix-htf-tribunal-design.md

import SwiftUI
import AppKit

// MARK: - Root

struct StructureMatrixView: View {
    @Environment(\.networkClient) private var networkClient
    @State private var vm: StructureMatrixViewModel?

    var body: some View {
        Group {
            if let vm = vm {
                StructureMatrixContentView(vm: vm)
            } else {
                LoadingView(type: .grid)
                    .padding(PulseSpacing.lg)
            }
        }
        .task {
            if vm == nil {
                let model = StructureMatrixViewModel(client: networkClient)
                vm = model
                await model.loadAll()
            }
        }
    }
}

// MARK: - Content

private struct StructureMatrixContentView: View {
    @Bindable var vm: StructureMatrixViewModel
    @Environment(PulseColors.self) private var colors

    @State private var symbolPickerOpen: Bool = false
    @State private var detailCell: DetailCellPayload? = nil
    @AppStorage("structure_matrix.recent_symbols") private var recentSymbolsRaw: String = "BTC/USDT,ETH/USDT,SOL/USDT"

    private let allSymbols = [
        "BTC/USDT", "ETH/USDT", "SOL/USDT",
        "AVAX/USDT", "LINK/USDT", "ARB/USDT",
        "BNB/USDT", "XRP/USDT", "DOGE/USDT",
    ]
    private let timeframes = ["5m", "15m", "1h", "4h"]
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                    FastTrackHealthMiniBar(health: vm.fastTrackHealth)
                        .staggeredAppearance(index: 0)

                    TribunalMasthead()
                        .staggeredAppearance(index: 1)

                    controlsBar
                        .staggeredAppearance(index: 2)

                    if vm.isLoading && vm.matrixData == nil {
                        LoadingView(type: .detail)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PulseSpacing.xl)
                    } else if let error = vm.error {
                        errorState(error)
                    } else {
                        TribunalCenterpiece(
                            guard_: vm.mtfGuard,
                            countdownSeconds: vm.countdownSeconds
                        )
                        .staggeredAppearance(index: 3)

                        EvidenceMatrix(
                            rows: orderedRows(vm.matrixData?.rows ?? []),
                            timeframes: timeframes,
                            shadowKeys: shadowKeyLookup(vm.shadowWindows),
                            onCellTap: { payload in detailCell = payload }
                        )
                        .staggeredAppearance(index: 4)

                        ShadowWindowsPanel(windows: vm.shadowWindows?.windows ?? [])
                            .staggeredAppearance(index: 5)

                        ChargesPanel(matrix: vm.matrixData)
                            .staggeredAppearance(index: 6)

                        HearingsTimeline(events: vm.guardEvents?.events ?? [])
                            .staggeredAppearance(index: 7)
                    }
                }
                .padding(.horizontal, PulseSpacing.xl)
                .padding(.vertical, PulseSpacing.lg)
                .frame(maxWidth: 1280, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if symbolPickerOpen {
                SymbolPickerOverlay(
                    isOpen: $symbolPickerOpen,
                    selected: vm.selectedSymbol,
                    recents: recentSymbols,
                    all: allSymbols,
                    onSelect: { sym in
                        vm.selectedSymbol = sym
                        pushRecent(sym)
                        symbolPickerOpen = false
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(10)
            }

            if let payload = detailCell {
                StructureDetailDrawer(
                    payload: payload,
                    onClose: { detailCell = nil }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .onReceive(countdownTimer) { _ in vm.tickCountdown() }
        .onChange(of: vm.selectedSymbol) { _, _ in Task { await vm.loadAll() } }
        .onChange(of: vm.selectedTimeframe) { _, _ in Task { await vm.loadAll() } }
        .background(
            Button("") { symbolPickerOpen.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: 0.2), value: symbolPickerOpen)
        .animation(.easeInOut(duration: 0.2), value: detailCell != nil)
    }

    private var recentSymbols: [String] {
        recentSymbolsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private func pushRecent(_ symbol: String) {
        var list = recentSymbols.filter { $0 != symbol }
        list.insert(symbol, at: 0)
        recentSymbolsRaw = Array(list.prefix(3)).joined(separator: ",")
    }

    private func orderedRows(_ rows: [MatrixRowResponse]) -> [MatrixRowResponse] {
        let order = ["4h", "1h", "15m", "5m"]
        return order.compactMap { tf in rows.first(where: { $0.timeframe == tf }) }
    }

    private func shadowKeyLookup(_ shadows: ShadowWindowsBFFResponse?) -> Set<String> {
        guard let windows = shadows?.windows else { return [] }
        return Set(windows.filter { $0.status == "violation" || $0.status == "reclaim" }
            .map { "\($0.timeframe)|\($0.zoneType)" })
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Button { symbolPickerOpen.toggle() } label: {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                    Text(vm.selectedSymbol)
                        .font(PulseFonts.tabular)
                    Text("⌘K")
                        .font(PulseFonts.micro)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(colors.textMuted.opacity(0.15)))
                }
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(colors.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                )
                .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                ForEach(timeframes, id: \.self) { tf in
                    Button { vm.selectedTimeframe = tf } label: {
                        Text(tf)
                            .font(PulseFonts.captionMedium)
                            .padding(.horizontal, PulseSpacing.sm)
                            .padding(.vertical, 7)
                            .background(
                                vm.selectedTimeframe == tf
                                    ? PulseColors.accent.opacity(0.18)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                vm.selectedTimeframe == tf
                                    ? PulseColors.accent
                                    : colors.textMuted
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.button)
                    .fill(colors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
            )

            Spacer()

            Button { Task { await vm.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.button)
                            .fill(colors.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                    )
                    .foregroundStyle(colors.textPrimary)
                    .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                    .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func errorState(_ error: String) -> some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: L10n.Structure.loadFailed,
            description: error,
            primaryAction: (title: L10n.Structure.retry, action: { Task { await vm.refresh() } })
        )
        .padding(PulseSpacing.lg)
    }
}

// MARK: - Fast Track Health Mini Bar

private struct FastTrackHealthMiniBar: View {
    let health: FastTrackHealthResponse?
    @Environment(PulseColors.self) private var colors

    var body: some View {
        let h = health ?? FastTrackHealthResponse()
        HStack(spacing: PulseSpacing.md) {
            Circle()
                .fill(h.verdictTrustworthy ? PulseColors.accent : PulseColors.StateColors.orange)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle().fill(h.verdictTrustworthy ? PulseColors.accent : PulseColors.StateColors.orange)
                        .frame(width: 8, height: 8)
                        .blur(radius: 4).opacity(0.8)
                )

            HStack(spacing: PulseSpacing.lg) {
                meta(L10n.Structure.labelLatency, "\(h.latencyMs)ms", ok: h.latencyMs < 200)
                meta(L10n.Structure.labelDataAge, String(format: "%.1fs", h.dataAgeSeconds), ok: h.dataAgeSeconds < 3)
                meta(L10n.Structure.labelRedis, h.redisOk ? L10n.Structure.statusOk : L10n.Structure.statusDown, ok: h.redisOk)
            }

            Spacer()

            Text(h.verdictTrustworthy ? L10n.Structure.verdictTrustworthy : L10n.Structure.verdictSuspect)
                .font(PulseFonts.micro)
                .padding(.horizontal, PulseSpacing.sm).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill((h.verdictTrustworthy ? PulseColors.accent : PulseColors.StateColors.orange).opacity(0.15))
                )
                .foregroundStyle(h.verdictTrustworthy ? PulseColors.accent : PulseColors.StateColors.orange)
        }
        .padding(.horizontal, PulseSpacing.md).padding(.vertical, PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.cardBackground.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }

    @ViewBuilder
    private func meta(_ label: String, _ value: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(ok ? colors.textPrimary : PulseColors.StateColors.orange)
        }
    }
}

// MARK: - Masthead

private struct TribunalMasthead: View {
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Structure.tribunalTitle.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(colors.textPrimary)
                Text(L10n.Structure.tribunalSubtitle)
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(currentDateStr)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textSecondary)
                Text("Vol. I · No. 1")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.top, PulseSpacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.border).frame(height: 1).offset(y: PulseSpacing.sm)
        }
        .padding(.bottom, PulseSpacing.sm)
    }

    private var currentDateStr: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy·MM·dd"
        return f.string(from: Date())
    }
}

// MARK: - Tribunal Centerpiece

private struct TribunalCenterpiece: View {
    let guard_: MTFGuardResponse?
    let countdownSeconds: Int
    @Environment(PulseColors.self) private var colors

    private static let states: [(key: String, label: () -> String)] = [
        ("inactive",            { L10n.Structure.stateInactive }),
        ("watching",            { L10n.Structure.stateWatching }),
        ("pending_htf_close",   { L10n.Structure.statePendingHtfClose }),
        ("temporary_violation", { L10n.Structure.stateTemporaryViolation }),
        ("reclaim_pending",     { L10n.Structure.stateReclaimPending }),
        ("confirmed",           { L10n.Structure.stateConfirmed }),
        ("invalidated",         { L10n.Structure.stateInvalidated }),
        ("expired",             { L10n.Structure.stateExpired }),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.lg) {
            stateRail
                .frame(width: 200)

            countdownRing
                .frame(maxWidth: .infinity)

            verdictPanel
                .frame(width: 280)
        }
        .padding(PulseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
        )
    }

    private var currentStateKey: String { guard_?.guardState ?? "inactive" }
    private var currentIndex: Int {
        Self.states.firstIndex(where: { $0.key == currentStateKey }) ?? 0
    }

    @ViewBuilder
    private var stateRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.Structure.stateMachine.uppercased())
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .padding(.bottom, PulseSpacing.sm)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(Self.states.enumerated()), id: \.offset) { idx, state in
                    StateRow(
                        label: state.label(),
                        isCurrent: idx == currentIndex,
                        isPast: idx < currentIndex
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var countdownRing: some View {
        VStack(spacing: PulseSpacing.md) {
            ZStack {
                Circle()
                    .stroke(colors.border.opacity(0.5), lineWidth: 6)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: max(0, min(1, ringProgress)))
                    .stroke(
                        verdictColor.opacity(0.9),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdownSeconds)

                VStack(spacing: 4) {
                    Text(formattedCountdown)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(colors.textPrimary)
                    Text(slowTfLabel + " " + L10n.Structure.candleClosesIn)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private var slowTfLabel: String { (guard_?.violation.slowTimeframe ?? "1h") }
    private var ringProgress: Double {
        // Assume 1h cycle by default. If we knew the period this would be exact.
        let period: Double = periodSecondsFor(slowTfLabel)
        guard period > 0 else { return 0 }
        let remaining = Double(max(countdownSeconds, 0))
        return (period - remaining) / period
    }

    private func periodSecondsFor(_ tf: String) -> Double {
        switch tf {
        case "5m": return 300
        case "15m": return 900
        case "1h": return 3600
        case "4h": return 14400
        default: return 3600
        }
    }

    private var formattedCountdown: String {
        let s = max(countdownSeconds, 0)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }

    @ViewBuilder
    private var verdictPanel: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.Structure.verdict)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)

            Text(verdictWord)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(verdictColor)

            Text(verdictSub)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)

            if let reason = guard_?.reasonCodes.first {
                Text("\"" + humanize(reason) + "\"")
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(3)
                    .padding(.top, PulseSpacing.xs)
            }

            Spacer(minLength: PulseSpacing.sm)

            Button {
                NotificationCenter.default.post(name: .applyVerdictToOrderForm, object: guard_)
            } label: {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.system(size: 12))
                    Text(L10n.Structure.applyToOrderForm)
                        .font(PulseFonts.captionMedium)
                }
                .padding(.horizontal, PulseSpacing.md).padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(verdictColor.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(verdictColor.opacity(0.45), lineWidth: 1))
                )
                .foregroundStyle(verdictColor)
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(verdictColor.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(verdictColor.opacity(0.25), lineWidth: 1))
        )
    }

    private var verdictWord: String {
        switch guard_?.action ?? "ignore" {
        case "allow": return L10n.Structure.verdictAllow
        case "observe": return L10n.Structure.verdictObserve
        case "require_confirmation", "require_confirm": return L10n.Structure.verdictConfirm
        case "reduce_size": return L10n.Structure.verdictReduce
        case "block_entry": return L10n.Structure.verdictBlock
        default: return L10n.Structure.verdictIdle
        }
    }

    private var verdictSub: String {
        switch guard_?.action ?? "ignore" {
        case "allow": return L10n.Structure.verdictSubAllow
        case "observe": return L10n.Structure.verdictSubObserve
        case "require_confirmation", "require_confirm": return L10n.Structure.verdictSubConfirm
        case "reduce_size": return L10n.Structure.verdictSubReduce
        case "block_entry": return L10n.Structure.verdictSubBlock
        default: return L10n.Structure.verdictSubIdle
        }
    }

    private var verdictColor: Color {
        switch guard_?.action ?? "ignore" {
        case "allow": return PulseColors.accent
        case "observe": return PulseColors.StateColors.yellow
        case "require_confirmation", "require_confirm": return PulseColors.StateColors.yellow
        case "reduce_size": return PulseColors.StateColors.orange
        case "block_entry": return PulseColors.StateColors.red
        default: return Color.gray.opacity(0.6)
        }
    }
}

private struct StateRow: View {
    let label: String
    let isCurrent: Bool
    let isPast: Bool
    @Environment(PulseColors.self) private var colors
    @State private var pulse = false

    var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            Rectangle()
                .fill(dotColor)
                .frame(width: 4, height: 16)
                .opacity(isCurrent && pulse ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(textColor)
                .opacity(isCurrent && pulse ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            Spacer(minLength: 0)
        }
        .onAppear { if isCurrent { pulse = true } }
    }

    private var dotColor: Color {
        if isCurrent { return PulseColors.StateColors.orange }
        if isPast { return PulseColors.accent }
        return colors.border
    }
    private var textColor: Color {
        if isCurrent { return colors.textPrimary }
        if isPast { return PulseColors.accent.opacity(0.85) }
        return colors.textMuted.opacity(0.55)
    }
}

// MARK: - Evidence Matrix

private struct EvidenceMatrix: View {
    let rows: [MatrixRowResponse]
    let timeframes: [String]
    let shadowKeys: Set<String>
    let onCellTap: (DetailCellPayload) -> Void
    @Environment(PulseColors.self) private var colors

    private let zoneOrder = ["order_block", "fvg", "liquidity_pool"]
    private var zoneLabels: [String: String] {
        [
            "order_block": L10n.Structure.zoneOrderBlockShort,
            "fvg": L10n.Structure.zoneFvgShort,
            "liquidity_pool": L10n.Structure.zoneLiquidityPoolShort,
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.xs) {
                Text("§").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(PulseColors.accent)
                Text(L10n.Structure.evidenceMatrix)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                Text(L10n.Structure.evidenceMatrixSub)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            VStack(spacing: 1) {
                // Column header
                HStack(spacing: 1) {
                    Text("")
                        .frame(width: 48, alignment: .leading)
                    ForEach(zoneOrder, id: \.self) { z in
                        Text(zoneLabels[z]?.uppercased() ?? z.uppercased())
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }

                ForEach(rows, id: \.timeframe) { row in
                    HStack(spacing: 1) {
                        Text(row.timeframe)
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textSecondary)
                            .frame(width: 48, alignment: .leading)

                        ForEach(zoneOrder, id: \.self) { z in
                            let cell = row.cells[z] ?? MatrixCellResponse(zoneType: z)
                            let isShadow = shadowKeys.contains("\(row.timeframe)|\(z)") || cell.temporaryViolation
                            EvidenceCell(cell: cell, isShadow: isShadow)
                                .onTapGesture {
                                    onCellTap(DetailCellPayload(timeframe: row.timeframe, cell: cell, isShadow: isShadow))
                                }
                        }
                    }
                }
            }
            .background(colors.border.opacity(0.3))
        }
    }
}

private struct EvidenceCell: View {
    let cell: MatrixCellResponse
    let isShadow: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(strengthPct)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if isShadow {
                    Text(L10n.Structure.inShadow)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.StateColors.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(PulseColors.StateColors.orange.opacity(0.15)))
                }
            }

            // Strength heatmap bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.border.opacity(0.4))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(strengthColor)
                        .frame(width: geo.size.width * cell.currentStrength)
                }
            }
            .frame(height: 4)

            if cell.filledRatio > 0 {
                Text("\(L10n.Structure.filled) \(Int(cell.filledRatio * 100))%")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            } else {
                Text(cell.status.uppercased())
                    .font(PulseFonts.micro)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(
            ZStack {
                colors.cardBackground
                if isShadow {
                    ShadowStripes()
                        .opacity(0.25)
                }
            }
        )
        .overlay(
            Rectangle().stroke(isShadow ? PulseColors.StateColors.orange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var strengthPct: String { "\(Int(cell.currentStrength * 100))%" }

    private var strengthColor: Color {
        let s = cell.currentStrength
        if s >= 0.7 { return PulseColors.accent }
        if s >= 0.4 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.orange
    }

    private var statusColor: Color {
        switch cell.status {
        case "active": return PulseColors.accent
        case "warning": return PulseColors.StateColors.orange
        case "broken": return PulseColors.StateColors.red
        default: return colors.textMuted
        }
    }
}

private struct ShadowStripes: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height + 2, y: size.height))
                path.addLine(to: CGPoint(x: x + 2, y: 0))
                path.closeSubpath()
                ctx.fill(path, with: .color(PulseColors.StateColors.orange.opacity(0.6)))
                x += step
            }
        }
    }
}

struct DetailCellPayload: Equatable {
    let timeframe: String
    let cell: MatrixCellResponse
    let isShadow: Bool

    static func == (lhs: DetailCellPayload, rhs: DetailCellPayload) -> Bool {
        lhs.timeframe == rhs.timeframe && lhs.cell.zoneType == rhs.cell.zoneType
    }
}

// MARK: - Shadow Windows Panel

private struct ShadowWindowsPanel: View {
    let windows: [ShadowWindowResponse]
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.xs) {
                Text("§").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(PulseColors.accent)
                Text(L10n.Structure.shadowWindows)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                Text(L10n.Structure.shadowWindowsSub)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            if windows.isEmpty {
                Text(L10n.Structure.noActiveShadowWindows)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .padding(PulseSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.cardBackground.opacity(0.4)))
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: PulseSpacing.md),
                    GridItem(.flexible(), spacing: PulseSpacing.md),
                ], spacing: PulseSpacing.md) {
                    ForEach(windows) { w in
                        ShadowWindowCard(window: w)
                    }
                }
            }
        }
    }
}

private struct ShadowWindowCard: View {
    let window: ShadowWindowResponse
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Text("\(window.fastTimeframe ?? "?") → \(window.slowTimeframe ?? window.timeframe)")
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text(window.status.uppercased())
                    .font(PulseFonts.micro)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(stateColor.opacity(0.18)))
                    .foregroundStyle(stateColor)
            }

            Text("\(window.zoneType) · \(window.direction ?? "—")")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)

            HStack(spacing: PulseSpacing.md) {
                stat(L10n.Structure.statFast, "\(window.fastCandleCount)")
                stat(L10n.Structure.statViol, "\(window.violationCount)")
                stat(L10n.Structure.statReclaim, "\(window.reclaimCount)")
                stat(L10n.Structure.statFill, String(format: "%.2f", window.filledRatio))
            }

            // 12-segment candle progress
            HStack(spacing: 2) {
                ForEach(0..<max(window.fastCandleMax, 1), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < window.fastCandleCount ? stateColor : colors.border.opacity(0.4))
                        .frame(height: 6)
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text(value).font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
        }
    }

    private var stateColor: Color {
        switch window.status {
        case "active": return PulseColors.accent
        case "violation": return PulseColors.StateColors.orange
        case "reclaim": return PulseColors.StateColors.yellow
        case "expired", "closed": return colors.textMuted
        default: return colors.textMuted
        }
    }
}

// MARK: - Charges Panel

private struct ChargesPanel: View {
    let matrix: StructureMatrixBFFResponse?
    @Environment(PulseColors.self) private var colors

    private var charges: [Charge] {
        var out: [Charge] = []
        for row in matrix?.rows ?? [] {
            for (_, cell) in row.cells {
                for code in cell.reasonCodes {
                    out.append(Charge(tf: row.timeframe, zoneType: cell.zoneType, reasonCode: code, action: cell.action))
                }
            }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.xs) {
                Text("§").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(PulseColors.accent)
                Text(L10n.Structure.chargesAndReasons)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }

            if charges.isEmpty {
                Text(L10n.Structure.noChargesFiled)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .padding(PulseSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.cardBackground.opacity(0.4)))
            } else {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    ForEach(Array(charges.enumerated()), id: \.offset) { idx, c in
                        ChargeRow(index: idx + 1, charge: c)
                    }
                }
            }
        }
    }
}

private struct Charge {
    let tf: String
    let zoneType: String
    let reasonCode: String
    let action: String
}

private struct ChargeRow: View {
    let index: Int
    let charge: Charge
    @Environment(PulseColors.self) private var colors

    private static let numerals = ["i.", "ii.", "iii.", "iv.", "v.", "vi.", "vii.", "viii.", "ix.", "x."]

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            Text(numeral)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(PulseColors.accent.opacity(0.7))
                .frame(width: 24, alignment: .leading)

            Text(charge.tf)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 36, alignment: .leading)

            Text("\"" + humanize(charge.reasonCode) + "\"")
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(charge.reasonCode)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(colors.border.opacity(0.3)))
        }
        .padding(PulseSpacing.sm)
        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.cardBackground.opacity(0.5)))
    }

    private var numeral: String {
        guard index - 1 < Self.numerals.count else { return "\(index)." }
        return Self.numerals[index - 1]
    }
}

// MARK: - Hearings Timeline

private struct HearingsTimeline: View {
    let events: [MTFGuardEventResponse]
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.xs) {
                Text("§").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(PulseColors.accent)
                Text(L10n.Structure.hearingsAndRulings)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }

            if events.isEmpty {
                Text(L10n.Structure.noPastHearings)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .padding(PulseSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.cardBackground.opacity(0.4)))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, e in
                        HearingRow(event: e, isLast: idx == events.count - 1)
                    }
                }
                .padding(PulseSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(colors.cardBackground.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
                )
            }
        }
    }
}

private struct HearingRow: View {
    let event: MTFGuardEventResponse
    let isLast: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            VStack(spacing: 0) {
                Circle().fill(actionColor).frame(width: 7, height: 7)
                if !isLast {
                    Rectangle().fill(colors.border).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: PulseSpacing.sm) {
                    Text(formattedTime)
                        .font(PulseFonts.tabular)
                        .foregroundStyle(colors.textSecondary)
                    Text("\(event.guardState) on \(event.slowTimeframe)")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Text("→ " + event.action.uppercased())
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(actionColor)
                }
                if let reason = event.reasonCodes.first {
                    Text(humanize(reason))
                        .font(.system(size: 12, weight: .regular, design: .serif).italic())
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(.bottom, PulseSpacing.sm)
        }
    }

    private var formattedTime: String {
        let iso = ISO8601DateFormatter()
        guard let d = iso.date(from: event.createdAt) else { return event.createdAt }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private var actionColor: Color {
        switch event.action {
        case "allow": return PulseColors.accent
        case "observe", "require_confirmation", "require_confirm": return PulseColors.StateColors.yellow
        case "reduce_size": return PulseColors.StateColors.orange
        case "block_entry": return PulseColors.StateColors.red
        default: return colors.textMuted
        }
    }
}

// MARK: - Detail Drawer

private struct StructureDetailDrawer: View {
    let payload: DetailCellPayload
    let onClose: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 0) {
            Color.black.opacity(0.35)
                .onTapGesture { onClose() }
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Structure.cellDetail)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                        Text("\(payload.cell.zoneType.uppercased()) · \(payload.timeframe)")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(colors.textPrimary)
                    }
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                            .padding(7)
                            .background(Circle().fill(colors.cardBackground))
                            .foregroundStyle(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().overlay(colors.border)

                row(L10n.Structure.detailStatus, payload.cell.status)
                row(L10n.Structure.detailStrength, String(format: "%.0f%%", payload.cell.currentStrength * 100))
                row(L10n.Structure.detailFilledRatio, String(format: "%.0f%%", payload.cell.filledRatio * 100))
                row(L10n.Structure.detailAction, payload.cell.action.uppercased())
                row(L10n.Structure.detailShadow, payload.isShadow ? L10n.Structure.yesLabel : L10n.Structure.noLabel)

                if !payload.cell.reasonCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Structure.reasonCodes)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                        ForEach(payload.cell.reasonCodes, id: \.self) { code in
                            HStack(spacing: 4) {
                                Text(code)
                                    .font(PulseFonts.micro)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(colors.border.opacity(0.3)))
                                    .foregroundStyle(colors.textSecondary)
                                Text(humanize(code))
                                    .font(.system(size: 12, design: .serif).italic())
                                    .foregroundStyle(colors.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(PulseSpacing.lg)
            .frame(width: 380)
            .frame(maxHeight: .infinity)
            .background(colors.background)
            .overlay(Rectangle().fill(colors.border).frame(width: 1), alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            Spacer()
            Text(value).font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Symbol Picker Overlay

private struct SymbolPickerOverlay: View {
    @Binding var isOpen: Bool
    let selected: String
    let recents: [String]
    let all: [String]
    let onSelect: (String) -> Void

    @State private var query: String = ""
    @Environment(PulseColors.self) private var colors

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isOpen = false }

            VStack(spacing: 0) {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                    TextField(L10n.Structure.searchSymbols, text: $query)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.tabular)
                    Text("ESC")
                        .font(PulseFonts.micro)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(colors.border.opacity(0.4)))
                        .foregroundStyle(colors.textMuted)
                }
                .padding(PulseSpacing.md)
                .background(colors.cardBackground)

                Divider().overlay(colors.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !recents.isEmpty && query.isEmpty {
                            sectionHeader(L10n.Structure.sectionRecent)
                            ForEach(recents, id: \.self) { s in
                                pickerRow(s)
                            }
                        }
                        sectionHeader(L10n.Structure.sectionAllSymbols)
                        ForEach(filtered, id: \.self) { s in
                            pickerRow(s)
                        }
                    }
                    .padding(.vertical, PulseSpacing.xs)
                }
                .frame(maxHeight: 360)
                .background(colors.background)
            }
            .frame(width: 420)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.background)
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .padding(.top, 80)
            .background(
                Button("") { isOpen = false }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
            )
        }
    }

    private var filtered: [String] {
        if query.isEmpty { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(colors.textMuted)
            .padding(.horizontal, PulseSpacing.md).padding(.top, PulseSpacing.sm).padding(.bottom, 4)
    }

    @ViewBuilder
    private func pickerRow(_ symbol: String) -> some View {
        Button { onSelect(symbol) } label: {
            HStack {
                Text(symbol)
                    .font(PulseFonts.tabular)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if symbol == selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                }
            }
            .padding(.horizontal, PulseSpacing.md).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func humanize(_ code: String) -> String {
    code
        .replacingOccurrences(of: "_", with: " ")
        .lowercased()
}

extension Notification.Name {
    static let applyVerdictToOrderForm = Notification.Name("structureMatrix.applyVerdictToOrderForm")
}
