// EquityCurveChart.swift — 权益曲线图表
// Swift Charts AreaMark + LineMark，支持时间范围切换和交互式 tooltip

import SwiftUI
import Charts

struct EquityCurveChart: View {
    @Environment(PulseColors.self) private var colors
    let points: [EquityPoint]
    @State private var selectedRange = 90
    @State private var hoveredPoint: EquityPoint?

    private let ranges = [7, 30, 90]

    private var filteredPoints: [EquityPoint] {
        Array(points.suffix(selectedRange))
    }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // 标题 + 范围选择器
                HStack {
                    Text("权益曲线")
                        .font(PulseFonts.displaySubheading)
                        .foregroundStyle(colors.textPrimary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(ranges, id: \.self) { range in
                            Button("\(range)D") {
                                withAnimation(PulseAnimation.easeOutFast) {
                                    selectedRange = range
                                }
                            }
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(selectedRange == range ? colors.textPrimary : colors.textSecondary)
                            .padding(.horizontal, PulseSpacing.xs)
                            .padding(.vertical, PulseSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PulseRadii.sm)
                                    .fill(selectedRange == range ? PulseColors.accent : .clear)
                            )
                            .buttonStyle(.plain)
                            .pressEffect()
                        }
                    }
                }

                // 图表
                Chart {
                    ForEach(filteredPoints) { point in
                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value("价值", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colors.profit.opacity(0.2), colors.profit.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("价值", point.value)
                        )
                        .foregroundStyle(colors.profit)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }

                    // 悬停指示线
                    if let hoveredPoint {
                        RuleMark(x: .value("日期", hoveredPoint.date))
                            .foregroundStyle(colors.textMuted.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        PointMark(
                            x: .value("日期", hoveredPoint.date),
                            y: .value("价值", hoveredPoint.value)
                        )
                        .foregroundStyle(colors.profit)
                        .symbolSize(60)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange <= 30 ? 5 : 15)) { value in
                        AxisValueLabel {
                            if let dateStr = value.as(String.self) {
                                Text(String(dateStr.suffix(5)))
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textMuted)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(colors.border)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "$%.0fk", v / 1000))
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(colors.textMuted)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(colors.border)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let date: String = proxy.value(atX: location.x) {
                                        // TODO: use index-based lookup for reliability
                                        if let idx = filteredPoints.firstIndex(where: { $0.date == date }) {
                                            hoveredPoint = filteredPoints[idx]
                                        }
                                    }
                                case .ended:
                                    hoveredPoint = nil
                                }
                            }
                    }
                }
                .frame(height: 260)
                .animation(PulseAnimation.easeOutMedium, value: selectedRange)
                .overlay(alignment: .top) {
                    if let point = hoveredPoint {
                        Text("\(point.date): \(String(format: "$%.0f", point.value))")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceElevated))
                            .transition(.opacity)
                    }
                }
            }
        }
    }
}
