// SignalTableComponents.swift — 信号中枢 Protocol 表格组件
// 过滤卡 / 表头 / 可展开表格行 / 冲突卡。对照 signal-03-protocol.html。

import SwiftUI

// MARK: - 币种图标色
func signalSymbolColor(_ symbol: String) -> Color {
    let base = symbol.split(separator: "/").first.map(String.init) ?? symbol
    switch base.uppercased() {
    case "BTC": return Color(hex: "F7931A")
    case "ETH": return Color(hex: "627EEA")
    case "SOL": return Color(hex: "14F195")
    case "AVAX": return Color(hex: "E84142")
    case "LINK": return Color(hex: "2A5ADA")
    case "PEPE": return Color(hex: "4CAF50")
    case "DOGE": return Color(hex: "C2A633")
    case "ARB": return Color(hex: "28A0F0")
    default: return PulseColors.accent
    }
}
func signalSymbolInitials(_ symbol: String) -> String {
    let base = symbol.split(separator: "/").first.map(String.init) ?? symbol
    return String(base.prefix(2)).uppercased()
}

// MARK: - 过滤卡
struct SignalFilterCard: View {
    @Bindable var viewModel: SignalCenterViewModel
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterGroup(L10n.Signals.source,
                options: [L10n.Signals.sourceAll, L10n.Signals.sourceAIResearch, L10n.Signals.sourceTradingAgents, L10n.Signals.sourceManual, L10n.Signals.sourceCanvas],
                selected: viewModel.filterSource ?? L10n.Signals.sourceAll) {
                viewModel.filterSource = $0 == L10n.Signals.sourceAll ? nil : $0
            }
            filterGroup(L10n.Signals.symbol,
                options: [L10n.Signals.symbolAll, "BTC", "ETH", "SOL", "PEPE"],
                selected: viewModel.filterSymbol ?? L10n.Signals.symbolAll) {
                viewModel.filterSymbol = $0 == L10n.Signals.symbolAll ? nil : $0
            }
            filterGroup(L10n.Signals.direction,
                options: [L10n.Signals.directionAll, "Long", "Short", "Hold"],
                selected: viewModel.filterDirection ?? L10n.Signals.directionAll) {
                viewModel.filterDirection = $0 == L10n.Signals.directionAll ? nil : $0
            }
            filterGroup(L10n.Signals.status,
                options: [L10n.Signals.statusAll, "active", "pending", "rejected"],
                selected: viewModel.filterStatus ?? L10n.Signals.statusAll) {
                viewModel.filterStatus = $0 == L10n.Signals.statusAll ? nil : $0
            }
            HStack(spacing: 8) {
                Text(L10n.Signals.sort).font(PulseFonts.body(13, .semibold)).foregroundStyle(colors.textSecondary)
                ForEach(SignalCenterViewModel.SortOrder.allCases, id: \.self) { order in
                    filterChip(order.label, selected: viewModel.sortOrder == order) {
                        viewModel.sortOrder = order
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
    }

    private func filterGroup(_ label: String, options: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(PulseFonts.body(13, .semibold)).foregroundStyle(colors.textSecondary)
                .frame(width: 44, alignment: .leading)
            ForEach(options, id: \.self) { opt in
                filterChip(opt, selected: selected == opt) { onSelect(opt) }
            }
            Spacer()
        }
    }

    private func filterChip(_ text: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Text(text)
            .font(PulseFonts.body(13, selected ? .semibold : .regular))
            .foregroundStyle(selected ? PulseColors.accent : colors.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? PulseColors.accentSoft : colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? PulseColors.accent.opacity(0.4) : Color.clear, lineWidth: 1))
            .onTapGesture(perform: onTap)
    }
}

// MARK: - 表头
struct SignalTableHeader: View {
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(spacing: 0) {
            headerCell(L10n.Signals.colSymbolTF, .leading, width: 200)
            headerCell(L10n.Signals.colDirection, .center, width: 74)
            headerCell(L10n.Signals.colSource, .leading, width: 120)
            headerCell(L10n.Signals.colConfidence, .leading, width: 130)
            headerCell(L10n.Signals.colScore, .center, width: 70)
            headerCell(L10n.Signals.colRisk, .center, width: 66)
            headerCell(L10n.Signals.colExpiry, .trailing, width: 90)
            headerCell(L10n.Signals.colStatus, .trailing, width: 80)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(colors.border).frame(height: 1) }
    }
    private func headerCell(_ t: String, _ align: Alignment, width: CGFloat) -> some View {
        Text(t)
            .font(PulseFonts.body(11.5, .semibold))
            .foregroundStyle(colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.4)
            .frame(width: width, alignment: align)
    }
}

