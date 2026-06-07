// ExecutionDetailSheet.swift — 执行详情弹窗
// 运行信息头 + 订单/事件 Tab 切换

import SwiftUI

struct ExecutionDetailSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    let run: StrategyRunV2
    let viewModel: ExecutionRecordsViewModel

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            sheetToolbar

            Divider()
                .foregroundStyle(colors.border)

            // 运行信息头
            runInfoHeader
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.md)

            Divider()
                .foregroundStyle(colors.border)

            // Tab 切换
            HStack(spacing: 0) {
                tabButton("订单", tag: 0, count: viewModel.runOrders.count)
                tabButton("事件", tag: 1, count: viewModel.runLedger.count)
                tabButton("追溯链", tag: 2, count: 6)
            }
            .padding(.horizontal, PulseSpacing.lg)

            Divider()
                .foregroundStyle(colors.border)

            // Tab 内容
            if viewModel.isLoadingDetail {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    switch selectedTab {
                    case 0: ordersContent
                    case 1: ledgerContent
                    case 2: traceabilityContent
                    default: EmptyView()
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
        .background(colors.background)
    }

    // MARK: - 顶部工具栏

    private var sheetToolbar: some View {
        HStack {
            TerminalLabel(text: "运行详情")
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.textMuted)
                    .frame(width: 24, height: 24)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - 运行信息头

    private var runInfoHeader: some View {
        KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.md) {
                // 模式
                VStack(alignment: .leading, spacing: 2) {
                    Text("模式")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    modeBadge(run.mode)
                }

                Divider()
                    .frame(height: 32)
                    .foregroundStyle(colors.border)

                // 状态
                VStack(alignment: .leading, spacing: 2) {
                    Text("状态")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    BadgeView(
                        text: statusLabel(run.status),
                        color: statusColor(run.status),
                        size: .small
                    )
                }

                Divider()
                    .frame(height: 32)
                    .foregroundStyle(colors.border)

                // 开始时间
                VStack(alignment: .leading, spacing: 2) {
                    Text("开始")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    Text(run.startedAt.map(formatDateTime) ?? "—")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                }

                Divider()
                    .frame(height: 32)
                    .foregroundStyle(colors.border)

                // 结束时间
                VStack(alignment: .leading, spacing: 2) {
                    Text("结束")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    Text(run.stoppedAt.map(formatDateTime) ?? "运行中")
                        .font(PulseFonts.caption)
                        .foregroundStyle(run.stoppedAt != nil ? colors.textPrimary : PulseColors.statusActive)
                }

                Divider()
                    .frame(height: 32)
                    .foregroundStyle(colors.border)

                // 策略版本
                VStack(alignment: .leading, spacing: 2) {
                    Text("版本 ID")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textMuted)
                    Text(String(run.strategyVersionId.prefix(8)) + "...")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Tab 按钮

    private func tabButton(_ title: String, tag: Int, count: Int) -> some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) { selectedTab = tag }
        } label: {
            HStack(spacing: PulseSpacing.xxs) {
                Text(title)
                    .font(selectedTab == tag ? PulseFonts.bodyMedium : PulseFonts.body)
                    .foregroundStyle(selectedTab == tag ? colors.textPrimary : colors.textSecondary)

                Text("\(count)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(selectedTab == tag ? PulseColors.accent : colors.textMuted)
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(selectedTab == tag ? PulseColors.accent : .clear)
                        .frame(height: 2)
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 订单内容

    private var ordersContent: some View {
        Group {
            if viewModel.runOrders.isEmpty {
                EmptyStateView(
                    icon: "arrow.left.arrow.right",
                    title: "暂无订单",
                    description: "该运行尚未产生交易订单"
                )
                .frame(height: 200)
            } else {
                KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.md) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 表头
                        ordersHeader

                        Divider()
                            .foregroundStyle(colors.border)

                        // 数据行
                        ForEach(Array(viewModel.runOrders.enumerated()), id: \.element.id) { index, order in
                            orderDataRow(order)
                                .staggeredAppearance(index: index, baseDelay: 0.02)
                                .background(index % 2 == 0 ? colors.surface.opacity(0.3) : Color.clear)
                        }
                    }
                }
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.md)
            }
        }
    }

    private var ordersHeader: some View {
        HStack(spacing: PulseSpacing.xs) {
            headerCell("交易对")
            headerCell("方向")
            headerCell("数量", alignment: .trailing)
            headerCell("价格", alignment: .trailing)
            headerCell("状态")
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    private func headerCell(_ title: String, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func orderDataRow(_ order: Order) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            Text(order.symbol)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(order.side == .buy ? "买入" : "卖出")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(order.side == .buy ? PulseColors.statusActive : PulseColors.loss)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.4f", order.quantity))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(formatPrice(order.filledPrice ?? order.price))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            BadgeView(text: order.status.label, color: order.status.color(colors), size: .small)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PulseSpacing.xs)
    }

    // MARK: - 事件（账本）内容

    private var ledgerContent: some View {
        Group {
            if viewModel.runLedger.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "暂无事件",
                    description: "该运行尚未产生账本事件"
                )
                .frame(height: 200)
            } else {
                VStack(spacing: PulseSpacing.xs) {
                    ForEach(Array(viewModel.runLedger.enumerated()), id: \.offset) { index, entry in
                        ledgerEventRow(entry, index: index)
                            .staggeredAppearance(index: index, baseDelay: 0.03)
                    }
                }
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.md)
            }
        }
    }

    private func ledgerEventRow(_ entry: AnyCodable, index: Int) -> some View {
        let dict = entry.value as? [String: Any] ?? [:]
        let entryType = dict["entry_type"] as? String ?? "unknown"
        let description = dict["description"] as? String ?? "—"
        let amount = dict["amount"] as? Double ?? 0
        let balance = dict["balance"] as? Double ?? 0
        let createdAt = dict["created_at"] as? String ?? ""

        return KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                // 时间线指示器
                VStack(spacing: 0) {
                    Circle()
                        .fill(ledgerEntryColor(entryType))
                        .frame(width: 8, height: 8)
                    if index < viewModel.runLedger.count - 1 {
                        Rectangle()
                            .fill(colors.border)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 12)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        BadgeView(text: entryType, color: ledgerEntryColor(entryType), size: .small)

                        Spacer()

                        Text(formatDateTime(createdAt))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }

                    Text(description)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: PulseSpacing.md) {
                        HStack(spacing: PulseSpacing.xxs) {
                            Text("金额:")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textMuted)
                            Text(String(format: "%+.2f", amount))
                                .font(PulseFonts.caption.weight(.medium))
                                .foregroundStyle(amount >= 0 ? PulseColors.statusActive : PulseColors.loss)
                        }

                        HStack(spacing: PulseSpacing.xxs) {
                            Text("余额:")
                                .font(PulseFonts.monoLabel)
                                .foregroundStyle(colors.textMuted)
                            Text(String(format: "%.2f", balance))
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func ledgerEntryColor(_ type: String) -> Color {
        switch type {
        case "trade_pnl": return PulseColors.statusActive
        case "fee": return PulseColors.warning
        case "funding": return PulseColors.info
        case "deposit": return PulseColors.purple
        case "withdrawal": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    // MARK: - 追溯链 (Traceability Chain)

    private var traceabilityContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(traceSteps.enumerated()), id: \.offset) { index, step in
                traceStepCard(step, isLast: index == traceSteps.count - 1)
                    .staggeredAppearance(index: index, baseDelay: 0.05)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    private func traceStepCard(_ step: TraceStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(step.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: step.color.opacity(0.4), radius: 4)

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [step.color.opacity(0.5), step.color.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 50)
                }
            }
            .frame(width: 16)

            // Step card
            KryptonCard(emphasis: .subtle, cardPadding: PulseSpacing.sm) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    HStack {
                        Image(systemName: step.icon)
                            .font(PulseFonts.caption)
                            .foregroundStyle(step.color)
                        Text(step.typeName)
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textPrimary)
                        Spacer()
                        BadgeDot(color: step.statusColor, label: step.status, size: .small)
                    }
                    HStack(spacing: PulseSpacing.sm) {
                        Text("ID: \(step.id)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                        Spacer()
                        Text(step.timestamp)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
        }
    }

    private var traceSteps: [TraceStep] {
        let baseTime = run.startedAt ?? "2026-06-05T10:00:00Z"
        return [
            TraceStep(
                typeName: "Signal",
                icon: "antenna.radiowaves.left.and.right",
                id: String(UUID().uuidString.prefix(8)),
                status: "已确认",
                statusColor: PulseColors.success,
                color: PulseColors.cyan,
                timestamp: formatDateTime(baseTime)
            ),
            TraceStep(
                typeName: "Agent",
                icon: "cpu",
                id: String(UUID().uuidString.prefix(8)),
                status: "已处理",
                statusColor: PulseColors.success,
                color: PulseColors.purple,
                timestamp: formatDateTime(baseTime)
            ),
            TraceStep(
                typeName: "Strategy",
                icon: "gearshape.2",
                id: String(run.strategyVersionId.prefix(8)),
                status: "已匹配",
                statusColor: PulseColors.success,
                color: PulseColors.accent,
                timestamp: formatDateTime(baseTime)
            ),
            TraceStep(
                typeName: "TradeIntent",
                icon: "arrow.right.circle",
                id: String(UUID().uuidString.prefix(8)),
                status: "已生成",
                statusColor: PulseColors.info,
                color: PulseColors.amber,
                timestamp: formatDateTime(baseTime)
            ),
            TraceStep(
                typeName: "RiskDecision",
                icon: "shield.checkered",
                id: String(UUID().uuidString.prefix(8)),
                status: "通过",
                statusColor: PulseColors.success,
                color: PulseColors.warning,
                timestamp: formatDateTime(baseTime)
            ),
            TraceStep(
                typeName: "Order",
                icon: "arrow.left.arrow.right",
                id: String(run.id.prefix(8)),
                status: run.status == "running" ? "执行中" : "已成交",
                statusColor: run.status == "running" ? PulseColors.statusActive : PulseColors.info,
                color: PulseColors.success,
                timestamp: formatDateTime(baseTime)
            ),
        ]
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
        case "running": return "运行中"
        case "completed": return "已完成"
        case "stopped": return "已停止"
        case "error": return "失败"
        case "starting": return "启动中"
        case "degraded": return "降级"
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

    private func formatDateTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm:ss"
        return df.string(from: date)
    }

    private func formatPrice(_ price: Double?) -> String {
        guard let p = price else { return "—" }
        return p >= 1000 ? String(format: "%.0f", p) : String(format: "%.2f", p)
    }
}


// MARK: - Trace Step Model

private struct TraceStep {
    let typeName: String
    let icon: String
    let id: String
    let status: String
    let statusColor: Color
    let color: Color
    let timestamp: String
}
