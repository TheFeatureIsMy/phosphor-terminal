// BacktestLabView.swift — 回测实验室（3 列：Run Rail | Comparison | Inspector）

import SwiftUI

struct BacktestLabView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    @Environment(SettingsState.self) private var settingsState
    @Environment(\.networkClient) private var networkClient

    @State private var viewModel: BacktestLabViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(type: .detail)
            }
        }
        .id(settingsState.language)
        .task {
            if viewModel == nil {
                let vm = BacktestLabViewModel(client: networkClient)
                // 与工作台共享当前策略
                if let id = appState.selectedStrategyV2Id { vm.selectedStrategyId = id }
                viewModel = vm
                await vm.bootstrap()
            }
        }
    }

    private func content(vm: BacktestLabViewModel) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                LabHeader(vm: vm)
                Divider().overlay(colors.border)
                HStack(spacing: 0) {
                    RunRail(vm: vm)
                        .frame(width: 240)
                    Divider().overlay(colors.border)
                    ComparisonWorkbench(vm: vm)
                        .frame(maxWidth: .infinity)
                    Divider().overlay(colors.border)
                    RunInspector(vm: vm)
                        .frame(width: 320)
                }
            }
        }
        .sheet(isPresented: Binding(get: { vm.showNewRunSheet }, set: { vm.showNewRunSheet = $0 })) {
            NewRunSheet(viewModel: vm)
        }
    }
}

// MARK: - Header

