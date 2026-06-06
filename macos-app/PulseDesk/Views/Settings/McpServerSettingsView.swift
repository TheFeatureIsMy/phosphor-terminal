// McpServerSettingsView.swift — MCP 服务器状态与审计日志

import SwiftUI

struct McpServerSettingsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var status: McpStatusInfo?
    @State private var auditLogs: [McpAuditLogEntry] = []
    @State private var isLoading = true
    @State private var showRotateConfirm = false
    @State private var rotateResult: McpTokenRotateResult?
    @State private var isRotating = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("MCP 服务器")
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
        .task { await loadData() }
        .alert("轮换 Token", isPresented: $showRotateConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认轮换", role: .destructive) {
                Task { await rotateToken() }
            }
        } message: {
            Text("确定要轮换 MCP Token 吗？旧 Token 将立即失效，所有使用旧 Token 的客户端需要更新。")
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("服务状态")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    if let s = status {
                        HStack(spacing: PulseSpacing.xxs) {
                            StatusDot(status: s.enabled ? .online : .offline)
                            Text(s.enabled ? "已启用" : "已禁用")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                }
                Spacer()
            }

            if let s = status {
                HStack(spacing: PulseSpacing.lg) {
                    statusItem("绑定地址", s.bindAddress)
                    statusItem("总请求数", "\(s.totalRequests)")
                    statusItem("最近请求", s.lastRequestAt.map { String($0.prefix(16)) } ?? "无")
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
                    Text("Token 管理")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text("轮换 MCP 访问 Token，旧 Token 将立即失效")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                if isRotating {
                    ProgressView().controlSize(.small)
                } else {
                    ProofAlphaButton(title: "轮换 Token", action: {
                        showRotateConfirm = true
                    }, style: .ghost)
                }
            }

            if let result = rotateResult {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PulseColors.success)
                    Text("Token 已轮换")
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.success)
                    Text("· 新 Token: \(String(result.newToken.prefix(12)))...")
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
            TerminalLabel(text: "审计日志")

            if auditLogs.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    StatusDot(status: .online)
                    Text("暂无审计记录")
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
