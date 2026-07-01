// NewRunDrawer.swift — 配置抽屉：策略/版本/日期范围/资金参数

import SwiftUI

struct NewRunDrawer: View {
    @Binding var isPresented: Bool
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    @State private var selectedStrategyId: String?
    @State private var selectedVersionId: String?
    @State private var symbol = "BTC/USDT"
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var capital = 10000.0
    @State private var stakeAmount = 100.0
    @State private var maxOpenTrades = 5
    @State private var slippageBps = 0.0
    @State private var isRunning = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            header

            strategyPicker
            versionPicker
            symbolField

            if vm.activeTab == .backtest {
                dateRangePicker
                capitalField
                slippageField
            } else {
                stakeField
                maxOpenTradesField
                capitalField
            }

            Spacer()

            if let err = errorMsg {
                Text(err).font(PulseFonts.caption).foregroundStyle(PulseColors.danger)
            }

            runButton
        }
        .padding(PulseSpacing.lg)
        .onAppear {
            selectedStrategyId = vm.selectedStrategy?.id ?? vm.availableStrategies.first?.id
            selectedVersionId = vm.selectedVersion?.id
        }
    }

    private var header: some View {
        HStack {
            Text(vm.activeTab == .backtest ? L10n.BacktestLab.newRunDrawerTitle : L10n.BacktestLab.runDryrun)
                .font(PulseFonts.headline)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                    .padding(7)
                    .background(colors.surfaceHover.opacity(0.5))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(colors.border, lineWidth: 1))
                    .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldStrategy).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            Picker(L10n.BacktestLab.fieldStrategy, selection: $selectedStrategyId) {
                Text(L10n.BacktestLab.selectStrategyPrompt).tag(nil as String?)
                ForEach(vm.availableStrategies) { s in
                    Text(s.name).tag(s.id as String?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedStrategyId) { _, newId in
                guard let newId, let s = vm.availableStrategies.first(where: { $0.id == newId }) else { return }
                Task { await vm.selectStrategy(s) }
            }
        }
    }

    private var versionPicker: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldVersion).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            Picker(L10n.BacktestLab.fieldVersion, selection: $selectedVersionId) {
                Text(L10n.BacktestLab.selectVersionPrompt).tag(nil as String?)
                ForEach(vm.availableVersions) { v in
                    Text("v\(v.versionNo) · \(v.status)").tag(v.id as String?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedVersionId) { _, newId in
                guard let newId, let v = vm.availableVersions.first(where: { $0.id == newId }) else { return }
                vm.selectVersion(v)
            }
        }
    }

    private var symbolField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldSymbol).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            TextField("BTC/USDT", text: $symbol)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
        }
    }

    private var dateRangePicker: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldDateRange).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            HStack(spacing: PulseSpacing.sm) {
                DatePicker(L10n.BacktestLab.fieldStartDate, selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                Text("→").foregroundStyle(colors.textMuted)
                DatePicker(L10n.BacktestLab.fieldEndDate, selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .font(PulseFonts.tabular)
        }
    }

    private var capitalField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldInitialCapital).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            TextField("10000", value: $capital, format: .number)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
        }
    }

    private var slippageField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldSlippageBps).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            TextField("0", value: $slippageBps, format: .number)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
        }
    }

    private var stakeField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldStakeAmount).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            TextField("100", value: $stakeAmount, format: .number)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
        }
    }

    private var maxOpenTradesField: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.BacktestLab.fieldMaxOpenTrades).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            TextField("5", value: $maxOpenTrades, format: .number)
                .textFieldStyle(.plain)
                .font(PulseFonts.tabular)
                .padding(PulseSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PulseRadii.button).fill(colors.surfaceHover.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
        }
    }

    private var runButton: some View {
        Button {
            Task { await runAction() }
        } label: {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: vm.activeTab == .backtest ? "play.fill" : "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(vm.activeTab == .backtest ? L10n.BacktestLab.runBacktest : L10n.BacktestLab.runDryrun)
                    .font(PulseFonts.captionMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(canRun ? PulseColors.accent : colors.surfaceHover.opacity(0.4))
            .foregroundStyle(canRun ? .white : colors.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
        }
        .buttonStyle(.plain)
        .disabled(!canRun || isRunning)
    }

    private var canRun: Bool {
        vm.selectedStrategy != nil && vm.selectedVersion != nil && !symbol.isEmpty
    }

    private func runAction() async {
        isRunning = true
        errorMsg = nil
        defer { isRunning = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let timerange = "\(formatter.string(from: startDate))-\(formatter.string(from: endDate))"

        do {
            switch vm.activeTab {
            case .backtest:
                try await vm.startBacktest(
                    timerange: timerange,
                    symbols: [symbol],
                    capital: capital,
                    slippageBps: slippageBps > 0 ? slippageBps : nil
                )
            case .dryrun:
                try await vm.startDryrun(
                    symbols: [symbol],
                    stakeAmount: stakeAmount,
                    maxOpenTrades: maxOpenTrades,
                    capital: capital
                )
            }
            isPresented = false
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