private struct LabHeader: View {
    @Environment(PulseColors.self) private var colors
    let vm: BacktestLabViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.BacktestLab.title)
                        .font(PulseFonts.displaySubheading)
                        .foregroundStyle(colors.textPrimary)
                }
                Text(L10n.BacktestLab.subtitle)
                    .font(PulseFonts.micro)
                    .tracking(0.8)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer(minLength: 12)

            strategyPicker
            newRunButton
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(colors.background)
    }

    private var strategyPicker: some View {
        Menu {
            ForEach(vm.strategies) { s in
                Button(s.name) {
                    Task { await vm.selectStrategy(s.id) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu").font(.system(size: 10, weight: .medium))
                Text(vm.selectedStrategy?.name ?? L10n.BacktestLab.strategyPicker)
                    .font(PulseFonts.monoLabel)
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(colors.surface)
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var newRunButton: some View {
        Button {
            vm.showNewRunSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill").font(.system(size: 11))
                Text(L10n.BacktestLab.newRun)
                    .font(PulseFonts.monoLabel)
                    .tracking(0.6)
            }
            .foregroundStyle(colors.background)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .disabled(vm.selectedStrategyId == nil)
        .opacity(vm.selectedStrategyId == nil ? 0.4 : 1)
    }
}

// MARK: - Run Rail

private struct RunRail: View {
    @Environment(PulseColors.self) private var colors
    let vm: BacktestLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.BacktestLab.runRail)
                    .font(PulseFonts.micro).tracking(0.8)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text(L10n.BacktestLab.compareHint)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)

            Divider().overlay(colors.border)

            ScrollView {
                if vm.runs.isEmpty && vm.dryruns.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.runs) { run in
                            RunRow(
                                run: run,
                                isCompared: vm.comparedRunIds.contains(run.id),
                                isInspected: vm.inspectedRunId == run.id,
                                isChampion: vm.championRun?.id == run.id,
                                onToggleCompare: { vm.toggleCompare(run.id) },
                                onInspect: { vm.inspect(run.id) }
                            )
                        }
                        if !vm.dryruns.isEmpty {
                            Divider().overlay(colors.border).padding(.vertical, 6)
                            HStack {
                                Text(L10n.BacktestLab.dryrunSection)
                                    .font(PulseFonts.micro).tracking(0.8)
                                    .foregroundStyle(colors.textMuted)
                                Spacer()
                                Text("\(vm.dryruns.count)")
                                    .font(PulseFonts.micro.monospaced())
                                    .foregroundStyle(colors.textMuted)
                            }
                            .padding(.horizontal, 4)
                            ForEach(vm.dryruns) { dr in
                                DryrunRow(run: dr)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray").font(.system(size: 18))
                .foregroundStyle(colors.textMuted)
            Text(L10n.BacktestLab.runEmpty)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
            Text(L10n.BacktestLab.runEmptyHint)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
    }
}

private struct RunRow: View {
    @Environment(PulseColors.self) private var colors
    let run: BacktestRunV2
    let isCompared: Bool
    let isInspected: Bool
    let isChampion: Bool
    var onToggleCompare: () -> Void
    var onInspect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleCompare) {
                Image(systemName: isCompared ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(isCompared ? PulseColors.accent : colors.textMuted)
            }
            .buttonStyle(.plain)

            Button(action: onInspect) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle().fill(statusColor).frame(width: 5, height: 5)
                        Text("Run #\(run.id)")
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textPrimary)
                        if isChampion {
                            Text(L10n.BacktestLab.championBadge)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(PulseColors.accent)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(PulseColors.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    HStack(spacing: 4) {
                        Text(String(format: "%+.1f%%", run.totalReturn))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
                        Text("·").foregroundStyle(colors.textMuted)
                        Text("SR \(String(format: "%.2f", run.sharpeRatio))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(colors.textSecondary)
                    }
                    Text(run.symbols.joined(separator: ", "))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(isInspected ? PulseColors.accent : colors.border.opacity(0.4),
                        lineWidth: isInspected ? 1 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private var rowBackground: Color {
        if isInspected { return PulseColors.accent.opacity(0.06) }
        return colors.surface
    }

    private var statusColor: Color {
        switch run.status {
        case "completed": return PulseColors.success
        case "running", "pending": return PulseColors.warning
        case "failed": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}

// MARK: - Dry-run row

private struct DryrunRow: View {
    @Environment(PulseColors.self) private var colors
    let run: StrategyRunV2

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(run.mode.uppercased())
                        .font(PulseFonts.micro).tracking(0.6)
                        .foregroundStyle(PulseColors.amber)
                    Text(String(run.id.prefix(8)))
                        .font(PulseFonts.captionMedium.monospaced())
                        .foregroundStyle(colors.textPrimary)
                    Spacer(minLength: 0)
                    Text(run.status)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(colors.textSecondary)
                }
                if let started = run.startedAt ?? Optional(run.createdAt) {
                    Text(started)
                        .font(PulseFonts.micro.monospaced())
                        .foregroundStyle(colors.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border.opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private var statusDot: some View {
        let color: Color = {
            switch run.status {
            case "running", "active": return PulseColors.success
            case "stopped":           return colors.textMuted
            case "error":             return PulseColors.danger
            default:                  return PulseColors.amber
            }
        }()
        return Circle().fill(color).frame(width: 6, height: 6)
    }
}

// MARK: - Comparison Workbench

private struct ComparisonWorkbench: View {
    @Environment(PulseColors.self) private var colors
    let vm: BacktestLabViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if vm.comparedRuns.isEmpty {
                    emptyState
                } else {
                    kpiMatrix
                    equityOverlay
                    championCard
                }
            }
            .padding(18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 22))
                .foregroundStyle(colors.textMuted)
            Text(L10n.BacktestLab.pickRunHint)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    // KPI matrix: rows = runs, cols = 6 metrics
    private var kpiMatrix: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(L10n.BacktestLab.compareMatrix, icon: "tablecells")
            VStack(spacing: 0) {
                headerRow
                Divider().overlay(colors.border)
                ForEach(vm.comparedRuns) { run in
                    matrixRow(run)
                    Divider().overlay(colors.border.opacity(0.4))
                }
            }
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 0.5))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("RUN", width: 80, align: .leading)
            cell(L10n.BacktestLab.kpiReturn, width: nil)
            cell(L10n.BacktestLab.kpiSharpe, width: nil)
            cell(L10n.BacktestLab.kpiMaxDD, width: nil)
            cell(L10n.BacktestLab.kpiWinRate, width: nil)
            cell(L10n.BacktestLab.kpiProfitFactor, width: nil)
            cell(L10n.BacktestLab.kpiTrades, width: nil)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(colors.surfaceElevated)
    }

    private func cell(_ text: String, width: CGFloat? = nil, align: HorizontalAlignment = .trailing) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(colors.textMuted)
            .frame(maxWidth: width ?? .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    private func matrixRow(_ run: BacktestRunV2) -> some View {
        let isChamp = vm.championRun?.id == run.id
        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(isChamp ? PulseColors.accent : colors.textMuted).frame(width: 5, height: 5)
                Text("#\(run.id)").font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
            }
            .frame(width: 80, alignment: .leading)
            metricCell(String(format: "%+.2f%%", run.totalReturn), color: run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            metricCell(String(format: "%.2f", run.sharpeRatio), color: run.sharpeRatio >= 1.5 ? PulseColors.success : colors.textPrimary)
            metricCell(String(format: "%.1f%%", run.maxDrawdown), color: PulseColors.danger)
            metricCell(String(format: "%.1f%%", run.winRate), color: run.winRate >= 50 ? PulseColors.success : colors.textPrimary)
            metricCell(String(format: "%.2f", run.profitFactor), color: run.profitFactor >= 1.5 ? PulseColors.success : colors.textPrimary)
            metricCell("\(run.totalTrades)", color: PulseColors.info)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isChamp ? PulseColors.accent.opacity(0.06) : Color.clear)
    }

    private func metricCell(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.tabular)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // Equity overlay: simple Path lines (no Charts dependency)
    private var equityOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(L10n.BacktestLab.equityOverlay, icon: "chart.xyaxis.line")
            VStack(spacing: 10) {
                EquityOverlayChart(runs: vm.comparedRuns)
                    .frame(height: 140)
                HStack(spacing: 12) {
                    ForEach(Array(vm.comparedRuns.enumerated()), id: \.element.id) { idx, run in
                        legendItem(run: run, color: lineColor(idx))
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 0.5))
        }
    }

    private func legendItem(run: BacktestRunV2, color: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 12, height: 2)
            Text("#\(run.id)")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func lineColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return PulseColors.accent
        case 1: return PulseColors.info
        default: return PulseColors.warning
        }
    }

    // Champion recommendation
    @ViewBuilder
    private var championCard: some View {
        if let champ = vm.championRun {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L10n.BacktestLab.champion, icon: "trophy")
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Run #\(champ.id)")
                                .font(PulseFonts.tabularLarge)
                                .foregroundStyle(PulseColors.accent)
                            Text(L10n.BacktestLab.championBadge)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(PulseColors.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(PulseColors.accent.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Text(L10n.BacktestLab.championReason)
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                    Spacer()
                    Button {
                        vm.inspect(champ.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 11))
                            Text(L10n.BacktestLab.promoteToPaper)
                                .font(PulseFonts.monoLabel)
                                .tracking(0.6)
                        }
                        .foregroundStyle(colors.background)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(PulseColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(LinearGradient(
                    colors: [PulseColors.accent.opacity(0.10), colors.surface],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(PulseColors.accent.opacity(0.4), lineWidth: 0.8))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
            }
        }
    }

    private func sectionHeader(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseColors.accent)
            Text(text)
                .font(PulseFonts.monoLabel).tracking(0.8).textCase(.uppercase)
                .foregroundStyle(colors.textSecondary)
        }
    }
}

