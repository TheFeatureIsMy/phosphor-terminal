// EnvironmentSetupView.swift - 首屏环境检测 + 自动启动
// 自动检测 PostgreSQL/Redis/Backend，自动启动，用户无需手动操作。

import SwiftUI

struct EnvironmentSetupView: View {
    @Environment(PulseColors.self) private var colors
    @ObservedObject var envService: LocalEnvironmentService

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    if envService.isStarting || envService.overallStatus() == .starting {
                        ProgressView()
                            .controlSize(.large)
                            .tint(PulseColors.accent)
                            .padding(.bottom, 8)
                        Text(L10n.zh("正在启动后端服务", en: "Starting Backend Services"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(colors.textPrimary)
                        Text(L10n.zh("请稍候，正在自动拉起 PostgreSQL、Redis 和后端 API", en: "Please wait, automatically starting PostgreSQL, Redis, and Backend API"))
                            .font(.system(size: 13))
                            .foregroundStyle(colors.textSecondary)
                    } else {
                        Image(systemName: "cpu.and.display")
                            .font(.system(size: 44))
                            .foregroundStyle(PulseColors.accent)
                        Text(L10n.zh("环境配置", en: "Environment Setup"))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(colors.textPrimary)
                        Text(L10n.zh("AlphaLoop 正在自动检测并启动后端服务", en: "AlphaLoop is auto-detecting and starting backend services"))
                            .font(.system(size: 13))
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                // 3 个服务状态卡
                VStack(spacing: 12) {
                    serviceRow("PostgreSQL", status: envService.postgresStatus, icon: "server.rack")
                    serviceRow("Redis", status: envService.redisStatus, icon: "bolt.fill")
                    serviceRow("Backend API", status: envService.apiStatus, icon: "cloud.fill")
                }
                .padding(16)
                .background(colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))

                // 操作按钮
                VStack(spacing: 12) {
                    if envService.overallStatus() == .allHealthy {
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("EnvironmentReady"), object: nil)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(L10n.zh("后端就绪，进入登录", en: "Backend Ready, Continue"))
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PulseColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)
                    } else if envService.overallStatus() == .notInstalled {
                        VStack(spacing: 12) {
                            Text(L10n.zh("缺少必要依赖，请安装后重启 App", en: "Missing dependencies. Please install and restart."))
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)

                            Text(L10n.zh("在终端执行：", en: "Run in terminal:"))
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textSecondary)

                            Text("brew install postgresql@16 redis python@3.11")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(PulseColors.accent)
                                .padding(8)
                                .background(colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    } else if envService.isStarting {
                        // 启动中不显示按钮
                    } else {
                        Button {
                            Task { await envService.startAll() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text(L10n.zh("一键启动", en: "Start All"))
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PulseColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 日志输出
                if !envService.lastLog.isEmpty {
                    Text(envService.lastLog)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 480)
        }
    }

    private func serviceRow(_ name: String, status: LocalEnvironmentService.ServiceStatus, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(colors.textSecondary)
                .frame(width: 20)
            Text(name)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            statusBadge(status)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: LocalEnvironmentService.ServiceStatus) -> some View {
        switch status {
        case .unknown, .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(L10n.zh("检测中", en: "Checking"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        case .notRunning, .starting:
            HStack(spacing: 4) {
                Circle().fill(PulseColors.amber).frame(width: 6, height: 6)
                Text(status == .starting ? L10n.zh("启动中", en: "Starting") : L10n.zh("未启动", en: "Not Running"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.amber)
            }
        case .healthy:
            HStack(spacing: 4) {
                Circle().fill(PulseColors.success).frame(width: 6, height: 6)
                Text(L10n.zh("运行中", en: "Running"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.success)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                Circle().fill(PulseColors.danger).frame(width: 6, height: 6)
                Text(msg == "not_installed" ? L10n.zh("未安装", en: "Not Installed") : msg)
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.danger)
            }
        }
    }
}