// MARK: - 方向 pill
struct SignalDirectionPill: View {
    let direction: String
    var body: some View {
        let d = direction.lowercased()
        let label = d == "long" ? "LONG" : d == "short" ? "SHORT" : d.uppercased()
        let fg = d == "long" ? PulseColors.bullish : d == "short" ? PulseColors.bearish : PulseColors.warning
        let bg = d == "long" ? PulseColors.bullishSoft : d == "short" ? PulseColors.bearishSoft : PulseColors.warningSoft
        Text(label)
            .font(PulseFonts.body(11, .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(bg))
    }
}

// MARK: - 风险 chip
struct SignalRiskChip: View {
    let risk: String
    var body: some View {
        let r = risk.lowercased()
        let (label, fg, bg): (String, Color, Color) = {
            switch r {
            case "low": return (L10n.Signals.riskLow, PulseColors.bullish, PulseColors.bullishSoft)
            case "medium": return (L10n.Signals.riskMedium, Color(hex: "B4740B"), PulseColors.warningSoft)
            case "high": return (L10n.Signals.riskHigh, PulseColors.bearish, PulseColors.bearishSoft)
            default: return (L10n.Signals.riskCritical, PulseColors.bearish, PulseColors.bearishSoft)
            }
        }()
        Text(label)
            .font(PulseFonts.body(11, .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(bg))
    }
}

// MARK: - 置信度条
struct SignalConfidenceBar: View {
    let confidence: Double
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.surface).frame(height: 6)
                    Capsule().fill(PulseColors.accent)
                        .frame(width: geo.size.width * min(max(confidence, 0), 1), height: 6)
                }
            }
            .frame(width: 64, height: 6)
            Text(String(format: "%.2f", confidence))
                .font(PulseFonts.body(12.5, .semibold))
                .foregroundStyle(colors.textPrimary)
                .monospacedDigit()
        }
    }
}

// MARK: - 表格行(可展开)
struct SignalTableRow: View {
    let signal: SignalV2
    let expanded: Bool
    let onToggle: () -> Void
    let onPublish: () -> Void
    let onArchive: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // 摘要行
            HStack(spacing: 0) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 9).fill(signalSymbolColor(signal.symbol))
                        .frame(width: 30, height: 30)
                        .overlay(Text(signalSymbolInitials(signal.symbol))
                            .font(PulseFonts.display(12, .bold)).foregroundStyle(.white))
                    Text(signal.symbol).font(PulseFonts.body(14, .semibold)).foregroundStyle(colors.textPrimary)
                }
                .frame(width: 200, alignment: .leading)
                SignalDirectionPill(direction: signal.direction).frame(width: 74, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.sourceType).font(PulseFonts.body(13)).foregroundStyle(colors.textPrimary)
                    Text(signal.sourceType.replacingOccurrences(of: "_", with: " "))
                        .font(PulseFonts.body(11)).foregroundStyle(colors.textMuted)
                }
                .frame(width: 120, alignment: .leading)
                SignalConfidenceBar(confidence: signal.confidence).frame(width: 130, alignment: .leading)
                Text(String(format: "%.1f", signal.score ?? 0))
                    .font(PulseFonts.body(13, .semibold)).foregroundStyle(colors.textPrimary).monospacedDigit()
                    .frame(width: 70, alignment: .center)
                SignalRiskChip(risk: signal.riskLevel).frame(width: 66, alignment: .center)
                Text(shortExpiry(signal.expiresAt))
                    .font(PulseFonts.body(12)).foregroundStyle(colors.textSecondary).monospacedDigit()
                    .frame(width: 90, alignment: .trailing)
                Text(signal.status)
                    .font(PulseFonts.body(11.5, .semibold)).foregroundStyle(statusColor)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            // 展开详情
            if expanded {
                Divider().overlay(colors.border)
                SignalExpandedDetail(signal: signal, onPublish: onPublish, onArchive: onArchive)
                    .padding(.vertical, 16)
            }
        }
        .background(expanded ? colors.surface.opacity(0.5) : Color.clear)
    }

    private var statusColor: Color {
        switch signal.status.lowercased() {
        case "active": return PulseColors.bullish
        case "pending": return PulseColors.warning
        case "rejected", "archived": return colors.textMuted
        default: return colors.textSecondary
        }
    }
    private func shortExpiry(_ iso: String) -> String {
        String(iso.prefix(10))
    }
}

