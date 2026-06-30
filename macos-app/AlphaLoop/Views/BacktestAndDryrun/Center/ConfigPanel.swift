// ConfigPanel.swift — Inline run configuration (replaces NewRunSheet).

import SwiftUI

struct ConfigPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    @State private var symbols: Set<String> = []
    @State private var timeframe: String = "5m"
    @State private var initialCapital: Double = 10000
    @State private var fee: Double = 0.001
    @State private var slippageBps: Double = 5
    @State private var startDate: Date = .now.addingTimeInterval(-86400 * 30)
    @State private var endDate: Date = .now
    @State private var stakeAmount: Double = 100
    @State private var maxOpenTrades: Int = 5
    @State private var initialWallet: Double = 10000

    private var isReadonly: Bool { vm.phase == .running }

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionConfig, locked: isReadonly) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                strategyPicker
                symbolChips
                timeframePicker
                if vm.activeTab == .backtest { dateRangePicker }
                if vm.activeTab == .dryrun { dryrunFields }
                capitalFeeSlippage
                runButton
            }
        }
    }

    private var strategyPicker: some View {
        HStack {
            Text(L10n.BacktestLab.fieldVersion).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            Picker("", selection: Binding(get: { vm.selectedStrategy }, set: { new in
                if let new { Task { await vm.selectStrategy(new) } }
            })) {
                ForEach(vm.availableStrategies) { s in
                    Text(s.name).tag(s as StrategyV2?)
                }
            }
            .disabled(isReadonly)
        }
    }

    private var symbolChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.BacktestLab.fieldSymbols).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(vm.tradableSymbols, id: \.self) { sym in
                    let selected = symbols.contains(sym)
                    Button {
                        if !isReadonly {
                            if selected { symbols.remove(sym) } else { symbols.insert(sym) }
                        }
                    } label: {
                        Text(sym)
                            .font(PulseFonts.micro)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(selected ? PulseColors.accent.opacity(0.3) : colors.surface.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var timeframePicker: some View {
        HStack {
            Text(L10n.BacktestLab.fieldTimeframe).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            Picker("", selection: $timeframe) {
                ForEach(["5m", "15m", "1h", "4h"], id: \.self) { Text($0).tag($0) }
            }.disabled(isReadonly)
        }
    }

    private var dateRangePicker: some View {
        HStack {
            DatePicker(L10n.BacktestLab.fieldStart, selection: $startDate, displayedComponents: .date).disabled(isReadonly)
            DatePicker(L10n.BacktestLab.fieldEnd, selection: $endDate, displayedComponents: .date).disabled(isReadonly)
        }
    }

    private var dryrunFields: some View {
        Group {
            labeledTextField(L10n.BacktestLab.fieldCapital, value: $stakeAmount)
            labeledIntField(L10n.BacktestLab.sheetMaxOpen, value: $maxOpenTrades)
            labeledTextField(L10n.BacktestLab.sheetWallet, value: $initialWallet)
        }
    }

    private var capitalFeeSlippage: some View {
        VStack(spacing: PulseSpacing.xs) {
            labeledTextField(L10n.BacktestLab.fieldCapital, value: $initialCapital)
            HStack {
                Text(L10n.BacktestLab.fieldFee).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                Spacer()
                Picker("", selection: $fee) {
                    Text("0.05%").tag(0.0005)
                    Text("0.1%").tag(0.001)
                    Text("0.2%").tag(0.002)
                }.disabled(isReadonly)
            }
            HStack {
                Text(L10n.BacktestLab.fieldSlippage).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
                Spacer()
                Picker("", selection: $slippageBps) {
                    Text(L10n.BacktestLab.fieldSlippageNone).tag(0.0)
                    Text("5 bps").tag(5.0)
                    Text("10 bps").tag(10.0)
                }.disabled(isReadonly)
            }
        }
    }

    private var runButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if vm.phase == .running { ProgressView().controlSize(.small) }
                Text(vm.phase == .running ? L10n.BacktestLab.phaseRunning : L10n.BacktestLab.sheetSubmit)
            }
            .font(PulseFonts.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(PulseColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .buttonStyle(.plain)
        .disabled(isReadonly || vm.selectedStrategy == nil || symbols.isEmpty)
    }

    // MARK: - Helpers

    private func labeledTextField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: 100)
                .textFieldStyle(.roundedBorder)
                .disabled(isReadonly)
        }
    }

    private func labeledIntField(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label).font(PulseFonts.caption).foregroundStyle(colors.textSecondary)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                .disabled(isReadonly)
        }
    }

    private func submit() async {
        guard let strategy = vm.selectedStrategy else { return }
        let syms = Array(symbols)

        if vm.activeTab == .backtest {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            let timerange = "\(fmt.string(from: startDate))-\(fmt.string(from: endDate))"
            do {
                try await vm.startBacktest(
                    timerange: timerange,
                    symbols: syms,
                    capital: initialCapital,
                    slippageBps: slippageBps
                )
            } catch {
                // VM sets phase = .failed with errorMessage
            }
        } else {
            do {
                try await vm.startDryrun(
                    symbols: syms,
                    stakeAmount: stakeAmount,
                    maxOpenTrades: maxOpenTrades,
                    capital: initialCapital
                )
            } catch {
                // VM sets phase = .failed with errorMessage
            }
        }
    }
}
