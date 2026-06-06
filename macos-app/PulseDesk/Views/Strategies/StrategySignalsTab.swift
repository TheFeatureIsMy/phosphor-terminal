// StrategySignalsTab.swift — 策略关联信号列表
// 显示触发本策略的信号 + 策略产生的信号

import SwiftUI

struct StrategySignalsTab: View {
    @Environment(PulseColors.self) private var colors
    let strategyId: String
    let client: NetworkClientProtocol

    @State private var sourceSignals: [SignalV2] = []
    @State private var producedSignals: [SignalV2] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if isLoading {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            } else {
                VStack(spacing: PulseSpacing.md) {
                    // Source signals (signals that led to this strategy)
                    signalSection(
                        title: "来源信号",
                        subtitle: "触发本策略的信号",
                        signals: sourceSignals,
                        emptyMessage: "暂无来源信号"
                    )

                    // Produced signals (signals produced by this strategy)
                    signalSection(
                        title: "产出信号",
                        subtitle: "本策略生成的信号",
                        signals: producedSignals,
                        emptyMessage: "暂无产出信号"
                    )
                }
                .padding(PulseSpacing.lg)
            }
        }
        .task { await loadSignals() }
    }

    @ViewBuilder
    private func signalSection(title: String, subtitle: String, signals: [SignalV2], emptyMessage: String) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        TerminalLabel(text: title)
                        Text(subtitle)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    BadgeDot(color: PulseColors.accent, label: "\(signals.count)", size: .small)
                }

                if signals.isEmpty {
                    Text(emptyMessage)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                } else {
                    ForEach(signals, id: \.id) { signal in
                        signalRow(signal)
                    }
                }
            }
        }
    }

    private func signalRow(_ signal: SignalV2) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: signal.direction == "long" ? "arrow.up" : "arrow.down")
                .font(.system(size: 10))
                .foregroundStyle(signal.direction == "long" ? PulseColors.success : PulseColors.loss)

            Text(signal.symbol)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)

            BadgeDot(color: PulseColors.info, label: signal.sourceType, size: .small)

            Spacer()

            Text(String(format: "%.0f%%", signal.confidence * 100))
                .font(PulseFonts.monoLabel)
                .foregroundStyle(PulseColors.accent)

            Text(String(signal.createdAt.prefix(10)))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func loadSignals() async {
        isLoading = true
        defer { isLoading = false }
        let api = APISignalsV2(client: client)
        sourceSignals = (try? await api.listSignals(limit: 20)) ?? []
        producedSignals = (try? await api.listSignals(limit: 10)) ?? []
    }
}
