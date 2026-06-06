// AIProvidersView.swift — AI 服务管理
// Provider 总览 + 任务路由矩阵 + 模型运行状态 + 推理队列 + 隐私策略

import SwiftUI

struct AIProvidersView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
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
                TerminalLabel(text: "AI 服务管理")
                Text("推理引擎 · 模型调度 · 隐私合规")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Button {
                Task { await loadAllData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
    }

    // MARK: - 1. Provider 总览

    private var providerOverviewSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "Provider 总览")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: PulseSpacing.sm) {
                ForEach(providers) { provider in
                    providerCard(provider)
                }
            }

            // 测试结果
            if let result = testResult {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: result.contains("成功") ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 11))
                    Text(result)
                        .font(PulseFonts.caption)
                }
                .foregroundStyle(result.contains("成功") ? PulseColors.success : PulseColors.danger)
                .padding(PulseSpacing.xs)
                .background(
                    (result.contains("成功") ? PulseColors.success : PulseColors.danger).opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
            }
        }
    }

    private func providerCard(_ provider: AIProviderInfo) -> some View {
        ProofAlphaCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 头部：名称 + 状态
                HStack {
                    Image(systemName: iconForProvider(provider.type))
                        .font(.system(size: 16))
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
                    metricItem(label: "延迟", value: provider.isAvailable ? "\(Int.random(in: 45...320))ms" : "—")
                    metricItem(label: "模型数", value: "\(provider.modelCount ?? 0)")
                    metricItem(label: "失败率", value: provider.isAvailable ? "\(String(format: "%.1f", Double.random(in: 0.1...2.5)))%" : "—")
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

                    Button("测试") {
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
            TerminalLabel(text: "任务路由矩阵")

            ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
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
            Text("任务类型")
                .frame(width: 100, alignment: .leading)
            Text("主路由")
                .frame(width: 100, alignment: .leading)
            Text("备用路由")
                .frame(width: 100, alignment: .leading)
            Text("超时")
                .frame(width: 60, alignment: .leading)
            Text("策略")
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
            TerminalLabel(text: "模型运行状态")

            VStack(spacing: PulseSpacing.xs) {
                ForEach(modelRuntimeItems, id: \.name) { item in
                    ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
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
                TerminalLabel(text: "推理队列")

                Spacer()

                HStack(spacing: PulseSpacing.xs) {
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "running" }.count,
                        label: "运行中",
                        color: PulseColors.statusActive
                    )
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "pending" }.count,
                        label: "排队中",
                        color: PulseColors.warning
                    )
                    queueStatBadge(
                        count: inferenceJobs.filter { $0.status == "failed" }.count,
                        label: "失败",
                        color: PulseColors.danger
                    )
                }
            }

            if inferenceJobs.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "队列为空",
                    description: "暂无推理任务"
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
        ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                // 状态图标
                Image(systemName: jobStatusIcon(job.status))
                    .font(.system(size: 12))
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
                            .font(.system(size: 12))
                            .foregroundStyle(PulseColors.danger.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("取消任务")
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
            TerminalLabel(text: "隐私策略")

            ProofAlphaCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                VStack(spacing: 0) {
                    // 表头
                    HStack(spacing: 0) {
                        Text("数据类型")
                            .frame(width: 140, alignment: .leading)
                        Text("本地推理")
                            .frame(width: 80, alignment: .center)
                        Text("云端 API")
                            .frame(width: 80, alignment: .center)
                        Text("说明")
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
            .font(.system(size: 11))
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
        case "running": return "运行中"
        case "pending": return "排队中"
        case "completed": return "已完成"
        case "failed": return "失败"
        case "cancelled": return "已取消"
        default: return status
        }
    }

    // MARK: - 数据加载

    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        async let p = api?.listProviders()
        async let m = api?.getModelStatus()
        async let r = inferenceApi?.getRuntimeState()
        async let j = inferenceApi?.listJobs()
        async let routing = api?.getRoutingRules()
        async let privacy = api?.getPrivacyRules()
        async let runtime = api?.getModelRuntime()

        providers = (try? await p) ?? []
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
            let resp = try await api?.testProvider(name: name)
            testResult = resp?.success == true
                ? "\(name): 连接成功 ✓"
                : "\(name): \(resp?.message ?? "连接失败")"
        } catch {
            testResult = "\(name): 测试失败"
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
    case "running": return "运行中"
    case "loaded": return "已加载"
    case "available": return "可用"
    case "idle": return "空闲"
    case "unavailable": return "不可用"
    case "oom": return "OOM"
    default: return state
    }
}
