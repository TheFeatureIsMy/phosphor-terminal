// RiskCenterView.swift — 风控中心（重新设计：作战指挥室风格）

import SwiftUI

struct RiskCenterView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @State private var viewModel: RiskCenterViewModel?
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Atmospheric background glow based on risk state
            atmosphericBackground

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseSpacing.xl) {
                    if let vm = viewModel {
                        if vm.isLoading && vm.overview == nil {
                            LoadingView(type: .detail)
                        } else if let overview = vm.overview {
                            // Hero risk gauge
                            heroRiskGauge(overview)

                            // Guards grid (arc gauges)
                            guardsGrid(overview.guards)

                            // Emergency action panel
                            emergencyPanel(vm, overview: overview)

                        } else if let error = vm.error {
                            EmptyStateView(
                                icon: "exclamationmark.triangle",
                                title: L10n.Common.error,
                                description: error,
                                primaryAction: (title: L10n.Common.retry, action: { Task { await vm.loadOverview() } })
                            )
                        } else {
                            EmptyStateView(
                                icon: "shield.checkered",
                                title: L10n.Common.noData,
                                description: L10n.zh("风控系统尚未返回数据", en: "Risk system has not returned data")
                            )
                        }
                    }
                }
                .padding(PulseSpacing.xl)
                .id(settingsState.language)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
        .task {
            let vm = RiskCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadOverview()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        let riskColor = overallRiskColor
        return ZStack {
            colors.background

            // Radial glow from center-top
            RadialGradient(
                colors: [
                    riskColor.opacity(0.08 + pulsePhase * 0.04),
                    riskColor.opacity(0.02),
                    Color.clear,
                ],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )

            // Scanline effect (very subtle)
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.008)))
                }
            }
        }
        .ignoresSafeArea()
    }

    private var overallRiskColor: Color {
        guard let overview = viewModel?.overview else { return PulseColors.accent }
        switch overview.state {
        case "normal": return PulseColors.StateColors.green
        case "warning", "degraded": return PulseColors.StateColors.yellow
        case "emergency", "locked": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.orange
        }
    }

    // MARK: - Hero Risk Gauge

    private func heroRiskGauge(_ overview: RiskOverviewBFFResponse) -> some View {
        VStack(spacing: PulseSpacing.lg) {
            // Title
            HStack {
                TerminalLabel(text: L10n.zh("风控中心", en: "RISK CENTER"))
                Spacer()
                if !overview.reasonCodes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text(overview.reasonCodes.first ?? "")
                            .font(PulseFonts.micro)
                    }
                    .foregroundStyle(overallRiskColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(overallRiskColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // Main gauge
            HStack(spacing: PulseSpacing.xl) {
                // Left: Arc gauge
                ZStack {
                    // Outer ring (background)
                    Circle()
                        .stroke(colors.surface, lineWidth: 6)
                        .frame(width: 180, height: 180)

                    // Gauge arc (270 degrees)
                    ArcGauge(value: riskGaugeValue(overview), lineWidth: 8, size: 180, color: overallRiskColor)

                    // Inner content
                    VStack(spacing: 4) {
                        Text(accountStateLabel(overview.accountState))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(overallRiskColor)

                        Text(overview.accountState.uppercased())
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .tracking(2)

                        if overview.emergencyLocked {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                Text("LOCKED")
                                    .font(PulseFonts.micro)
                            }
                            .foregroundStyle(PulseColors.StateColors.red)
                            .padding(.top, 4)
                        }
                    }

                    // Pulsing outer ring for non-normal states
                    if overview.state != "normal" {
                        Circle()
                            .stroke(overallRiskColor.opacity(0.3 * pulsePhase), lineWidth: 2)
                            .frame(width: 196, height: 196)
                    }
                }
                .frame(width: 200, height: 200)

                // Right: Quick stats
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    quickStat(
                        icon: "shield.checkered",
                        label: L10n.zh("系统状态", en: "System State"),
                        value: stateDisplayName(overview.state),
                        color: overallRiskColor
                    )
                    quickStat(
                        icon: "exclamationmark.triangle",
                        label: L10n.zh("守卫告警", en: "Guard Alerts"),
                        value: "\(overview.guards.filter { $0.status != "healthy" }.count) / \(overview.guards.count)",
                        color: overview.guards.contains(where: { $0.status == "breached" }) ? PulseColors.StateColors.red : PulseColors.StateColors.green
                    )
                    quickStat(
                        icon: "bolt.shield",
                        label: L10n.zh("紧急锁定", en: "Emergency Lock"),
                        value: overview.emergencyLocked ? "ACTIVE" : "OFF",
                        color: overview.emergencyLocked ? PulseColors.StateColors.red : PulseColors.StateColors.green
                    )
                    quickStat(
                        icon: "clock.badge.exclamationmark",
                        label: L10n.zh("风险原因", en: "Reason Codes"),
                        value: overview.reasonCodes.isEmpty ? "—" : "\(overview.reasonCodes.count)",
                        color: colors.textSecondary
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PulseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .stroke(overallRiskColor.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    private func quickStat(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Text(value)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(color)
            }
        }
    }

    private func riskGaugeValue(_ overview: RiskOverviewBFFResponse) -> Double {
        switch overview.accountState {
        case "normal": return 0.15
        case "warning": return 0.5
        case "restricted": return 0.7
        case "locked": return 0.9
        case "emergency": return 1.0
        default: return 0.3
        }
    }

    private func accountStateLabel(_ state: String) -> String {
        switch state {
        case "normal": return "SAFE"
        case "warning": return "WARN"
        case "restricted": return "RISK"
        case "locked": return "LOCK"
        case "emergency": return "HALT"
        default: return "—"
        }
    }

    private func stateDisplayName(_ state: String) -> String {
        switch state {
        case "normal": return L10n.zh("正常", en: "Normal")
        case "warning": return L10n.zh("警告", en: "Warning")
        case "degraded": return L10n.zh("降级", en: "Degraded")
        case "locked": return L10n.zh("锁定", en: "Locked")
        case "emergency": return L10n.zh("紧急", en: "Emergency")
        default: return state
        }
    }

    // MARK: - Guards Grid

    private func guardsGrid(_ guards: [RiskGuardResponse]) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            TerminalLabel(text: L10n.zh("风控守卫", en: "RISK GUARDS"))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: PulseSpacing.md),
                GridItem(.flexible(), spacing: PulseSpacing.md),
                GridItem(.flexible(), spacing: PulseSpacing.md),
            ], spacing: PulseSpacing.md) {
                ForEach(Array(guards.enumerated()), id: \.element.id) { index, guard_ in
                    guardArcCard(guard_)
                        .staggeredAppearance(index: index)
                }
            }
        }
    }

    private func guardArcCard(_ guard_: RiskGuardResponse) -> some View {
        let usedPct = 1.0 - guard_.remainingPct
        let color = guardColor(guard_.status, remainingPct: guard_.remainingPct)

        return VStack(spacing: PulseSpacing.sm) {
            // Mini arc gauge
            ZStack {
                // Background arc
                ArcShape(startAngle: -135, endAngle: 135)
                    .stroke(colors.surface, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 70, height: 70)

                // Value arc
                ArcShape(startAngle: -135, endAngle: -135 + 270 * usedPct)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 70, height: 70)

                // Center value
                Text(String(format: "%.0f%%", usedPct * 100))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: 4)
            }
            .frame(height: 60)

            // Label
            Text(guard_.label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            // Current / Limit
            Text("\(guard_.currentValue, specifier: "%.1f") / \(guard_.limitValue, specifier: "%.1f")")
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)

            // Status badge
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(guardStatusLabel(guard_.status))
                    .font(PulseFonts.micro)
            }
            .foregroundStyle(color)
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(guard_.status == "breached" ? color.opacity(0.4) : colors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func guardColor(_ status: String, remainingPct: Double) -> Color {
        switch status {
        case "healthy": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "critical": return PulseColors.StateColors.orangeRed
        case "breached": return PulseColors.StateColors.red
        default:
            if remainingPct > 0.5 { return PulseColors.StateColors.green }
            if remainingPct > 0.2 { return PulseColors.StateColors.yellow }
            return PulseColors.StateColors.red
        }
    }

    private func guardStatusLabel(_ status: String) -> String {
        switch status {
        case "healthy": return L10n.Common.healthy
        case "warning": return L10n.Common.warning
        case "critical": return L10n.zh("临界", en: "Critical")
        case "breached": return L10n.zh("突破", en: "Breached")
        default: return status
        }
    }

    // MARK: - Emergency Panel

    private func emergencyPanel(_ vm: RiskCenterViewModel, overview: RiskOverviewBFFResponse) -> some View {
        VStack(spacing: PulseSpacing.md) {
            TerminalLabel(text: L10n.zh("紧急操作", en: "EMERGENCY ACTIONS"))

            HStack(spacing: PulseSpacing.md) {
                // Block new entries button
                actionButton(
                    icon: "hand.raised.fill",
                    title: L10n.zh("禁止新开仓", en: "Block Entries"),
                    subtitle: L10n.zh("阻止新订单", en: "Prevent new orders"),
                    color: PulseColors.StateColors.orange,
                    action: {}
                )

                // Unblock button
                actionButton(
                    icon: "checkmark.shield",
                    title: L10n.zh("解除禁止", en: "Unblock"),
                    subtitle: L10n.zh("恢复正常操作", en: "Resume normal ops"),
                    color: PulseColors.StateColors.green,
                    action: {}
                )

                // Emergency stop
                emergencyStopButton(vm)
            }
        }
    }

    private func actionButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: PulseSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(title)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)

                Text(subtitle)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(PulseSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func emergencyStopButton(_ vm: RiskCenterViewModel) -> some View {
        Button {
            Task { await vm.emergencyStop() }
        } label: {
            VStack(spacing: PulseSpacing.xs) {
                ZStack {
                    // Pulsing danger ring
                    Circle()
                        .stroke(PulseColors.StateColors.red.opacity(0.3 * pulsePhase), lineWidth: 2)
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(PulseColors.StateColors.red.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PulseColors.StateColors.red)
                }

                Text(L10n.zh("紧急停止", en: "EMERGENCY"))
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(PulseColors.StateColors.red)

                Text(L10n.zh("停止一切交易", en: "Halt all trading"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(PulseSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .stroke(PulseColors.StateColors.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arc Gauge Component

private struct ArcGauge: View {
    let value: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            ArcShape(startAngle: -135, endAngle: 135)
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            ArcShape(startAngle: -135, endAngle: -135 + 270 * value)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color],
                        center: .center,
                        startAngle: .degrees(-135),
                        endAngle: .degrees(-135 + 270 * value)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)

            // End dot
            Circle()
                .fill(color)
                .frame(width: lineWidth + 2, height: lineWidth + 2)
                .shadow(color: color.opacity(0.5), radius: 4)
                .offset(arcEndOffset(angle: -135 + 270 * value, radius: size / 2))
        }
    }

    private func arcEndOffset(angle: Double, radius: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        return CGSize(
            width: radius * cos(radians),
            height: radius * sin(radians)
        )
    }
}

// MARK: - Arc Shape

private struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}
