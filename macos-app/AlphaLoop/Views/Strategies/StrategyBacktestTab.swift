// StrategyBacktestTab.swift — v2.5 回测（Command Bus 轮询模式）

import SwiftUI

struct StrategyBacktestTab: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Bindable var viewModel: StrategyDetailViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                configSection
                actionBar

                if viewModel.isPollingBacktest {
                    pollingIndicator
                }

                if let error = viewModel.backtestError {
                    errorBanner(error)
                }

                if let run = viewModel.backtestRun {
                    BacktestResultCardView(run: run)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .id(settingsState.language)
    }

    // MARK: - Config

    private var configSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("回测配置", en: "Backtest Configuration"))

            HStack(spacing: PulseSpacing.md) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("时间范围", en: "Date Range")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    TextField("YYYYMMDD-YYYYMMDD", text: $viewModel.backtestTimerange)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.label)
                        .foregroundStyle(colors.textPrimary)
                        .padding(PulseSpacing.xs)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
                        .frame(width: 200)
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("初始资金", en: "Initial Capital")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    TextField("10000", value: $viewModel.backtestCapital, format: .number)
                        .textFieldStyle(.plain)
                        .font(PulseFonts.label)
                        .foregroundStyle(colors.textPrimary)
                        .padding(PulseSpacing.xs)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("交易对", en: "Trading Pair")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    Text(viewModel.backtestSymbols.joined(separator: ", "))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: PulseSpacing.sm) {
            let title = viewModel.isStartingBacktest ? L10n.zh("提交中...", en: "Submitting...") :
                        viewModel.isPollingBacktest ? L10n.zh("回测运行中...", en: "Backtest running...") : L10n.zh("启动回测", en: "Run Backtest")
            KryptonButton(title: title) {
                Task { await viewModel.startBacktest() }
            }
            .disabled(!viewModel.canStartBacktest || viewModel.isStartingBacktest)

            if viewModel.isPollingBacktest {
                Button(L10n.zh("取消", en: "Cancel")) { viewModel.stopPolling() }
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.danger)
                    .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.latestVersion == nil {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "info.circle")
                        .font(PulseFonts.monoLabel)
                    Text(L10n.zh("请先在 DSL 规则中保存一个版本", en: "Save a version in DSL Rules first"))
                        .font(PulseFonts.micro)
                }
                .foregroundStyle(PulseColors.warning)
            }
        }
    }

    // MARK: - Polling indicator

    private var pollingIndicator: some View {
        HStack(spacing: PulseSpacing.xs) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.zh("回测运行中...", en: "Backtest running..."))
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                if let status = viewModel.backtestStatus {
                    Text("Command: \(status.commandStatus)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(PulseColors.info.opacity(0.06))
        )
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(PulseColors.danger)
            Text(message)
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.danger)
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseColors.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }
}

// MARK: - Backtest init convenience (legacy compatibility)

extension StrategyBacktestTab {
    init(strategy: Strategy, client: NetworkClientProtocol) {
        let vm = StrategyDetailViewModel(strategyId: "\(strategy.id)", client: client)
        self.init(viewModel: vm)
    }
}
