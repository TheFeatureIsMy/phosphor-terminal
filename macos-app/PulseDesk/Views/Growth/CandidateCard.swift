// CandidateCard.swift — 候选策略卡片
// ProofAlphaCard(.balanced): 置信度 + 状态 + DSL 预览 + 操作按钮

import SwiftUI

struct CandidateCard: View {
    @Environment(PulseColors.self) private var colors
    let candidate: StrategyCandidate
    var onBacktest: (() -> Void)?
    var onConfirm: (() -> Void)?

    var body: some View {
        ProofAlphaCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Header: name + status badge
                HStack {
                    Text(candidateName)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    BadgeDot(
                        color: statusColor,
                        label: statusLabel,
                        size: .small
                    )
                }

                // Confidence bar (0-100%)
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack {
                        Text("置信度")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Spacer()
                        Text(String(format: "%.0f%%", confidenceValue * 100))
                            .font(PulseFonts.tabular)
                            .foregroundStyle(confidenceColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors.surface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(confidenceColor)
                                .frame(width: geo.size.width * confidenceValue, height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                // DSL preview (first 3 lines in monospace)
                Text(dslPreview)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(3)
                    .padding(PulseSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface)
                    )

                // Action buttons row
                if candidate.status != "confirmed" && candidate.status != "rejected" {
                    HStack(spacing: PulseSpacing.sm) {
                        Spacer()
                        ProofAlphaButton(title: "回测", action: { onBacktest?() }, style: .ghost)
                        ProofAlphaButton(title: "确认", action: { onConfirm?() })
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var confidenceValue: Double {
        candidate.confidence ?? 0
    }

    private var confidenceColor: Color {
        if confidenceValue >= 0.7 { return PulseColors.success }
        if confidenceValue >= 0.4 { return PulseColors.amber }
        return PulseColors.danger
    }

    private var candidateName: String {
        guard let dsl = candidate.dsl, let dict = dsl.value as? [String: Any],
              let name = dict["name"] as? String else {
            return "未命名候选"
        }
        return name
    }

    private var dslPreview: String {
        guard let dsl = candidate.dsl, let dict = dsl.value as? [String: Any] else {
            return "// 暂无 DSL 数据"
        }
        var lines: [String] = []
        if let name = dict["name"] as? String { lines.append("name: \(name)") }
        if let symbol = dict["symbol"] as? String { lines.append("symbol: \(symbol)") }
        if let source = dict["source_type"] as? String { lines.append("source: \(source)") }
        if let wr = dict["backtest_win_rate"] as? Double { lines.append("win_rate: \(String(format: "%.2f", wr))") }
        if let sr = dict["backtest_sharpe"] as? Double { lines.append("sharpe: \(String(format: "%.2f", sr))") }
        if let reason = dict["reasoning"] as? String { lines.append("// \(reason)") }
        return lines.prefix(3).joined(separator: "\n")
    }

    private var statusLabel: String {
        switch candidate.status {
        case "pending_review": return "待审核"
        case "confirmed": return "已确认"
        case "rejected": return "已拒绝"
        case "backtesting": return "回测中"
        default: return candidate.status
        }
    }

    private var statusColor: Color {
        switch candidate.status {
        case "pending_review": return PulseColors.amber
        case "confirmed": return PulseColors.success
        case "rejected": return PulseColors.danger
        case "backtesting": return PulseColors.info
        default: return PulseColors.info
        }
    }
}
