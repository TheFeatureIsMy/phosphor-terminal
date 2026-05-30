// AIProvidersView.swift — AI 服务管理页面

import SwiftUI

struct AIProvidersView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var api: APIAIProviders?
    @State private var providers: [AIProviderInfo] = []
    @State private var modelStatus: [String: ModelStatusInfo] = [:]
    @State private var isLoading = true
    @State private var testResult: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                HStack {
                    Text("AI 服务管理")
                        .font(PulseFonts.displayHeading)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                }

                // Providers grid
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    Text("LLM Provider")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: PulseSpacing.md) {
                        ForEach(providers) { provider in
                            ProviderCardView(provider: provider) {
                                Task { await testProvider(provider.name) }
                            }
                        }
                    }
                }
                .cardStyle()

                // Model status
                VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                    Text("ML 模型状态")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    ForEach(Array(modelStatus.keys.sorted()), id: \.self) { key in
                        if let model = modelStatus[key] {
                            HStack {
                                Text(model.name)
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textPrimary)
                                Spacer()
                                Text(model.status)
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(model.status == "loaded" ? PulseColors.success : PulseColors.warning)
                                if let fallback = model.fallback {
                                    Text("(\(fallback))")
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(colors.textMuted)
                                }
                            }
                            .padding(PulseSpacing.xs)
                            .background(colors.surface)
                            .cornerRadius(PulseRadii.xs)
                        }
                    }

                    if modelStatus.isEmpty {
                        Text("暂无模型信息")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                }
                .cardStyle()

                // Test result
                if let result = testResult {
                    Text(result)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.accent)
                        .padding(PulseSpacing.sm)
                        .background(PulseColors.accent.opacity(0.1))
                        .cornerRadius(PulseRadii.sm)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task {
            api = APIAIProviders(client: networkClient)
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        providers = (try? await api?.listProviders()) ?? []
        modelStatus = (try? await api?.getModelStatus()) ?? [:]
    }

    private func testProvider(_ name: String) async {
        testResult = nil
        do {
            let resp = try await api?.testProvider(name: name)
            testResult = resp?.success == true ? "\(name): 连接成功" : "\(name): \(resp?.message ?? "连接失败")"
        } catch {
            testResult = "\(name): 测试失败 - \(error.localizedDescription)"
        }
    }
}
