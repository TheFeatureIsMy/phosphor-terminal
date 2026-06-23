// NewRunSheet.swift — 新建 Run sheet（回测 / 模拟运行配置）
// Real form controls: DatePicker, NumberFormatter, multi-select toggles for symbols

import SwiftUI

struct NewRunSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BacktestLabViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case backtest, dryrun
        var id: String { rawValue }
        var label: String {
            switch self {
            case .backtest: return L10n.BacktestLab.sheetTitleBacktest
            case .dryrun: return L10n.BacktestLab.sheetTitleDryrun
            }
        }
    }

    @State private var mode: Mode = .backtest
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var capital: Double = 10000
    @State private var feeModel: String = "default"  // default | custom
    @State private var customFee: Double = 0.05
    @State private var slippageModel: String = "none"  // none | bps | pct
    @State private var slippageBps: Double = 3
    @State private var slippagePct: Double = 0.03
    @State private var selectedSymbols: Set<String> = []
    @State private var stakeAmount: Double = 100
    @State private var maxOpenTrades: Int = 5
    @State private var submitting = false
    @State private var error: String?

    /// Common crypto pairs used as default symbol options.
    /// StrategyV2 does not expose symbols directly, so we provide a curated list.
    private static let defaultSymbols: [String] = [
        "BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT",
        "DOGE/USDT", "XRP/USDT", "ADA/USDT", "AVAX/USDT"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            header

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Form {
                Section(L10n.BacktestLab.fieldSymbols) {
                    ForEach(availableSymbols, id: \.self) { s in
                        Toggle(s, isOn: Binding(
                            get: { selectedSymbols.contains(s) },
                            set: { v in if v { selectedSymbols.insert(s) } else { selectedSymbols.remove(s) } }
                        ))
                    }
                }

                if mode == .backtest {
                    Section(L10n.BacktestLab.fieldDateRange) {
                        DatePicker(L10n.BacktestLab.fieldDateRange, selection: $startDate, displayedComponents: .date)
                        DatePicker("—", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section(L10n.BacktestLab.fieldCapital) {
                    TextField(L10n.BacktestLab.fieldCapital, value: $capital, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                Section(L10n.BacktestLab.fieldFee) {
                    Picker(L10n.BacktestLab.fieldFee, selection: $feeModel) {
                        Text(L10n.BacktestLab.feeExchangeDefault).tag("default")
                        Text(L10n.BacktestLab.feeCustom).tag("custom")
                    }
                    if feeModel == "custom" {
                        TextField("fee %", value: $customFee, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section(L10n.BacktestLab.fieldSlippage) {
                    Picker(L10n.BacktestLab.fieldSlippage, selection: $slippageModel) {
                        Text(L10n.BacktestLab.fieldSlippageNone).tag("none")
                        Text(L10n.BacktestLab.fieldSlippageBps).tag("bps")
                        Text(L10n.BacktestLab.fieldSlippagePct).tag("pct")
                    }
                    if slippageModel == "bps" {
                        TextField("bps", value: $slippageBps, format: .number)
                            .textFieldStyle(.roundedBorder)
                    } else if slippageModel == "pct" {
                        TextField("%", value: $slippagePct, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if mode == .dryrun {
                    Section("Stake") {
                        TextField("stake_amount", value: $stakeAmount, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField("max_open_trades", value: $maxOpenTrades, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)

            if let error {
                Text(error)
                    .foregroundStyle(PulseColors.danger)
                    .font(PulseFonts.caption)
            }

            HStack {
                Button(L10n.BacktestLab.sheetCancel) { dismiss() }
                Spacer()
                Button(L10n.BacktestLab.sheetSubmit) {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(submitting || !isValid)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 560)
    }

    private var header: some View {
        Text(mode == .backtest ? L10n.BacktestLab.sheetTitleBacktest : L10n.BacktestLab.sheetTitleDryrun)
            .font(PulseFonts.displayHeading)
    }

    /// Symbols available for selection. StrategyV2 has no symbols field,
    /// so we use a static default list of common crypto pairs.
    private var availableSymbols: [String] {
        Self.defaultSymbols
    }

    private var isValid: Bool {
        guard !selectedSymbols.isEmpty else { return false }
        if capital <= 0 { return false }
        if mode == .backtest && startDate >= endDate { return false }
        return true
    }

    private func submit() async {
        submitting = true
        error = nil
        defer { submitting = false }
        do {
            let timerange = stringTimerange()
            let slipBps: Double? = slippageModel == "bps" ? slippageBps
                                  : slippageModel == "pct" ? slippagePct * 100 : nil
            try await viewModel.startBacktest(
                timerange: timerange,
                symbols: Array(selectedSymbols),
                capital: capital,
                slippageBps: slipBps
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func stringTimerange() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return "\(fmt.string(from: startDate))-\(fmt.string(from: endDate))"
    }
}
