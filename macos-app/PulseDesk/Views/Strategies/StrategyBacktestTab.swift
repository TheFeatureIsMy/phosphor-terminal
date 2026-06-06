// StrategyBacktestTab.swift — v2.5 回测（Command Bus 轮询模式）

import SwiftUI

struct StrategyBacktestTab: View {
    @Environment(PulseColors.self) private var colors
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
    }

    // MARK: - Config

    private var configSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "回测配置")

            HStack(spacing: PulseSpacing.md) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("时间范围").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    TextField("YYYYMMDD-YYYYMMDD", text: $viewModel.backtestTimerange)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)
                        .padding(PulseSpacing.xs)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
                        .frame(width: 200)
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("初始资金").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    TextField("10000", value: $viewModel.backtestCapital, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)
                        .padding(PulseSpacing.xs)
                        .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("交易对").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
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
            let title = viewModel.isStartingBacktest ? "提交中..." :
                        viewModel.isPollingBacktest ? "回测运行中..." : "启动回测"
            ProofAlphaButton(title: title) {
                Task { await viewModel.startBacktest() }
            }
            .disabled(!viewModel.canStartBacktest || viewModel.isStartingBacktest)

            if viewModel.isPollingBacktest {
                Button("取消") { viewModel.stopPolling() }
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.danger)
                    .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.latestVersion == nil {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("请先在 DSL 规则中保存一个版本")
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
                Text("回测运行中...")
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
