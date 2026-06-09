// SetupWizardView.swift — 首次启动引导页

import SwiftUI

struct SetupWizardView: View {
    @Environment(\.dependencyState) private var depState
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss

    @Environment(SettingsState.self) private var settingsState
    @State private var currentStep = 0

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: PulseSpacing.sm) {
                L10nText("弈机 配置向导", en: "AlphaLoop Setup Wizard")
                    .font(PulseFonts.displayTitle)
                    .foregroundStyle(colors.textPrimary)

                Text(L10n.zh("完成以下步骤以启用全部功能", en: "Complete the following steps to enable all features"))
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textMuted)

                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= currentStep ? PulseColors.accent : colors.textMuted.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .padding(.top, PulseSpacing.sm)
            }
            .padding(PulseSpacing.xl)

            // Step content
            Group {
                switch currentStep {
                case 0: step1CoreDeps
                case 1: step2AIServices
                case 2: step3TradingServices
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: currentStep)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button(L10n.zh("上一步", en: "Back")) { currentStep -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()

                if depState?.isLoading == true {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(currentStep < totalSteps - 1 ? L10n.zh("下一步", en: "Next") : L10n.zh("完成配置", en: "Finish Setup")) {
                    if currentStep < totalSteps - 1 {
                        currentStep += 1
                    } else {
                        completeSetup()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PulseColors.accent)
            }
            .padding(PulseSpacing.lg)
        }
        .frame(width: 600, height: 500)
        .background(colors.background)
    }

    // MARK: - Step 1: Core Dependencies
    private var step1CoreDeps: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text(L10n.zh("核心依赖", en: "Core Dependencies"))
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text(L10n.zh("以下 Python 包影响核心功能。缺失的包会自动降级，但建议安装以获得完整体验。", en: "The following Python packages affect core functionality. Missing packages will gracefully degrade, but installation is recommended for the full experience."))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "ccxt", group: "core_optional", desc: L10n.zh("实时市场数据", en: "Real-time market data"))
                    dependencyRow(name: "lightgbm", group: "core_optional", desc: L10n.zh("FreqAI 模型训练", en: "FreqAI model training"))
                    dependencyRow(name: "transformers", group: "core_optional", desc: L10n.zh("FinBERT 情绪分析", en: "FinBERT sentiment analysis"))
                    dependencyRow(name: "torch", group: "core_optional", desc: L10n.zh("ML 推理引擎", en: "ML inference engine"))
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Step 2: AI Services
    private var step2AIServices: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text(L10n.zh("AI 服务", en: "AI Services"))
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text(L10n.zh("配置 LLM Provider 以启用 RAG 策略生成、AI 研究等功能。Ollama 本地运行无需 Key。", en: "Configure LLM providers to enable RAG strategy generation, AI research, and more. Ollama runs locally and requires no API key."))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "ollama", group: "external_services", desc: L10n.zh("本地 LLM (默认启用)", en: "Local LLM (enabled by default)"))
                    dependencyRow(name: "openai", group: "external_services", desc: "GPT-4o")
                    dependencyRow(name: "deepseek", group: "external_services", desc: L10n.zh("国内主力", en: "DeepSeek API"))
                    dependencyRow(name: "anthropic", group: "external_services", desc: "Claude")
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Step 3: Trading Services
    private var step3TradingServices: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text(L10n.zh("交易服务", en: "Trading Services"))
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text(L10n.zh("Freqtrade 提供实盘交易数据。Telegram 用于推送通知。两者均为可选。", en: "Freqtrade provides live trading data. Telegram is used for push notifications. Both are optional."))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "freqtrade_api", group: "external_services", desc: L10n.zh("交易引擎", en: "Trading engine"))
                    dependencyRow(name: "telegram", group: "external_services", desc: L10n.zh("消息推送", en: "Push notifications"))
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Dependency Row
    private func dependencyRow(name: String, group: String, desc: String) -> some View {
        let isAvailable = depState?.isAvailable(name, in: group) ?? false
        let statusText = depState?.status(for: name, in: group) ?? "unknown"

        return HStack {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isAvailable ? PulseColors.accent : PulseColors.danger)

            VStack(alignment: .leading) {
                Text(name)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(desc)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Text(statusText)
                .font(PulseFonts.caption)
                .foregroundStyle(isAvailable ? PulseColors.accent : colors.textMuted)
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.sm)
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "setupCompleted")
        dismiss()
    }
}
