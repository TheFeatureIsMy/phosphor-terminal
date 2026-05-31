// AIStudioView.swift — AI 工作室
// 6 个 AI 子功能的标签容器，使用真实子视图

import SwiftUI

struct AIStudioView: View {
    @Environment(PulseColors.self) private var colors
    @State private var selectedTab = 0

    private let tabs = [
        ("doc.text.magnifyingglass", "RAG 实验室"),
        ("chart.line.uptrend.xyaxis", "价格预测"),
        ("chart.bar", "因子研究"),
        ("brain", "FreqAI"),
        ("person.3", "AI 研究"),
        ("antenna.radiowaves.left.and.right", "信号中心"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation(PulseAnimation.easeOutFast) { selectedTab = index }
                        } label: {
                            HStack(spacing: PulseSpacing.xxs) {
                                Image(systemName: tab.0)
                                    .font(.system(size: 12))
                                Text(tab.1)
                                    .font(selectedTab == index ? PulseFonts.bodyMedium : PulseFonts.body)
                            }
                            .foregroundStyle(selectedTab == index ? PulseColors.accent : colors.textSecondary)
                            .padding(.horizontal, PulseSpacing.md)
                            .padding(.vertical, PulseSpacing.sm)
                            .background(
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(selectedTab == index ? PulseColors.accent : .clear)
                                        .frame(height: 2)
                                }
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pressEffect(scale: 0.95)
                    }
                }
                .padding(.horizontal, PulseSpacing.lg)
            }

            Divider().foregroundStyle(colors.border)

            // 内容 — 使用真实子视图
            Group {
                switch selectedTab {
                case 0: RAGLabSectionView()
                case 1: ForecastSectionView()
                case 2: FactorResearchSectionView()
                case 3: FreqAISectionView()
                case 4: ResearchSectionView()
                case 5: SignalsSectionView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
