// AIProvidersView.swift — AI 服务管理
// Provider 总览 + 任务路由矩阵 + 模型运行状态 + 推理队列 + 隐私策略

import SwiftUI

struct AIProvidersView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var api: APIAIProviders?
    @State private var inferenceApi: APIInference?
    @State private var providers: [AIProviderInfo] = []
    @State private var modelStatus: [String: ModelStatusInfo] = [:]
    @State private var runtimeState: RuntimeStateInfo?
    @State private var inferenceJobs: [InferenceJob] = []
    @State private var isLoading = true
    @State private var routingRules: [RoutingRuleResponse] = []
    @State private var modelRuntimeItems: [ModelRuntimeResponse] = []
    @State private var privacyRules: [PrivacyRuleResponse] = []
    @State private var testResult: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                // 页面标题
                headerSection

                // 1. Provider 总览
                providerOverviewSection

                // 2. 任务路由矩阵
                routingMatrixSection

                // 3. 模型运行状态
                modelRuntimeSection

                // 4. 推理队列
                inferenceQueueSection

                // 5. 隐私策略
                privacySettingsSection
            }
            .padding(PulseSpacing.lg)
        }
        .id(settingsState.language)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            api = APIAIProviders(client: networkClient)
            inferenceApi = APIInference(client: networkClient)
            await loadAllData()
        }
    }

    // MARK: - 标题

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                TerminalLabel(text: L10n.zh("AI 服务管理", en: "AI Services"))
                Text(L10n.zh("推理引擎 · 模型调度 · 隐私合规", en: "Inference Engine · Model Routing · Privacy Compliance"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Button {
                Task { await loadAllData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .help(L10n.zh("刷新", en: "Refresh"))
        }
    }

    // MARK: - 1. Provider 总览

    private var providerOverviewSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("Provider 总览", en: "Provider Overview"))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: PulseSpacing.sm) {
                ForEach(providers) { provider in
                    providerCard(provider)
                }
            }

            // 测试结果
            if let result = testResult {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: result.contains("✓") ? "checkmark.circle" : "xmark.circle")
                        .font(PulseFonts.caption)
                    Text(result)
                        .font(PulseFonts.caption)
                }
                .foregroundStyle(result.contains("✓") ? PulseColors.success : PulseColors.danger)
                .padding(PulseSpacing.xs)
                .background(
                    (result.contains("✓") ? PulseColors.success : PulseColors.danger).opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
            }
        }
    }

    private func providerCard(_ provider: AIProviderInfo) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 头部：名称 + 状态
                HStack {
                    Image(systemName: iconForProvider(provider.type))
                        .font(PulseFonts.displaySubheading)
                        .foregroundStyle(provider.isAvailable ? PulseColors.accent : colors.textMuted)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(provider.name)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text(provider.type)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }

                    Spacer()

                    StatusDot(status: provider.isAvailable ? .online : .offline)
                }

                // 指标行
                HStack(spacing: PulseSpacing.md) {
                    metricItem(label: L10n.zh("延迟", en: "Latency"), value: "—")
                    metricItem(label: L10n.zh("模型数", en: "Models"), value: "\(provider.modelCount ?? 0)")
                    metricItem(label: L10n.zh("失败率", en: "Fail Rate"), value: "—")
                }

                // URL + 操作
                HStack {
                    if let url = provider.baseUrl {
                        Text(url)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(L10n.zh("测试", en: "Test")) {
                        Task { await testProvider(provider.name) }
                    }
                    .buttonStyle(.plain)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accent)
                }
            }
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
        }
    }

    // MARK: - 2. 任务路由矩阵

    private var routingMatrixSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("任务路由矩阵", en: "Task Routing Matrix"))

            KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                VStack(spacing: 0) {
                    // 表头
                    routingHeaderRow

                    Divider().foregroundStyle(colors.border)

                    // 数据行
                    ForEach(routingRules, id: \.taskType) { rule in
                        routingDataRow(rule)
                        if rule.taskType != routingRules.last?.taskType {
                            Divider().foregroundStyle(colors.border.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private var routingHeaderRow: some View {
        HStack(spacing: 0) {
            Text(L10n.zh("任务类型", en: "Task Type"))
                .frame(width: 100, alignment: .leading)
            Text(L10n.zh("主路由", en: "Primary"))
                .frame(width: 100, alignment: .leading)
            Text(L10n.zh("备用路由", en: "Fallback"))
                .frame(width: 100, alignment: .leading)
            Text(L10n.zh("超时", en: "Timeout"))
                .frame(width: 60, alignment: .leading)
            Text(L10n.zh("策略", en: "Strategy"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(PulseFonts.monoLabel)
        .foregroundStyle(colors.textMuted)
        .textCase(.uppercase)
        .padding(.vertical, PulseSpacing.xs)
        .padding(.horizontal, PulseSpacing.xs)
    }

    private func routingDataRow(_ rule: RoutingRuleResponse) -> some View {
        HStack(spacing: 0) {
            Text(rule.taskType)
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(colors.textPrimary)
            Text(rule.primary)
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(PulseColors.accent)
            Text(rule.fallback)
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(colors.textSecondary)
            Text(rule.timeout)
                .frame(width: 60, alignment: .leading)
                .foregroundStyle(colors.textSecondary)
            BadgeDot(color: strategyColor(rule.strategy), label: rule.strategy)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(PulseFonts.caption)
        .padding(.vertical, PulseSpacing.xs)
        .padding(.horizontal, PulseSpacing.xs)
    }

    // MARK: - 3. 模型运行状态

    private var modelRuntimeSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("模型运行状态", en: "Model Runtime Status"))

            VStack(spacing: PulseSpacing.xs) {
                ForEach(modelRuntimeItems, id: \.name) { item in
                    KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                        HStack(spacing: PulseSpacing.md) {
                            // 状态指示
                            Circle()
                                .fill(modelStateColor(item.state))
                                .frame(width: 8, height: 8)

                            // 名称
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(PulseFonts.bodyMedium)
                                    .foregroundStyle(colors.textPrimary)
                                Text(item.provider)
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                            }

                            Spacer()

                            // 状态标签
                            BadgeDot(color: modelStateColor(item.state), label: modelStateLabel(item.state))

                            // GPU 内存
                            if let gpu = item.gpuMemoryMb {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("GPU")
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(colors.textMuted)
                                    Text("\(gpu) MB")
                                        .font(PulseFonts.captionMedium)
                                        .foregroundStyle(colors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. 推理队列

    private var inferenceQueueSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                TerminalLabel(text: L10n.zh("推理队列", en: "Inference Queue"))

                Spacer()

                HStack(spacing: PulseSpacing.xs) {
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "running" }.count,
                        label: L10n.zh("运行中", en: "Running"),
                        color: PulseColors.statusActive
                    )
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "pending" }.count,
                        label: L10n.zh("排队中", en: "Queued"),
                        color: PulseColors.warning
                    )
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "failed" }.count,
                        label: L10n.zh("失败", en: "Failed"),
                        color: PulseColors.danger
                    )
                }
            }

            if inferenceJobs.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: L10n.zh("队列为空", en: "Queue Empty"),
                    description: L10n.zh("暂无推理任务", en: "No inference jobs")
                )
            } else {
                VStack(spacing: PulseSpacing.xs) {
                    ForEach(inferenceJobs) { job in
                        inferenceJobRow(job)
                    }
                }
            }
        }
    }

    private func inferenceJobRow(_ job: InferenceJob) -> some View {
        KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                // 状态图标
                Image(systemName: jobStatusIcon(job.status))
                    .font(PulseFonts.label)
                    .foregroundStyle(jobStatusColor(job.status))

                // 任务信息
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: PulseSpacing.xs) {
                        Text(job.modelName)
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textPrimary)
                        Text("[\(job.jobType)]")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                    Text("ID: \(job.id)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                // 费用
                if let cost = job.actualCostUsd ?? job.estimatedCostUsd {
                    Text("$\(cost, specifier: "%.2f")")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textSecondary)
                }

                // 状态
                BadgeDot(color: jobStatusColor(job.status), label: jobStatusLabel(job.status))

                // 取消按钮
                if job.status == "running" || job.status == "pending" {
                    Button {
                        Task { await cancelJob(job.id) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(PulseFonts.label)
                            .foregroundStyle(PulseColors.danger.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.zh("取消任务", en: "Cancel Job"))
                }
            }
        }
    }

    private func queueStatBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - 5. 隐私策略

    private var privacySettingsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("隐私策略", en: "Privacy Policy"))

            KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                VStack(spacing: 0) {
                    // 表头
                    HStack(spacing: 0) {
                        Text(L10n.zh("数据类型", en: "Data Type"))
                            .frame(width: 140, alignment: .leading)
                        Text(L10n.zh("本地推理", en: "Local"))
                            .frame(width: 80, alignment: .center)
                        Text(L10n.zh("云端 API", en: "Cloud API"))
                            .frame(width: 80, alignment: .center)
                        Text(L10n.zh("说明", en: "Notes"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .padding(.vertical, PulseSpacing.xs)
                    .padding(.horizontal, PulseSpacing.xs)

                    Divider().foregroundStyle(colors.border)

                    ForEach(privacyRules, id: \.dataType) { rule in
                        HStack(spacing: 0) {
                            Text(rule.dataType)
                                .frame(width: 140, alignment: .leading)
                                .foregroundStyle(colors.textPrimary)
                            privacyIcon(rule.localAllowed)
                                .frame(width: 80)
                            privacyIcon(rule.cloudAllowed)
                                .frame(width: 80)
                            Text(rule.note)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(colors.textMuted)
                        }
                        .font(PulseFonts.caption)
                        .padding(.vertical, PulseSpacing.xs)
                        .padding(.horizontal, PulseSpacing.xs)

                        if rule.dataType != privacyRules.last?.dataType {
                            Divider().foregroundStyle(colors.border.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func privacyIcon(_ allowed: Bool) -> some View {
        Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle")
            .font(PulseFonts.caption)
            .foregroundStyle(allowed ? PulseColors.success : PulseColors.danger)
    }

    // MARK: - 辅助方法

    private func iconForProvider(_ type: String) -> String {
        switch type {
        case "ollama": return "desktopcomputer"
        case "openai", "openai_compatible": return "cloud"
        case "anthropic": return "brain"
        default: return "server.rack"
        }
    }

    private func strategyColor(_ strategy: String) -> Color {
        switch strategy {
        case "failover": return PulseColors.warning
        case "round-robin": return PulseColors.info
        case "local-only": return PulseColors.success
        case "cost-opt": return PulseColors.purple
        default: return colors.textMuted
        }
    }

    private func modelStateColor(_ state: String) -> Color {
        switch state {
        case "running": return PulseColors.statusActive
        case "loaded", "idle": return PulseColors.info
        case "oom", "error": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private func jobStatusIcon(_ status: String) -> String {
        switch status {
        case "running": return "play.circle.fill"
        case "pending": return "clock"
        case "completed": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.triangle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private func jobStatusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.statusActive
        case "pending": return PulseColors.warning
        case "completed": return PulseColors.success
        case "failed": return PulseColors.danger
        case "cancelled": return colors.textMuted
        default: return colors.textMuted
        }
    }

    private func jobStatusLabel(_ status: String) -> String {
        switch status {
        case "running": return L10n.zh("运行中", en: "Running")
        case "pending": return L10n.zh("排队中", en: "Queued")
        case "completed": return L10n.zh("已完成", en: "Completed")
        case "failed": return L10n.zh("失败", en: "Failed")
        case "cancelled": return L10n.zh("已取消", en: "Cancelled")
        default: return status
        }
    }

    // MARK: - 数据加载

    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        async let configs = api?.listProviders()
        async let m = api?.getModelStatus()
        async let r = inferenceApi?.getRuntimeState()
        async let j = inferenceApi?.listJobs()
        async let routing = api?.getRoutingRules()
        async let privacy = api?.getPrivacyRules()
        async let runtime = api?.getModelRuntime()

        // Convert ProviderConfigView to AIProviderInfo for view compatibility
        if let views = try? await configs {
            providers = views.map { v in
                let baseUrl: String? = (v.config["base_url"]?.value as? String)
                return AIProviderInfo(
                    name: v.providerName,
                    type: v.category,
                    baseUrl: baseUrl,
                    isAvailable: v.isActive || v.status == "active",
                    modelCount: nil
                )
            }
        } else {
            providers = []
        }
        modelStatus = (try? await m) ?? [:]
        runtimeState = try? await r
        inferenceJobs = (try? await j) ?? []
        routingRules = (try? await routing) ?? []
        privacyRules = (try? await privacy) ?? []
        modelRuntimeItems = (try? await runtime) ?? []
    }

    private func testProvider(_ name: String) async {
        testResult = nil
        do {
            let resp = try await api?.testConnection(body: ProviderTestRequestBody(
                category: "llm",
                providerName: name,
                credentials: [:],
                config: [:]
            ))
            testResult = resp?.success == true
                ? "\(name): \(L10n.zh("连接成功", en: "Connected")) ✓"
                : "\(name): \(L10n.zh("连接失败", en: "Connection Failed"))"
        } catch {
            testResult = "\(name): \(L10n.zh("测试失败", en: "Test Failed"))"
        }
    }

    private func cancelJob(_ id: String) async {
        _ = try? await inferenceApi?.cancelJob(id: id)
        await loadAllData()
    }
}


// MARK: - Helpers

private func modelStateLabel(_ state: String) -> String {
    switch state {
    case "running": return L10n.zh("运行中", en: "Running")
    case "loaded": return L10n.zh("已加载", en: "Loaded")
    case "available": return L10n.zh("可用", en: "Available")
    case "idle": return L10n.zh("空闲", en: "Idle")
    case "unavailable": return L10n.zh("不可用", en: "Unavailable")
    case "oom": return "OOM"
    default: return state
    }
}
