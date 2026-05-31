// LoadingView.swift — 骨架屏加载视图（多类型）

import SwiftUI

struct LoadingView: View {
    enum LoadingType {
        case dashboard  // KPI row + chart + two-column
        case listRow    // Single list row skeleton
        case detail     // Detail page skeleton
        case grid       // Grid skeleton
        case inline     // Thin progress bar for polling refreshes
    }

    @Environment(PulseColors.self) private var colors
    var type: LoadingType = .dashboard

    var body: some View {
        switch type {
        case .dashboard: dashboardSkeleton
        case .listRow:   listRowSkeleton
        case .detail:    detailSkeleton
        case .grid:      gridSkeleton
        case .inline:    inlineProgress
        }
    }

    // MARK: - Dashboard skeleton (4 KPI cards + chart + two-column)

    private var dashboardSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            HStack(spacing: PulseSpacing.xs) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface)
                        .frame(height: 88)
                        .shimmerWithDelay(phase: Double(i) * 0.15)
                }
            }
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface)
                .frame(height: 160)
                .shimmerWithDelay(phase: 0)
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 200)
                    .shimmerWithDelay(phase: 0.1)
                VStack(spacing: PulseSpacing.md) {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 100)
                        .shimmerWithDelay(phase: 0.2)
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 100)
                        .shimmerWithDelay(phase: 0.3)
                }
                .frame(width: 280)
            }
        }
    }

    // MARK: - List row skeleton

    private var listRowSkeleton: some View {
        HStack(spacing: PulseSpacing.sm) {
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 24, height: 24)
                .shimmerWithDelay(phase: 0)
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface).frame(width: 120, height: 14)
                    .shimmerWithDelay(phase: 0.05)
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface).frame(width: 80, height: 10)
                    .shimmerWithDelay(phase: 0.1)
            }
            Spacer()
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 60, height: 14)
                .shimmerWithDelay(phase: 0.15)
        }
        .padding(.vertical, PulseSpacing.sm)
        .padding(.horizontal, PulseSpacing.md)
    }

    // MARK: - Detail page skeleton

    private var detailSkeleton: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 200, height: 24)
                .shimmerWithDelay(phase: 0)
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(height: 120)
                .shimmerWithDelay(phase: 0.1)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface).frame(width: 100, height: 14)
                            .shimmerWithDelay(phase: Double(i) * 0.1)
                        Spacer()
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface).frame(width: 140, height: 14)
                            .shimmerWithDelay(phase: Double(i) * 0.1 + 0.05)
                    }
                }
            }
        }
    }

    // MARK: - Grid skeleton

    private var gridSkeleton: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: PulseSpacing.sm)], spacing: PulseSpacing.sm) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 100)
                    .shimmerWithDelay(phase: Double(i) * 0.1)
            }
        }
    }

    // MARK: - Inline progress bar (polling refresh)

    private var inlineProgress: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(PulseColors.accent.opacity(0.3))
                .frame(width: geo.size.width * 0.3, height: 2)
        }
        .frame(height: 2)
    }
}

// MARK: - Staggered shimmer helper

extension View {
    func shimmerWithDelay(phase: Double) -> some View {
        self.modifier(StaggeredShimmerModifier(phase: phase))
    }
}

struct StaggeredShimmerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    let phase: Double
    @State private var animPhase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: animPhase - 0.3),
                            .init(color: colors.surfaceHover, location: animPhase),
                            .init(color: .clear, location: animPhase + 0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + geometry.size.width * 2 * animPhase)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(phase)
                ) {
                    animPhase = 1.0
                }
            }
    }
}
