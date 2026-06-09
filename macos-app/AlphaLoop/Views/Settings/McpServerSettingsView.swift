// McpServerSettingsView.swift — MCP 服务器状态与审计日志

import SwiftUI

struct McpServerSettingsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var status: McpStatusInfo?
    @State private var auditLogs: [McpAuditLogEntry] = []
    @State private var isLoading = true
    @State private var showRotateConfirm = false
    @State private var rotateResult: McpTokenRotateResult?
    @State private var isRotating = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text(L10n.zh("MCP 服务器", en: "MCP Server"))
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                statusCard
                tokenSection
                auditLogSection
            }
        }
        .id(settingsState.language)
        .task { await loadData() }
        .alert(L10n.zh("轮换 Token", en: "Rotate Token"), isPresented: $showRotateConfirm) {
            Button(L10n.zh("取消", en: "Cancel"), role: .cancel) {}
            Button(L10n.zh("确认轮换", en: "Confirm Rotation"), role: .destructive) {
                Task { await rotateToken() }
            }
        } message: {
            Text(L10n.zh("确定要轮换 MCP Token 吗？旧 Token 将立即失效，所有使用旧 Token 的客户端需要更新。", en: "Are you sure you want to rotate the MCP Token? The old token will be revoked immediately and all clients using it will need to update."))
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("服务状态", en: "Service Status"))
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    if let s = status {
                        HStack(spacing: PulseSpacing.xxs) {
                            StatusDot(status: s.enabled ? .online : .offline)
                            Text(s.enabled ? L10n.zh("已启用", en: "Enabled") : L10n.zh("已禁用", en: "Disabled"))
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                }
                Spacer()
            }

            if let s = status {
                HStack(spacing: PulseSpacing.lg) {
                    statusItem(L10n.zh("绑定地址", en: "Bind Address"), s.bindAddress)
                    statusItem(L10n.zh("总请求数", en: "Total Requests"), "\(s.totalRequests)")
                    statusItem(L10n.zh("最近请求", en: "Last Request"), s.lastRequestAt.map { String($0.prefix(16)) } ?? L10n.zh("无", en: "N/A"))
                }
            }
        }
        .cardStyle()
    }

    private func statusItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
            Text(value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
        }
    }

    // MARK: - Token Section

    @ViewBuilder
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text(L10n.zh("Token 管理", en: "Token Management"))
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(L10n.zh("轮换 MCP 访问 Token，旧 Token 将立即失效", en: "Rotate MCP access token. The old token will be revoked immediately."))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                if isRotating {
                    ProgressView().controlSize(.small)
                } else {
                    KryptonButton(title: L10n.zh("轮换 Token", en: "Rotate Token"), action: {
                            showRotateConfirm = true
                        }, style: .ghost)
                }
            }

            if let result = rotateResult {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PulseColors.success)
                    Text(L10n.zh("Token 已轮换", en: "Token Rotated"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.success)
                    Text(L10n.zh("· 新 Token: \(String(result.newToken.prefix(12)))...", en: "· New Token: \(String(result.newToken.prefix(12)))..."))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Audit Log Section

    private var auditLogSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.zh("审计日志", en: "Audit Log"))

            if auditLogs.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    StatusDot(status: .online)
                    Text(L10n.zh("暂无审计记录", en: "No audit records"))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: PulseSpacing.xxs) {
                    ForEach(Array(auditLogs.enumerated()), id: \.element.id) { index, entry in
                        auditLogRow(entry)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func auditLogRow(_ entry: McpAuditLogEntry) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            // Status color bar
            RoundedRectangle(cornerRadius: 1)
                .fill(entry.responseStatus < 400 ? PulseColors.success : PulseColors.danger)
                .frame(width: 3, height: 28)

            // Tool name
            Text(entry.toolName)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Status code badge
            Text("\(entry.responseStatus)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(entry.responseStatus < 400 ? PulseColors.success : PulseColors.danger)
                .padding(.horizontal, PulseSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.badge)
                        .fill((entry.responseStatus < 400 ? PulseColors.success : PulseColors.danger).opacity(0.12))
                )

            // Latency
            if let latency = entry.latencyMs {
                Text("\(latency)ms")
                    .font(PulseFonts.micro)
                    .foregroundStyle(latency > 1000 ? PulseColors.warning : colors.textMuted)
                    .frame(width: 50, alignment: .trailing)
            }

            // Time
            Text(String(entry.createdAt.prefix(16)))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let api = APIMcp(client: networkClient)
        status = try? await api.getStatus()
        auditLogs = (try? await api.listAuditLogs()) ?? []
    }

    private func rotateToken() async {
        isRotating = true
        defer { isRotating = false }
        let api = APIMcp(client: networkClient)
        rotateResult = try? await api.rotateToken(reason: "手动轮换")
    }
}
