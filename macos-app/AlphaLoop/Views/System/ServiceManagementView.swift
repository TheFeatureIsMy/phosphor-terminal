// ServiceManagementView.swift - 服务管理
// 真实服务状态总览 + AI Provider 管理 + 不伪造 start/stop 按钮

import SwiftUI

struct ServiceManagementView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: ServiceManagementViewModel?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.lg) {
                if let vm = viewModel {
                    if vm.isLoading && vm.serviceStatus == nil {
                        LoadingView(type: .detail)
                            .padding(PulseSpacing.lg)
                    } else if vm.serviceStatus != nil {
                        headerSection(vm)
                        stateBanner(vm)
                        serviceStatusGrid(vm)
                        aiProviderSection
                    } else if let error = vm.error {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: L10n.zh("加载失败", en: "Load Failed"),
                            description: error,
                            primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.load() } })
                        )
                    }
                } else {
                    LoadingView(type: .detail)
                        .padding(PulseSpacing.lg)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .id(settingsState.language)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            if viewModel == nil {
                let vm = ServiceManagementViewModel(client: networkClient)
                viewModel = vm
                await vm.load()
            }
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: ServiceManagementViewModel) -> some View {
        QuantPageHeader(
            eyebrow: "SYSTEM",
            title: L10n.zh("服务管理", en: "Service Management"),
            subtitle: L10n.zh("后端 · 数据库 · 缓存 · 交易所 · 模型网关 - 全链路健康监控", en: "Backend · Database · Cache · Exchange · Model Gateway - Full Health Monitor")
        ) {
            Button {
                Task { await vm.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .help(L10n.zh("刷新", en: "Refresh"))
        }
    }

    // MARK: - State Banner

    @ViewBuilder
    private func stateBanner(_ vm: ServiceManagementViewModel) -> some View {
        let stateColor: Color = vm.state == "healthy" ? PulseColors.success : (vm.state == "warning" ? PulseColors.warning : PulseColors.danger)
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: vm.state == "healthy" ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(PulseFonts.body)
                .foregroundStyle(stateColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.state == "healthy"
                     ? L10n.zh("所有服务正常运行", en: "All Services Healthy")
                     : (vm.state == "warning"
                        ? L10n.zh("部分服务异常", en: "Some Services Degraded")
                        : L10n.zh("服务异常", en: "Service Error")))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(L10n.zh("\(vm.healthyCount) 正常 / \(vm.errorCount) 异常", en: "\(vm.healthyCount) healthy / \(vm.errorCount) errors"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(stateColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(stateColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Service Status Grid

    private func serviceStatusGrid(_ vm: ServiceManagementViewModel) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("服务状态", en: "Service Status"))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: PulseSpacing.sm) {
                ForEach(vm.services) { service in
                    serviceCard(service, vm: vm)
                }
            }
        }
    }

    private func serviceCard(_ service: ServiceStatusItem, vm: ServiceManagementViewModel) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack {
                    Image(systemName: vm.iconFor(service.name))
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textSecondary)
                    Text(vm.displayName(service.name))
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    StatusDot(status: vm.isHealthy(service) ? .online : (vm.isError(service) ? .offline : .warning))
                }

                HStack {
                    Text(vm.statusLabel(service))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(vm.statusColor(service))
                    Spacer()
                }

                if let detail = service.detail, !detail.isEmpty {
                    Text(detail)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                if let error = service.error, !error.isEmpty {
                    HStack(alignment: .top, spacing: PulseSpacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.danger)
                        Text(error)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.danger)
                            .lineLimit(2)
                    }
                }
                if let version = service.version {
                    Text(L10n.zh("版本: \(version)", en: "Version: \(version)"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                if let mem = service.usedMemoryMb {
                    Text(L10n.zh("内存: \(String(format: "%.1f", mem)) MB", en: "Memory: \(String(format: "%.1f", mem)) MB"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                if let clients = service.connectedClients {
                    Text(L10n.zh("连接数: \(clients)", en: "Connections: \(clients)"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                if let pos = service.openPositions {
                    Text(L10n.zh("持仓: \(pos)", en: "Positions: \(pos)"))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    // MARK: - AI Provider Section

    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("AI Provider 管理", en: "AI Provider Management"))
            AIProvidersView()
        }
    }
}