// MARK: - Equity Overlay Chart (hand-drawn paths)

private struct EquityOverlayChart: View {
    @Environment(PulseColors.self) private var colors
    let runs: [BacktestRunV2]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // grid lines
                Path { p in
                    for i in 0...3 {
                        let y = geo.size.height * CGFloat(i) / 3
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(colors.border.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

                // overlay lines per run
                ForEach(Array(runs.enumerated()), id: \.element.id) { idx, run in
                    let pts = synthesizePoints(run: run)
                    Path { p in
                        guard let first = pts.first else { return }
                        p.move(to: scale(first, in: geo.size, range: globalRange))
                        for pt in pts.dropFirst() {
                            p.addLine(to: scale(pt, in: geo.size, range: globalRange))
                        }
                    }
                    .stroke(lineColor(idx), lineWidth: 1.5)
                }
            }
        }
    }

    private var globalRange: (lo: Double, hi: Double) {
        var lo = 0.0, hi = 0.0
        for r in runs {
            let pts = synthesizePoints(run: r)
            for p in pts {
                if p.y < lo { lo = p.y }
                if p.y > hi { hi = p.y }
            }
        }
        if hi == lo { hi = lo + 1 }
        return (lo, hi)
    }

    /// 简化：从 totalReturn 合成 30 个点的随机权益曲线（后端未返 equity_curve 时的兜底）
    /// 同 commandId 同 seed → 同一曲线（基于 id 哈希）
    private func synthesizePoints(run: BacktestRunV2) -> [CGPoint] {
        var rng = SeededRandom(seed: UInt64(abs(run.id.hashValue)) &+ 1)
        var pts: [CGPoint] = []
        var equity = 0.0
        let steps = 30
        let drift = run.totalReturn / Double(steps)
        for i in 0...steps {
            let noise = rng.nextDouble(in: -1.5...1.5)
            equity += drift + noise
            pts.append(CGPoint(x: Double(i), y: equity))
        }
        // 终点对齐到 totalReturn
        if let last = pts.last {
            let delta = run.totalReturn - last.y
            for i in 0..<pts.count {
                pts[i].y += delta * (Double(i) / Double(steps))
            }
        }
        return pts
    }

