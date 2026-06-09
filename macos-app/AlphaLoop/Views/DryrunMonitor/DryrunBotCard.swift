// DryrunBotCard.swift — Dryrun Bot 卡片
// 显示单个 dryrun 运行的状态、策略信息、操作按钮

import SwiftUI

struct DryrunBotCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let run: StrategyRunV2
    let onStop: (() -> Void)?
    let onViewDetail: () -> Void

    var body: some View {
        KryptonCard(emphasis: .balanced, cardPadding: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // 第一行：状态指示 + 策略名 + 模式徽章
                HStack(spacing: PulseSpacing.sm) {
                    PulsingDot(color: dotColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(strategyName)
                            .font(PulseFonts.bodyMedium)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)

                        Text(truncateUUID(run.strategyVersionId))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }

                    Spacer()

                    modeBadge(run.mode)

                    BadgeView(
                        text: statusLabel(run.status),
                        color: statusColor(run.status),
                        size: .small
                    )
                }

                Divider()
                    .foregroundStyle(colors.border)

                // 第二行：统计信息
                HStack(spacing: PulseSpacing.lg) {
                    statItem(icon: "heart.fill", label: L10n.zh("心跳", en: "Heartbeat"), value: heartbeatDisplay)
                    statItem(icon: "folder", label: L10n.zh("配置", en: "Config"), value: configDisplay)
                    statItem(icon: "clock", label: L10n.zh("运行时长", en: "Uptime"), value: uptimeDisplay)
                }

                // 第三行：操作按钮
                HStack(spacing: PulseSpacing.sm) {
                    Spacer()

                    if let onStop, isRunning {
                        Button(action: onStop) {
                            HStack(spacing: PulseSpacing.xxs) {
                                Image(systemName: "stop.circle")
                                    .font(PulseFonts.caption)
                                Text(L10n.zh("停止", en: "Stop"))
                                    .font(PulseFonts.monoLabel)
                            }
                            .foregroundStyle(PulseColors.danger)
                            .padding(.horizontal, PulseSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.button)
                                    .fill(PulseColors.danger.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PulseRadii.button)
                                    .stroke(PulseColors.danger.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onViewDetail) {
                        HStack(spacing: PulseSpacing.xxs) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(PulseFonts.caption)
                            Text(L10n.zh("查看详情", en: "View Details"))
                                .font(PulseFonts.monoLabel)
                        }
                        .foregroundStyle(PulseColors.accent)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.button)
                                .fill(PulseColors.accent.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.button)
                                .stroke(PulseColors.accent.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 统计项

    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)

            Text(label)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)

            Text(value)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - 计算属性

    private var isRunning: Bool {
        ["running", "starting", "degraded"].contains(run.status)
    }

    private var dotColor: Color {
        switch run.status {
        case "running": return PulseColors.statusActive
        case "starting": return PulseColors.warning
        case "error": return PulseColors.statusError
        case "stopped", "completed": return colors.textMuted
        case "degraded": return PulseColors.warning
        default: return colors.textMuted
        }
    }

    private var strategyName: String {
        // 从 configSnapshot 提取策略名，若无则显示版本 ID
        if let config = run.configSnapshot?.value as? [String: Any],
           let symbol = config["symbol"] as? String {
            return symbol
        }
        return "\(L10n.zh("策略", en: "Strategy")) \(String(run.strategyVersionId.prefix(6)))"
    }

    private var heartbeatDisplay: String {
        // 对于运行中的，显示相对时间
        if isRunning {
            return L10n.zh("刚刚", en: "Just now")
        }
        return "—"
    }

    private var configDisplay: String {
        if let config = run.configSnapshot?.value as? [String: Any],
           let exchange = config["exchange"] as? String {
            return exchange
        }
        return "—"
    }

    private var uptimeDisplay: String {
        guard let startStr = run.startedAt else { return "—" }
        let fmt = ISO8601DateFormatter()
        guard let startDate = fmt.date(from: startStr) else { return "—" }
        let endDate: Date
        if let stopStr = run.stoppedAt, let stopDate = fmt.date(from: stopStr) {
            endDate = stopDate
        } else {
            endDate = Date()
        }
        let interval = endDate.timeIntervalSince(startDate)
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let h = Int(interval / 3600)
            let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h \(m)m"
        }
    }

    // MARK: - 通用

    private func modeBadge(_ mode: String) -> some View {
        let (label, color) = modeInfo(mode)
        return BadgeDot(color: color, label: label, size: .small)
    }

    private func modeInfo(_ mode: String) -> (String, Color) {
        switch mode {
        case "backtest": return ("backtest", PulseColors.info)
        case "dryrun": return ("dryrun", PulseColors.warning)
        case "live_small", "live": return ("live", PulseColors.danger)
        default: return (mode, colors.textMuted)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "running": return L10n.zh("运行中", en: "Running")
        case "completed": return L10n.zh("已完成", en: "Completed")
        case "stopped": return L10n.zh("已停止", en: "Stopped")
        case "error": return L10n.zh("失败", en: "Failed")
        case "starting": return L10n.zh("启动中", en: "Starting")
        case "degraded": return L10n.zh("降级", en: "Degraded")
        default: return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running", "starting": return PulseColors.statusActive
        case "completed": return PulseColors.info
        case "stopped": return colors.textMuted
        case "error": return PulseColors.statusError
        case "degraded": return PulseColors.warning
        default: return colors.textMuted
        }
    }

    private func truncateUUID(_ uuid: String) -> String {
        if uuid.count > 12 {
            return String(uuid.prefix(8)) + "..."
        }
        return uuid
    }
}
