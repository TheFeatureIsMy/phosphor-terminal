// AnimatedEffects.swift — ProofAlpha 高级动效组件
// DecryptedText, CountUp, BlurTextReveal, ParticleField

import SwiftUI

// MARK: - DecryptedText — 密码破译式文字揭示
struct DecryptedText: View {
    @Environment(PulseColors.self) private var colors
    let text: String
    var triggerOnAppear: Bool = true
    var speed: Double = 0.04
    var revealDirection: RevealDirection = .start

    enum RevealDirection { case start, end, center }

    @State private var revealed: Set<Int> = []
    @State private var hasStarted = false

    private let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*")

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(displayChar(at: index, original: char))
                    .font(PulseFonts.body)
                    .foregroundStyle(revealed.contains(index) ? colors.textPrimary : colors.textMuted)
                    .animation(nil, value: revealed.contains(index))
            }
        }
        .onAppear {
            guard triggerOnAppear, !hasStarted else { return }
            hasStarted = true
            startReveal()
        }
    }

    private func displayChar(at index: Int, original: Character) -> String {
        if original == " " { return " " }
        if revealed.contains(index) { return String(original) }
        return String(chars.randomElement() ?? "?")
    }

    private func startReveal() {
        let indices: [Int]
        switch revealDirection {
        case .start:
            indices = Array(0..<text.count)
        case .end:
            indices = Array((0..<text.count).reversed())
        case .center:
            let mid = text.count / 2
            indices = (0..<text.count).sorted { abs($0 - mid) < abs($1 - mid) }
        }

        for (order, index) in indices.enumerated() {
            guard text[text.index(text.startIndex, offsetBy: index)] != " " else {
                revealed.insert(index)
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(order) * speed) {
                // Scramble effect - show random chars before revealing
                revealed.insert(index)
            }
        }
    }
}

// MARK: - CountUp — 弹簧数字跳动
struct CountUp: View {
    @Environment(PulseColors.self) private var colors
    let value: Double
    var format: String = "%.2f"
    var prefix: String = ""
    var suffix: String = ""
    var duration: Double = 1.5

    @State private var displayValue: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        Text("\(prefix)\(String(format: format, displayValue))\(suffix)")
            .font(PulseFonts.tabularLarge)
            .foregroundStyle(colors.textPrimary)
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                withAnimation(.spring(response: duration, dampingFraction: 0.7)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - BlurTextReveal — 模糊文字揭示
struct BlurTextReveal: View {
    @Environment(PulseColors.self) private var colors
    let text: String
    var delay: Double = 0
    var duration: Double = 0.5

    @State private var opacity: Double = 0
    @State private var blur: Double = 10
    @State private var offsetY: Double = -20

    var body: some View {
        Text(text)
            .font(PulseFonts.displayTitle)
            .foregroundStyle(colors.textPrimary)
            .blur(radius: blur)
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeOut(duration: duration)
                    .delay(delay)
                ) {
                    opacity = 1
                    blur = 0
                    offsetY = 0
                }
            }
    }
}

// MARK: - TypewriterText — 打字机效果 (TimelineView 驱动)
struct TypewriterText: View {
    @Environment(PulseColors.self) private var colors
    let text: String
    var speed: Double = 0.05
    var cursor: Bool = true

    @State private var startTime: Date?
    @State private var showCursor = true

    var body: some View {
        TimelineView(.animation(minimumInterval: speed)) { timeline in
            let elapsed = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            let count = min(Int(elapsed / speed), text.count)
            let isTyping = count < text.count

            HStack(spacing: 0) {
                Text(String(text.prefix(count)))
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)

                if cursor && showCursor {
                    Rectangle()
                        .fill(PulseColors.accent)
                        .frame(width: 8, height: 16)
                        .opacity(isTyping ? 1 : (Int(elapsed * 2) % 2 == 0 ? 1 : 0))
                }
            }
            .onChange(of: count) { _, newCount in
                if newCount >= text.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCursor = false }
                    }
                }
            }
        }
        .onAppear {
            startTime = Date()
            showCursor = true
        }
    }
}

// MARK: - PulseRing — 脉冲光环
struct PulseRing: View {
    var color: Color = PulseColors.accent
    var size: CGFloat = 60
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: size, height: size)
                    .scaleEffect(animate ? 2.0 : 1.0)
                    .opacity(animate ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.6),
                        value: animate
                    )
            }

            Circle()
                .fill(color)
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: color.opacity(0.5), radius: 8)
        }
        .onAppear { animate = true }
    }
}

// MARK: - ScanLine — 扫描线动画
struct ScanLine: View {
    var color: Color = PulseColors.accent.opacity(0.3)
    var height: CGFloat = 2

    @State private var offset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            color
                .frame(height: height)
                .blur(radius: 2)
                .offset(y: offset * geo.size.height)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 3.0)
                .repeatForever(autoreverses: false)
            ) {
                offset = 1
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - DataFlowLine — 数据流线条
struct DataFlowLine: View {
    var color: Color = PulseColors.accent.opacity(0.4)

    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [8, 40],
                    dashPhase: phase
                )
            )
        }
        .frame(height: 2)
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                phase = -96
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - GlowBorder — 发光边框
struct GlowBorder: View {
    var color: Color = PulseColors.accent
    var cornerRadius: CGFloat = PulseRadii.card

    @State private var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                AngularGradient(
                    colors: [
                        color.opacity(0),
                        color.opacity(0.6),
                        color.opacity(0),
                    ],
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: 1
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}
