// FreqAISectionView.swift — FreqAI 机器学习
// 模型训练、部署、状态监控

import SwiftUI

struct FreqAISectionView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var selectedModel = "lightgbm"
    @State private var trainSymbol = "BTC/USDT"
    @State private var epochs = 100
    @State private var runs: [FreqAIRunEntry] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    struct FreqAIRunEntry: Identifiable {
        let id: Int
        let symbol: String
        let model: String
        let status: String
        let accuracy: Double?
        let createdAt: String
    }

    var body: some View {
        VStack(spacing: 0) {
            configBar
            Divider().foregroundStyle(colors.border)

            ScrollView {
                VStack(spacing: PulseSpacing.lg) {
                    // 错误信息
                    if let errorMessage {
                        HStack(spacing: PulseSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(PulseColors.loss)
                            Text(errorMessage)
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                        }
                        .padding(PulseSpacing.sm)
                        .background(PulseColors.loss.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                    }

                    // 训练状态卡片
                    statusCards

                    // 训练历史
                    if !runs.isEmpty {
                        Divider().foregroundStyle(colors.border)
                        runsList
                    } else {
                        EmptyStateView(
                            icon: "brain",
                            title: "FreqAI 训练",
                            description: "选择模型和标的，提交训练任务"
                        )
                        .frame(height: 200)
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
        .task { await loadRuns() }
    }

    // MARK: - Load runs from API
    private func loadRuns() async {
        do {
            let response = try await networkClient.listFreqAIRuns()
            runs = response.runs.map { run in
                FreqAIRunEntry(
                    id: run.id,
                    symbol: run.modelName,
                    model: run.modelName,
                    status: run.status,
                    accuracy: nil,
                    createdAt: run.startedAt ?? run.completedAt ?? "N/A"
                )
            }
        } catch {
            // Silently fail on initial load — runs will be empty
        }
    }

    private var configBar: some View {
        HStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: "模型")
            Picker("", selection: $selectedModel) {
                Text("LightGBM").tag("lightgbm")
                Text("XGBoost").tag("xgboost")
                Text("CatBoost").tag("catboost")
                Text("神经网络").tag("neural_net")
            }
            .pickerStyle(.menu)
            .darkPicker()
            .frame(width: 110)

            TerminalLabel(text: "标的")
            TextField("BTC/USDT", text: $trainSymbol)
                .textFieldStyle(.plain)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
                .frame(width: 120)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, PulseSpacing.xxs)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))

            TerminalLabel(text: "Epochs")
            Picker("", selection: $epochs) {
                Text("50").tag(50)
                Text("100").tag(100)
                Text("200").tag(200)
            }
            .pickerStyle(.menu)
            .darkPicker()
            .frame(width: 80)

            Spacer()

            if isSubmitting {
                ProgressView()
                    .controlSize(.small)
            }

            ProofAlphaButton(title: "提交训练") {
                Task { await submitTraining() }
            }
            .disabled(isSubmitting)
        }
        .padding(PulseSpacing.lg)
    }

    private var statusCards: some View {
        HStack(spacing: PulseSpacing.md) {
            statusCard(icon: "cpu", label: "模型", value: selectedModel.uppercased(), color: PulseColors.accent)
            statusCard(icon: "chart.line.uptrend.xyaxis", label: "标的", value: trainSymbol, color: PulseColors.cyan)
            statusCard(icon: "list.number", label: "Epochs", value: "\(epochs)", color: PulseColors.warning)
            statusCard(icon: "clock.arrow.circlepath", label: "队列", value: "\(runs.filter { $0.status == "queued" }.count)", color: PulseColors.purple)
        }
    }

    private func statusCard(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                TerminalLabel(text: label)
                Text(value)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
            }
        }
        .cardStyle()
    }

    private var runsList: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "训练历史")

            ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                HStack(spacing: PulseSpacing.md) {
                    StatusDot(status: run.status == "completed" ? .online : run.status == "running" ? .loading : .offline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.symbol)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text("\(run.model) · \(run.createdAt)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    Spacer()

                    if let acc = run.accuracy {
                        Text(String(format: "准确率 %.1f%%", acc * 100))
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.profit)
                    }

                    BadgeDot(
                        color: run.status == "completed" ? PulseColors.success :
                               run.status == "running" ? PulseColors.cyan : colors.textMuted,
                        label: run.status,
                        size: .small
                    )
                }
                .padding(.vertical, PulseSpacing.xxs)
                .background(index % 2 == 0 ? colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
            }
        }
        .cardStyle()
    }

    private func submitTraining() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await networkClient.submitFreqAITraining(
                modelName: selectedModel,
                strategyId: nil
            )
            runs.insert(FreqAIRunEntry(
                id: response.id,
                symbol: trainSymbol,
                model: response.modelName,
                status: response.status,
                accuracy: nil,
                createdAt: response.startedAt ?? "刚刚"
            ), at: 0)
        } catch {
            errorMessage = "提交训练失败: \(error.localizedDescription)"
        }
        isSubmitting = false
    }
}
