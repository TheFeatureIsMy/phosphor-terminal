// TradingWorkflowRailView.swift — Daily Trading Loop §3 Workflow Rail
// Cyberpunk neon pipeline: sinusoidal wave + glowing cards + flowing light

import SwiftUI

// MARK: - Step color palette

private struct StepTheme {
    let color: Color
    let icon: String

    static let themes: [String: StepTheme] = [
        "mission_control": .init(color: Color(red: 0.0, green: 0.76, blue: 1.0), icon: "gauge.with.dots.needle.33percent"),
        "opportunity":     .init(color: Color(red: 1.0, green: 0.72, blue: 0.0), icon: "antenna.radiowaves.left.and.right"),
        "strategy":        .init(color: Color(red: 0.65, green: 0.45, blue: 1.0), icon: "doc.text.fill"),
        "mtf_defense":     .init(color: Color(red: 0.30, green: 0.55, blue: 1.0), icon: "shield.lefthalf.filled"),
        "validation":      .init(color: Color(red: 0.0, green: 0.85, blue: 0.55), icon: "chart.line.uptrend.xyaxis"),
        "risk_gate":       .init(color: Color(red: 1.0, green: 0.35, blue: 0.45), icon: "lock.shield.fill"),
        "execution":       .init(color: Color(red: 0.0, green: 0.90, blue: 0.80), icon: "bolt.fill"),
        "review":          .init(color: Color(red: 1.0, green: 0.55, blue: 0.20), icon: "magnifyingglass"),
        "evolution":       .init(color: Color(red: 0.40, green: 0.95, blue: 0.40), icon: "arrow.triangle.2.circlepath"),
    ]

    static func theme(for step: String) -> StepTheme {
        themes[step] ?? .init(color: .gray, icon: "circle")
    }
}

// MARK: - Main View

