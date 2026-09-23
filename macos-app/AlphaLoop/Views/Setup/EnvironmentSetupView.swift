// EnvironmentSetupView.swift — VOLT 启动序列首屏
// 电路纹理 + 电光 Logo + 编号服务行 + 终端日志 + 电光进度条。
// 自动检测 PostgreSQL/Redis/Backend 并一键拉起。

import SwiftUI

struct EnvironmentSetupView: View {
    @Environment(PulseColors.self) private var colors
    @ObservedObject var envService: LocalEnvironmentService

    @State private var appeared = false
    @State private var cursorOn = true
    @State private var ctaHovered = false

    private var healthyCount: Int {
        [envService.postgresStatus, envService.redisStatus, envService.apiStatus]
            .filter { $0 == .healthy }.count
    }

    private var allHealthy: Bool { envService.overallStatus() == .allHealthy }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            // VOLT 氛围层：电路纹理 + 顶部电光晕
            CircuitTexture()
                .scaleEffect(2.6)
                .opacity(0.55)
                .offset(x: 240, y: -160)
                .allowsHitTesting(false)
            RadialGradient(
                colors: [PulseColors.accent.opacity(0.07), .clear],
                center: .init(x: 0.5, y: 0.18),
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 26) {
                header
                progressBar
                servicePanel
                bootLog
                ctaArea
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(PulseAnimation.easeOutMedium) { appeared = true }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOn = false
            }
        }
    }

    // MARK: - Header（Logo + eyebrow + 大标题）

    private var header: some View {
        VStack(spacing: PulseSpacing.md) {
            // 实心电光黄 Logo mark — 与 Landing / App Icon 同款
            RoundedRectangle(cornerRadius: 13)
                .fill(PulseColors.accent)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "0A0A0C"))
                )
                .shadow(color: PulseColors.accent.opacity(0.45), radius: 22)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("SYSTEM BOOT // 环境自检")
                    .font(PulseFonts.mono(10, .semibold))
                    .tracking(2.2)
                    .foregroundStyle(PulseColors.accentText)

                Text(L10n.zh("启动序列", en: "Boot Sequence"))
                    .font(PulseFonts.display(30, .black))
                    .foregroundStyle(colors.textPrimary)
                    .tracking(-0.5)

                Text(L10n.zh("正在检测并拉起本地量化栈 · PostgreSQL / Redis / Backend API",
                             en: "Detecting & starting the local quant stack"))
                    .font(PulseFonts.body(12.5))
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    // MARK: - 电光进度条（3 段 = 3 服务）

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < healthyCount ? PulseColors.accent : colors.surface)
                    .frame(height: 3)
                    .shadow(color: i < healthyCount ? PulseColors.accent.opacity(0.6) : .clear, radius: 4)
                    .animation(PulseAnimation.easeOutMedium, value: healthyCount)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 服务面板（编号行 + 状态芯片 + 启动扫描线）

    private var servicePanel: some View {
        VStack(spacing: 8) {
            bootRow(index: "01", name: "PostgreSQL", port: ":5432",
                    icon: "server.rack", status: envService.postgresStatus)
                .staggeredAppearance(index: 0, baseDelay: 0.08)
            bootRow(index: "02", name: "Redis", port: ":6379",
                    icon: "bolt.fill", status: envService.redisStatus)
                .staggeredAppearance(index: 1, baseDelay: 0.08)
            bootRow(index: "03", name: "Backend API", port: ":8000",
                    icon: "waveform.path.ecg", status: envService.apiStatus)
                .staggeredAppearance(index: 2, baseDelay: 0.08)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(allHealthy ? PulseColors.accent.opacity(0.35) : colors.border, lineWidth: 1)
        )
        .shadow(color: allHealthy ? PulseColors.accent.opacity(0.08) : .clear, radius: 28, y: 0)
    }

    private func bootRow(index: String, name: String, port: String,
                         icon: String, status: LocalEnvironmentService.ServiceStatus) -> some View {
        let tint = statusTint(status)
        return HStack(spacing: 12) {
            // 编号
            Text(index)
                .font(PulseFonts.mono(10, .bold))
                .foregroundStyle(colors.textMuted.opacity(0.7))

            // 图标芯片
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .fill(tint.opacity(status == .healthy ? 0.14 : 0.08))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(PulseFonts.body(13, .semibold))
                    .foregroundStyle(colors.textPrimary)
                Text(port)
                    .font(PulseFonts.mono(9.5, .medium))
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            statusChip(status, tint: tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(status == .healthy ? tint.opacity(0.25) : colors.border.opacity(0.7), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            if status == .starting {
                BootScanLine()
                    .padding(.horizontal, 10)
                    .offset(y: 3)
            }
        }
    }

    private func statusTint(_ status: LocalEnvironmentService.ServiceStatus) -> Color {
        switch status {
        case .healthy: return PulseColors.success
        case .failed: return PulseColors.danger
        case .starting, .notRunning: return PulseColors.amber
        case .unknown, .checking: return colors.textMuted
        }
    }

    @ViewBuilder
    private func statusChip(_ status: LocalEnvironmentService.ServiceStatus, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .shadow(color: tint.opacity(0.6), radius: 3)
                .opacity(status == .starting ? (cursorOn ? 1 : 0.3) : 1)
            Text(statusLabel(status))
                .font(PulseFonts.mono(9.5, .bold))
                .tracking(1)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func statusLabel(_ status: LocalEnvironmentService.ServiceStatus) -> String {
        switch status {
        case .unknown, .checking:
            return L10n.zh("检测中", en: "PROBING")
        case .notRunning:
            return L10n.zh("未启动", en: "DOWN")
        case .starting:
            return L10n.zh("启动中", en: "BOOTING")
        case .healthy:
            return L10n.zh("运行中", en: "ONLINE")
        case .failed(let msg):
            return msg == "not_installed" ? L10n.zh("未安装", en: "MISSING") : "ERROR"
        }
    }

    // MARK: - 终端日志（mono + 闪烁光标）

    private var bootLog: some View {
        HStack(spacing: 6) {
            Text("▸")
                .foregroundStyle(PulseColors.accentText)
            Text(envService.lastLog.isEmpty
                 ? L10n.zh("等待指令...", en: "awaiting command...")
                 : envService.lastLog)
                .foregroundStyle(colors.textMuted)
                .lineLimit(1)
            Rectangle()
                .fill(PulseColors.accent)
                .frame(width: 6, height: 11)
                .opacity(cursorOn ? 0.9 : 0)
            Spacer()
            Text("\(healthyCount)/3")
                .foregroundStyle(healthyCount == 3 ? PulseColors.success : colors.textMuted)
        }
        .font(PulseFonts.mono(10, .medium))
        .padding(.horizontal, 4)
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaArea: some View {
        if envService.overallStatus() == .notInstalled {
            VStack(spacing: 10) {
                Text(L10n.zh("缺少必要依赖，请安装后重启 App", en: "Missing dependencies. Install and restart."))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                Text("brew install postgresql@16 redis python@3.11")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.badge)
                            .fill(colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.badge)
                            .stroke(colors.border, lineWidth: 1)
                    )
            }
        } else {
            Button {
                if allHealthy {
                    NotificationCenter.default.post(name: NSNotification.Name("EnvironmentReady"), object: nil)
                } else {
                    Task { await envService.startAll() }
                }
            } label: {
                HStack(spacing: 8) {
                    if envService.isStarting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color(hex: "0A0A0C"))
                    } else {
                        Image(systemName: allHealthy ? "arrow.right" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(ctaTitle)
                        .font(PulseFonts.mono(12, .heavy))
                        .tracking(1.5)
                }
                .foregroundStyle(Color(hex: "0A0A0C"))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(PulseColors.accent)
                )
                .shadow(color: PulseColors.accent.opacity(ctaHovered ? 0.45 : 0.25), radius: ctaHovered ? 24 : 14, y: 0)
                .scaleEffect(ctaHovered ? 1.015 : 1)
            }
            .buttonStyle(.plain)
            .disabled(envService.isStarting)
            .opacity(envService.isStarting ? 0.7 : 1)
            .onHover { h in
                withAnimation(PulseAnimation.easeOutFast) { ctaHovered = h }
            }
        }
    }

    private var ctaTitle: String {
        if envService.isStarting {
            return L10n.zh("启动中...", en: "BOOTING...")
        }
        return allHealthy
            ? L10n.zh("进入终端", en: "ENTER TERMINAL")
            : L10n.zh("一键启动", en: "START ALL")
    }
}

// MARK: - 启动扫描线（服务 starting 时的滑动电光条）

private struct BootScanLine: View {
    @State private var phase: CGFloat = -0.25

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, PulseColors.amber, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35, height: 2)
            .offset(x: geo.size.width * phase)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
        }
        .frame(height: 2)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .allowsHitTesting(false)
    }
}
