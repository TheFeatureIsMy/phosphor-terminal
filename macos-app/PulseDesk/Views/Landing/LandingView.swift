// LandingView.swift — Krypton Pro 启动页
// 简洁设计：Logo + 标题 + 特性亮点 + CTA

import SwiftUI

struct LandingView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @State private var showContent = false
    @State private var showCTA = false

    var body: some View {
        ZStack {
            BackgroundLayersView()
            ParticleFieldView().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + 标题
                VStack(spacing: PulseSpacing.lg) {
                    ZStack {
                        RadialGradient(
                            colors: [PulseColors.accent.opacity(0.15), .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                        .frame(width: 240, height: 240).blur(radius: 40)

                        KryptonLogoView()
                            .frame(width: 72, height: 72)
                            .shadow(color: PulseColors.accent.opacity(0.45), radius: 16)
                    }

                    if showContent {
                        VStack(spacing: PulseSpacing.sm) {
                            BlurTextReveal(text: "Krypton", delay: 0.2, duration: 0.8)
                                .font(.system(size: 48, weight: .bold))
                            HStack(spacing: 4) {
                                DecryptedText(text: "PRO", triggerOnAppear: true, speed: 0.03, revealDirection: .start)
                                    .font(PulseFonts.monoLabel).foregroundStyle(PulseColors.accent).tracking(2)
                                DecryptedText(text: "AI QUANT TRADING TERMINAL", triggerOnAppear: true, speed: 0.03, revealDirection: .start)
                                    .font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted).tracking(3)
                            }
                        }
                    }

                    // 特性亮点 — 简洁 pill
                    if showContent {
                        HStack(spacing: PulseSpacing.sm) {
                            FeaturePill(icon: "brain.head.profile", label: "多智能体", color: PulseColors.cyan)
                            FeaturePill(icon: "chart.bar.fill", label: "量化策略", color: PulseColors.accent)
                            FeaturePill(icon: "shield.checkered", label: "实时风控", color: PulseColors.purple)
                        }
                    }
                }

                Spacer().frame(height: 48)

                // CTA
                if showCTA {
                    VStack(spacing: PulseSpacing.md) {
                        ProofAlphaButton(title: "进入 Krypton Pro") {
                            withAnimation(PulseAnimation.springDefault) { appState.hasLaunched = true }
                        }

                        HStack(spacing: PulseSpacing.xs) {
                            BadgeDot(color: PulseColors.success, label: "v1.0.0", size: .small)
                            BadgeDot(color: PulseColors.cyan, label: "macOS 26", size: .small)
                            BadgeDot(color: PulseColors.purple, label: "DEMO", size: .small)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showCTA)
                }

                Spacer().frame(height: 80)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { showContent = true } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showCTA = true } }
        }
    }
}

// MARK: - 特性 Pill
struct FeaturePill: View {
    let icon: String; let label: String; let color: Color
    @Environment(PulseColors.self) private var colors
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(
            Capsule()
                .fill(colors.surface.opacity(0.4))
        )
        .overlay(Capsule().stroke(colors.border, lineWidth: 0.5))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear { withAnimation(PulseAnimation.springDefault.delay(0.5)) { appeared = true } }
    }
}

// MARK: - 粒子场 (TimelineView)
struct ParticleFieldView: View {
    @State private var baseParticles: [BaseParticle] = []
    struct BaseParticle { var x: CGFloat; var y: CGFloat; var size: CGFloat; var opacity: Double; var speed: Double; var color: Color }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for p in baseParticles {
                    var px = p.x + sin((p.y + t * p.speed) * 10) * 0.03
                    var py = p.y - t * p.speed * 0.5
                    py = py.truncatingRemainder(dividingBy: 1.0); if py < 0 { py += 1.0 }
                    px = px.truncatingRemainder(dividingBy: 1.0); if px < 0 { px += 1.0 }
                    let rect = CGRect(x: px * size.width, y: py * size.height, width: p.size, height: p.size)
                    let glowRect = rect.insetBy(dx: -p.size, dy: -p.size)
                    context.fill(Path(ellipseIn: glowRect), with: .color(p.color.opacity(p.opacity * 0.3)))
                    context.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(p.opacity)))
                }
            }
        }
        .onAppear { generateParticles() }
    }

    private func generateParticles() {
        let colors: [Color] = [PulseColors.accent, PulseColors.cyan, PulseColors.purple]
        baseParticles = (0..<60).map { _ in
            BaseParticle(x: .random(in: 0...1), y: .random(in: 0...1), size: .random(in: 1.5...3.5), opacity: .random(in: 0.06...0.25), speed: .random(in: 0.0002...0.001), color: colors.randomElement() ?? PulseColors.accent)
        }
    }
}