// MARK: - 展开详情
struct SignalExpandedDetail: View {
    let signal: SignalV2
    let onPublish: () -> Void
    let onArchive: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 四问信息网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                infoBlock(L10n.Signals.detSource, signal.sourceType)
                infoBlock(L10n.Signals.detTarget, signal.symbol)
                infoBlock(L10n.Signals.detDirection, directionLabel(signal.direction))
                infoBlock(L10n.Signals.detConfidence,
                          String(format: L10n.zh("置信 %.2f · 评分 %.1f · %@风险", en: "conf %.2f · score %.1f · %@ risk"),
                                 signal.confidence, signal.score ?? 0, signal.riskLevel))
            }

            // 为什么
            if let reasoning = signal.reasoning, !reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Signals.detReasoning).font(PulseFonts.body(12, .semibold)).foregroundStyle(colors.textSecondary)
                    Text(reasoning).font(PulseFonts.body(13)).foregroundStyle(colors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
            }

            // 何时有效
            infoBlock(L10n.Signals.detValidity, "\(L10n.zh("截至", en: "until")) \(signal.expiresAt.prefix(10)) · \(signal.status)")

            // 操作按钮
            HStack(spacing: 10) {
                detailButton(L10n.Signals.actionPublish, primary: true, action: onPublish)
                detailButton(L10n.Signals.actionDryrun + L10n.Signals.comingSoon, primary: false, action: {})
                detailButton(L10n.Signals.actionDraft + L10n.Signals.comingSoon, primary: false, action: {})
                detailButton(L10n.Signals.actionArchive, primary: false, action: onArchive)
                Spacer()
            }
        }
        .padding(.leading, 4)
    }

    private func infoBlock(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(q).font(PulseFonts.body(12, .semibold)).foregroundStyle(colors.textSecondary)
            Text(a).font(PulseFonts.body(13)).foregroundStyle(colors.textPrimary)
        }
    }

    private func detailButton(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(PulseFonts.body(13, .semibold))
            .foregroundStyle(primary ? .white : colors.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(primary ? PulseColors.accent : colors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primary ? Color.clear : colors.border, lineWidth: 1))
            .onTapGesture(perform: action)
    }

    private func directionLabel(_ d: String) -> String {
        switch d.lowercased() {
        case "long": return L10n.Signals.dirLong
        case "short": return L10n.Signals.dirShort
        case "hold": return L10n.Signals.dirHold
        default: return d
        }
    }
}

// MARK: - 冲突卡
struct SignalConflictCard: View {
    let group: SignalCenterViewModel.ConflictGroup
    let onAdjudicate: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(group.symbol).font(PulseFonts.body(15, .bold)).foregroundStyle(colors.textPrimary)
                Text(L10n.Signals.conflictDirection)
                    .font(PulseFonts.body(11, .semibold)).foregroundStyle(PulseColors.warning)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(PulseColors.warningSoft))
            }

            // 多空对立行
            HStack(spacing: 10) {
                sideLine(group.longs.first, long: true)
                Text(L10n.Signals.conflictVS).font(PulseFonts.body(12, .bold)).foregroundStyle(colors.textMuted)
                sideLine(group.shorts.first, long: false)
            }

            Text(L10n.Signals.conflictHint)
                .font(PulseFonts.body(12.5)).foregroundStyle(colors.textSecondary)

            Text(L10n.Signals.conflictAdjudicate)
                .font(PulseFonts.body(13, .semibold)).foregroundStyle(PulseColors.accent)
                .onTapGesture(perform: onAdjudicate)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: PulseRadii.card).fill(colors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(colors.border, lineWidth: 1))
    }

    private func sideLine(_ s: SignalV2?, long: Bool) -> some View {
        let color = long ? PulseColors.bullish : PulseColors.bearish
        return HStack(spacing: 6) {
            SignalDirectionPill(direction: long ? "long" : "short")
            Text(s?.sourceType ?? "—").font(PulseFonts.body(12.5)).foregroundStyle(colors.textSecondary)
            Text(String(format: "%.2f", s?.confidence ?? 0))
                .font(PulseFonts.body(13, .semibold)).foregroundStyle(color).monospacedDigit()
        }
    }
}