    private func scale(_ pt: CGPoint, in size: CGSize, range: (lo: Double, hi: Double)) -> CGPoint {
        let x = (pt.x / 30) * size.width
        let normY = (pt.y - range.lo) / (range.hi - range.lo)
        let y = size.height - normY * size.height
        return CGPoint(x: x, y: y)
    }

    private func lineColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return PulseColors.accent
        case 1: return PulseColors.info
        default: return PulseColors.warning
        }
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Inspector

private struct RunInspector: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let vm: BacktestLabViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.BacktestLab.inspector)
                        .font(PulseFonts.micro).tracking(0.8)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                if let run = vm.inspectedRun {
                    detailHeader(run)
                    configCard(run)
                    promotionGate(run)
                } else {
                    Text(L10n.BacktestLab.inspectorEmpty)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(.top, 30)
                }
            }
            .padding(14)
        }
    }

    private func detailHeader(_ run: BacktestRunV2) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Run #\(run.id)")
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Text(run.status.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(statusColor(run.status))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(statusColor(run.status).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Text(run.symbols.joined(separator: ", "))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
            HStack(spacing: 4) {
                Text(L10n.BacktestLab.kpiReturn).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text(String(format: "%+.2f%%", run.totalReturn))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(run.totalReturn >= 0 ? PulseColors.success : PulseColors.danger)
            }
        }
    }

    private func configCard(_ run: BacktestRunV2) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(L10n.BacktestLab.configSnapshot)
            kvRow(L10n.BacktestLab.fieldStart, run.startDate)
            kvRow(L10n.BacktestLab.fieldEnd, run.endDate)
            kvRow(L10n.BacktestLab.fieldCapital, String(format: "%.0f USDT", run.initialCapital))
            if let hash = run.dslHash, !hash.isEmpty {
                kvRow("DSL Hash", String(hash.prefix(10)))
            }
        }
        .padding(10)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 0.5))
    }

    private func promotionGate(_ run: BacktestRunV2) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(L10n.BacktestLab.promotionGate)
            gateLink(label: L10n.BacktestLab.openMtfGuard, icon: "shield.lefthalf.filled",
                     route: .structureMatrix)
            gateLink(label: L10n.BacktestLab.openLiveReadiness, icon: "checkmark.shield",
                     route: .liveReadiness)
        }
        .padding(10)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 0.5))
    }

    private func gateLink(label: String, icon: String, route: AppRoute) -> some View {
        Button {
            appState.selectedRoute = route
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(PulseColors.accent)
                Text(label).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro).tracking(0.6).textCase(.uppercase)
            .foregroundStyle(colors.textMuted)
    }

    private func kvRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Spacer()
            Text(v).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return PulseColors.success
        case "running", "pending": return PulseColors.warning
        case "failed": return PulseColors.danger
        default: return colors.textMuted
        }
    }
}