struct TradingWorkflowRailView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let workflow: DailyWorkflow?

    @State private var flowPhase: CGFloat = 0

    private let cardWidth: CGFloat = 76
    private let cardSpacing: CGFloat = 32
    private let waveAmplitude: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            titleBar
            cardPipeline
        }
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.lg)
                        .fill(colors.cardBackground.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.lg)
                        .stroke(colors.border.opacity(0.5), lineWidth: 0.5)
                )
        )
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                flowPhase = 1.0
            }
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 13))
                .foregroundStyle(PulseColors.accent)
                .shadow(color: PulseColors.accent.opacity(0.5), radius: 4)
            Text(L10n.zh("交易工作流", en: "Trading Workflow"))
                .font(PulseFonts.label)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            if let workflow {
                statusBadge(workflow.globalState)
            }
        }
    }

    // MARK: - Card pipeline with wave

    private var cardPipeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            let steps = workflow?.steps ?? []
            let count = max(steps.count, 9)
            let totalWidth = CGFloat(count) * cardWidth + CGFloat(count - 1) * cardSpacing

            ZStack(alignment: .topLeading) {
                if !steps.isEmpty {
                    waveConnection(stepCount: steps.count, totalWidth: totalWidth)
                        .frame(width: totalWidth, height: 120)
                }

                HStack(spacing: cardSpacing) {
                    if steps.isEmpty {
                        ForEach(0..<9, id: \.self) { i in
                            placeholderCard
                                .offset(y: i.isMultiple(of: 2) ? -waveAmplitude : waveAmplitude)
                        }
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            NeonStepCard(
                                step: step,
                                index: index + 1,
                                theme: StepTheme.theme(for: step.step),
                                isCurrentStep: step.step == workflow?.currentStep
                            ) {
                                navigateToStep(step)
                            }
                            .offset(y: index.isMultiple(of: 2) ? -waveAmplitude : waveAmplitude)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
    }

    // MARK: - Sinusoidal wave connection

    private func waveConnection(stepCount: Int, totalWidth: CGFloat) -> some View {
        let centerY: CGFloat = 44

        return ZStack {
            // Base wave (dim)
            WavePath(stepCount: stepCount, cardWidth: cardWidth, spacing: cardSpacing, amplitude: waveAmplitude, centerY: centerY)
                .stroke(
                    LinearGradient(
                        colors: waveGradientColors(steps: workflow?.steps ?? []),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .opacity(0.2)

            // Dashed wave overlay
            WavePath(stepCount: stepCount, cardWidth: cardWidth, spacing: cardSpacing, amplitude: waveAmplitude, centerY: centerY)
                .stroke(
                    LinearGradient(
                        colors: waveGradientColors(steps: workflow?.steps ?? []),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 8])
                )
                .opacity(0.4)

            // Flowing light (trim animation)
            WavePath(stepCount: stepCount, cardWidth: cardWidth, spacing: cardSpacing, amplitude: waveAmplitude, centerY: centerY)
                .trim(from: max(0, flowPhase - 0.15), to: flowPhase)
                .stroke(
                    LinearGradient(
                        colors: [.clear, PulseColors.accent.opacity(0.8), PulseColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .shadow(color: PulseColors.accent.opacity(0.6), radius: 6)
                .shadow(color: PulseColors.accent.opacity(0.3), radius: 12)
        }
        .allowsHitTesting(false)
    }

    private func waveGradientColors(steps: [WorkflowStep]) -> [Color] {
        if steps.isEmpty { return [colors.textMuted] }
        return steps.map { StepTheme.theme(for: $0.step).color }
    }

    // MARK: - Helpers

    private func navigateToStep(_ step: WorkflowStep) {
        let routeMap: [String: AppRoute] = [
            "liveReadiness": .liveReadiness,
            "signalCenter": .signalCenter,
            "strategyWorkspace": .strategyWorkspace,
            "structureMatrix": .structureMatrix,
            "backtestSimulation": .backtestSimulation,
            "riskCenter": .riskCenter,
            "executionCenter": .executionCenter,
            "growthReview": .growthReview,
            "strategyOptimization": .strategyOptimization,
        ]
        if let route = routeMap[step.jumpTarget] {
            appState.selectedRoute = route
        }
    }

    private func statusBadge(_ state: String) -> some View {
        let label: String
        let color: Color
        switch state {
        case "ready": label = L10n.zh("就绪", en: "Ready"); color = PulseColors.accent
        case "attention": label = L10n.zh("需关注", en: "Attention"); color = PulseColors.amber
        case "blocked": label = L10n.zh("阻塞", en: "Blocked"); color = PulseColors.danger
        case "completed": label = L10n.zh("完成", en: "Done"); color = PulseColors.accent
        default: label = L10n.zh("未开始", en: "Idle"); color = colors.textMuted
        }
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.6), radius: 3)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(color.opacity(0.2), lineWidth: 0.5))
        )
    }

    private var placeholderCard: some View {
        RoundedRectangle(cornerRadius: PulseRadii.sm)
            .fill(colors.cardBackground.opacity(0.3))
            .frame(width: cardWidth, height: 90)
    }
}

// MARK: - Sinusoidal Wave Path (weaves through card top/bottom alternately)

private struct WavePath: Shape {
    let stepCount: Int
    let cardWidth: CGFloat
    let spacing: CGFloat
    let amplitude: CGFloat
    let centerY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard stepCount > 1 else { return path }

        let step = cardWidth + spacing
        let halfCard = cardWidth / 2

        // Anchor points alternate: odd cards at top, even cards at bottom
        let points = (0..<stepCount).map { i in
            let x = halfCard + CGFloat(i) * step
            let y = i.isMultiple(of: 2) ? centerY - amplitude : centerY + amplitude
            return CGPoint(x: x, y: y)
        }

        path.move(to: points[0])

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            // S-curve: control points push the curve beyond the endpoints
            let cpOffset = amplitude * 0.6
            let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) * 0.4,
                              y: p0.y + (p0.y < centerY ? cpOffset : -cpOffset))
            let cp2 = CGPoint(x: p0.x + (p1.x - p0.x) * 0.6,
                              y: p1.y + (p1.y < centerY ? cpOffset : -cpOffset))
            path.addCurve(to: p1, control1: cp1, control2: cp2)
        }

        return path
    }
}

// MARK: - Neon Step Card

private struct NeonStepCard: View {
    @Environment(PulseColors.self) private var colors
    let step: WorkflowStep
    let index: Int
    let theme: StepTheme
    let isCurrentStep: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.color.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.color.opacity(isCurrentStep ? 0.5 : 0.2), lineWidth: isCurrentStep ? 1.5 : 0.5)
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: theme.color.opacity(isCurrentStep ? 0.4 : 0.1), radius: isCurrentStep ? 8 : 2)

                    Image(systemName: theme.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.color)
                        .shadow(color: theme.color.opacity(0.5), radius: 3)
                }

                VStack(spacing: 2) {
                    Text(step.title)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)

                    stepStatusLabel
                }
            }
            .frame(width: 76, height: 90)
        }
        .buttonStyle(.plain)
    }

    private var stepStatusLabel: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(statusColor)
                .frame(width: 4, height: 4)
                .shadow(color: statusColor.opacity(0.6), radius: 2)
            Text(statusText)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(statusColor.opacity(0.8))
        }
    }

    private var statusText: String {
        switch step.status {
        case "passed": "已通过"
        case "running": "运行中"
        case "attention": "需关注"
        case "blocked": "已阻塞"
        case "ready": "就绪"
        case "not_started": "未开始"
        default: step.status
        }
    }

    private var statusColor: Color {
        switch step.status {
        case "passed": PulseColors.accent
        case "running": PulseColors.cyan
        case "attention": PulseColors.amber
        case "blocked", "failed": PulseColors.danger
        case "ready": PulseColors.cyan
        default: colors.textMuted
        }
    }
}
