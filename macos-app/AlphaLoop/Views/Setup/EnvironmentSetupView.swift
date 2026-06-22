// EnvironmentSetupView.swift — 首屏环境检测 + 一键启动后端
// 用户无感安装：显示 4 个服务状态，点击 "一键启动后端" 执行 docker compose up。
import SwiftUI

struct EnvironmentSetupView: View {
    @Environment(PulseColors.self) private var colors
    @StateObject private var dockerService = DockerEnvironmentService()
    @State private var hasLaunched = false

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            BackgroundLayersView()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "cpu.and.display")
                        .font(.system(size: 44))
                        .foregroundStyle(PulseColors.accent)
                    Text("环境配置")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(colors.textPrimary)
                    Text("AlphaLoop 需要后端服务支持，一键启动即可")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.textSecondary)
                }

                // 4 个服务状态卡
                VStack(spacing: 12) {
                    serviceRow("Docker", status: dockerService.dockerRunning, icon: "square.stack.3d.down.right.fill")
                    serviceRow("PostgreSQL", status: dockerService.postgresStatus, icon: "server.rack")
                    serviceRow("Redis", status: dockerService.redisStatus, icon: "bolt.fill")
                    serviceRow("Freqtrade", status: dockerService.freqtradeStatus, icon: "chart.line.uptrend.xyaxis")
                    serviceRow("Backend API", status: dockerService.apiStatus, icon: "cloud.fill")
                }
                .padding(16)
                .background(colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))

                // 操作按钮
                VStack(spacing: 12) {
                    if dockerService.overallStatus() == .allHealthy {
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("EnvironmentReady"), object: nil)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("后端就绪，进入登录")
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PulseColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)
                    } else if dockerService.overallStatus() == .notInstalled {
                        Link(destination: URL(string: "https://www.docker.com/products/docker-desktop/")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("下载 Docker Desktop")
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PulseColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)

                        Text("安装后重启 App 即可自动检测")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    } else if dockerService.overallStatus() == .dockerNotRunning {
                        Button {
                            Task { await dockerService.checkAll() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("启动 Docker 后点此重试")
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PulseColors.amber)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            hasLaunched = true
                            Task { await dockerService.startAll() }
                        } label: {
                            HStack(spacing: 8) {
                                if dockerService.isStarting {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(dockerService.isStarting ? "正在启动后端..." : "一键启动后端")
                            }
                            .font(PulseFonts.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(dockerService.isStarting ? colors.surface : PulseColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                        .buttonStyle(.plain)
                        .disabled(dockerService.isStarting)
                    }
                }

                // 日志输出
                if !dockerService.lastLog.isEmpty {
                    Text(dockerService.lastLog)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 480)
        }
        .task {
            await dockerService.checkAll()
        }
    }

    private func serviceRow(_ name: String, status: DockerEnvironmentService.ServiceStatus, icon: String) -> some View {
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
    private func statusBadge(_ status: DockerEnvironmentService.ServiceStatus) -> some View {
        switch status {
        case .unknown, .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("检测中")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        case .notRunning, .starting:
            HStack(spacing: 4) {
                Circle().fill(PulseColors.amber).frame(width: 6, height: 6)
                Text("未启动")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.amber)
            }
        case .healthy:
            HStack(spacing: 4) {
                Circle().fill(PulseColors.success).frame(width: 6, height: 6)
                Text("运行中")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.success)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                Circle().fill(PulseColors.danger).frame(width: 6, height: 6)
                Text(msg)
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.danger)
            }
        }
    }
}
