// CircuitBreakersView.swift — 熔断记录（War Room 风格重新设计）

import SwiftUI

struct CircuitBreakersView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: RiskCenterViewModel?
    @State private var selectedType: String? = nil
    @State private var selectedFilter: String = "unresolved"
    @State private var pulsePhase: CGFloat = 0
    @State private var resolveEventId: String?

    private struct BreakerTypeInfo {
        let label: String
        let labelEn: String
        let color: Color
        let icon: String
    }

    private let typeInfoMap: [String: BreakerTypeInfo] = [
        "emergency_stop": BreakerTypeInfo(label: "紧急停止", labelEn: "EMERGENCY STOP", color: PulseColors.StateColors.red, icon: "bolt.fill"),
        "kill_switch": BreakerTypeInfo(label: "Kill Switch", labelEn: "KILL SWITCH", color: PulseColors.StateColors.red, icon: "xmark.octagon.fill"),
        "daily_loss_lock": BreakerTypeInfo(label: "日亏损锁", labelEn: "DAILY LOSS LOCK", color: PulseColors.StateColors.orangeRed, icon: "chart.line.downtrend.xyaxis"),
        "weekly_loss_lock": BreakerTypeInfo(label: "周亏损锁", labelEn: "WEEKLY LOSS LOCK", color: PulseColors.StateColors.orangeRed, icon: "chart.line.downtrend.xyaxis"),
        "manual_force_close": BreakerTypeInfo(label: "手动平仓", labelEn: "MANUAL CLOSE", color: PulseColors.StateColors.yellow, icon: "hand.raised.fill"),
        "system_safe_mode": BreakerTypeInfo(label: "系统安全模式", labelEn: "SAFE MODE", color: PulseColors.StateColors.purple, icon: "shield.fill"),
    ]

    private var resolvedMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel?.circuitBreakers?.state,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    private var affectedRunCount: Int {
        viewModel?.circuitBreakers?.totalCount ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveWireStrip(mode: resolvedMode)
            EmergencyStopBar(
                mode: resolvedMode,
                affectedRuns: affectedRunCount,
                emergencyLocked: viewModel?.circuitBreakers?.state == "emergency_locked",
                onStop: { await viewModel?.emergencyStop() },
                onResume: { await viewModel?.emergencyResume() }
            )

            if let vm = viewModel {
                if vm.isLoading && vm.circuitBreakers == nil {
                    LoadingView(type: .detail)
                        .padding(PulseSpacing.lg)
                } else if let data = vm.circuitBreakers {
                    // Header + Filter
                    headerSection(vm, data: data)

                    Divider().foregroundStyle(colors.border)

                    ScrollView(.vertical, showsIndicators: false) {
                        let filtered = filteredRecords(data.records)
                        if filtered.isEmpty {
                            allClearState
                                .padding(.top, PulseSpacing.xl)
                        } else {
                            // Timeline layout
                            timelineLayout(filtered)
                                .padding(PulseSpacing.xl)
                        }

                    }
                    .id(settingsState.language)
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.zh("加载失败", en: "Load Failed"),
                        description: error,
                        primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.loadCircuitBreakers() } })
                    )
                    .padding(PulseSpacing.lg)
                } else {
                    EmptyStateView(
                        icon: "bolt.slash",
                        title: L10n.zh("暂无熔断数据", en: "No Breaker Data"),
                        description: L10n.zh("熔断系统尚未返回数据", en: "Circuit breaker system has not returned data")
                    )
                    .padding(PulseSpacing.lg)
                }
            }
        }
        .riskAtmosphericBackground(tint: overallStateColor)
        .task {
            let vm = RiskCenterViewModel(client: networkClient)
            viewModel = vm
            await vm.loadCircuitBreakers()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
        // Resolve confirm dialog
        .confirmDialog(
            isPresented: Binding(
                get: { resolveEventId != nil },
                set: { if !$0 { resolveEventId = nil } }
            ),
            title: L10n.Risk.confirmMarkResolved,
            message: L10n.zh("确认将此熔断事件标记为已解决？", en: "Mark this circuit breaker event as resolved?"),
            confirmLabel: L10n.Risk.markResolved,
            confirmStyle: .warning,
            onConfirm: {
                guard let id = resolveEventId else { return }
                Task { await viewModel?.resolveCircuitBreaker(eventId: id) }
                resolveEventId = nil
            }
        )
    }

    private var overallStateColor: Color {
        guard let data = viewModel?.circuitBreakers else { return PulseColors.accent }
        if data.records.isEmpty { return PulseColors.StateColors.green }
        if data.records.contains(where: { $0.type == "emergency_stop" || $0.type == "kill_switch" }) {
            return PulseColors.StateColors.red
        }
        return PulseColors.StateColors.orange
    }

    // MARK: - Header

    private func headerSection(_ vm: RiskCenterViewModel, data: CircuitBreakersBFFResponse) -> some View {
        VStack(spacing: PulseSpacing.sm) {
            HStack {
                TerminalLabel(text: L10n.zh("熔断记录", en: "CIRCUIT BREAKERS"))

                // Total count badge
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text("\(data.totalCount)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(data.totalCount > 0 ? PulseColors.StateColors.orange : colors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (data.totalCount > 0 ? PulseColors.StateColors.orange : colors.surface).opacity(0.12)
                )
                .clipShape(Capsule())

                Spacer()

                Button {
                    Task { await vm.loadCircuitBreakers() }
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text(L10n.zh("刷新", en: "Refresh"))
                            .font(PulseFonts.monoLabel)
                    }
                    .foregroundStyle(PulseColors.accent)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PulseSpacing.xs) {
                    filterChip(
                        label: L10n.zh("全部", en: "All"),
                        icon: "line.3.horizontal.decrease.circle",
                        isSelected: selectedFilter == "all" && selectedType == nil
                    ) {
                        selectedFilter = "all"
                        selectedType = nil
                    }

                    // Resolve status chips
                    filterChip(
                        label: L10n.Risk.unresolved,
                        icon: "circle.dotted",
                        color: PulseColors.StateColors.orange,
                        isSelected: selectedFilter == "unresolved" && selectedType == nil
                    ) {
                        selectedFilter = "unresolved"
                        selectedType = nil
                    }

                    filterChip(
                        label: L10n.Risk.resolved,
                        icon: "checkmark.circle",
                        color: PulseColors.StateColors.green,
                        isSelected: selectedFilter == "resolved" && selectedType == nil
                    ) {
                        selectedFilter = "resolved"
                        selectedType = nil
                    }

                    // Divider
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(colors.border)
                        .frame(width: 1, height: 20)

                    // Type chips
                    filterChip(
                        label: L10n.zh("紧急停止", en: "Emergency"),
                        icon: "bolt.fill",
                        color: PulseColors.StateColors.red,
                        isSelected: selectedType == "emergency_stop"
                    ) { selectedType = selectedType == "emergency_stop" ? nil : "emergency_stop"; selectedFilter = "all" }

                    filterChip(
                        label: L10n.zh("Kill Switch", en: "Kill Switch"),
                        icon: "xmark.octagon.fill",
                        color: PulseColors.StateColors.red,
                        isSelected: selectedType == "kill_switch"
                    ) { selectedType = selectedType == "kill_switch" ? nil : "kill_switch"; selectedFilter = "all" }

                    filterChip(
                        label: L10n.zh("亏损锁", en: "Loss Lock"),
                        icon: "chart.line.downtrend.xyaxis",
                        color: PulseColors.StateColors.orangeRed,
                        isSelected: selectedType == "daily_loss_lock"
                    ) { selectedType = selectedType == "daily_loss_lock" ? nil : "daily_loss_lock"; selectedFilter = "all" }

                    filterChip(
                        label: L10n.zh("手动平仓", en: "Manual"),
                        icon: "hand.raised.fill",
                        color: PulseColors.StateColors.yellow,
                        isSelected: selectedType == "manual_force_close"
                    ) { selectedType = selectedType == "manual_force_close" ? nil : "manual_force_close"; selectedFilter = "all" }

                    filterChip(
                        label: L10n.zh("安全模式", en: "Safe Mode"),
                        icon: "shield.fill",
                        color: PulseColors.StateColors.purple,
                        isSelected: selectedType == "system_safe_mode"
                    ) { selectedType = selectedType == "system_safe_mode" ? nil : "system_safe_mode"; selectedFilter = "all" }
                }
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }

    private func filterChip(label: String, icon: String, color: Color = PulseColors.accent, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(PulseFonts.micro)
            }
            .foregroundStyle(isSelected ? colors.textPrimary : colors.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? color.opacity(0.15) : colors.surface
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - All Clear State

    private var allClearState: some View {
        VStack(spacing: PulseSpacing.lg) {
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(PulseColors.StateColors.green.opacity(0.15 + pulsePhase * 0.1), lineWidth: 2)
                    .frame(width: 120, height: 120)

                // Middle ring
                Circle()
                    .stroke(PulseColors.StateColors.green.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)

                // Inner filled circle
                Circle()
                    .fill(PulseColors.StateColors.green.opacity(0.08))
                    .frame(width: 80, height: 80)

                // Shield checkmark
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PulseColors.StateColors.green)
                    .shadow(color: PulseColors.StateColors.green.opacity(0.4), radius: 8)
            }

            VStack(spacing: PulseSpacing.xs) {
                Text(L10n.zh("全部清除", en: "ALL CLEAR"))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(PulseColors.StateColors.green)
                    .tracking(3)

                Text(L10n.zh(
                    selectedType != nil || selectedFilter != "all"
                        ? L10n.zh("当前筛选条件下无熔断记录", en: "No circuit breaker records for this filter")
                        : L10n.zh("系统未触发过熔断，运行正常", en: "No circuit breakers triggered — system running normally"),
                    en: selectedType != nil || selectedFilter != "all"
                        ? "No breakers match current filter"
                        : "No circuit breakers fired — system nominal"
                ))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PulseSpacing.xl)
    }

    // MARK: - Timeline Layout

    private func timelineLayout(_ records: [CircuitBreakerRecordResponse]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                timelineRow(record, isFirst: index == 0, isLast: index == records.count - 1)
                    .staggeredAppearance(index: index)
            }
        }
    }

    private func timelineRow(_ record: CircuitBreakerRecordResponse, isFirst: Bool, isLast: Bool) -> some View {
        let info = typeInfoMap[record.type] ?? BreakerTypeInfo(label: record.type, labelEn: record.type.uppercased(), color: PulseColors.StateColors.gray, icon: "questionmark.circle")
        let canResolve = canMarkResolved(record)

        return HStack(alignment: .top, spacing: PulseSpacing.md) {
            // Left: Timeline connector + dot
            VStack(spacing: 0) {
                // Top connector line
                if !isFirst {
                    Rectangle()
                        .fill(colors.border.opacity(0.4))
                        .frame(width: 2, height: 12)
                } else {
                    Spacer().frame(height: 12)
                }

                // Colored dot
                ZStack {
                    Circle()
                        .fill(info.color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(record.resolved ? PulseColors.StateColors.green : info.color)
                        .frame(width: 10, height: 10)
                        .shadow(color: (record.resolved ? PulseColors.StateColors.green : info.color).opacity(0.5), radius: 3)
                }

                // Bottom connector line
                if !isLast {
                    Rectangle()
                        .fill(colors.border.opacity(0.4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(width: 24)

            // Right: Record card
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Type badge (large, dramatic)
                HStack(spacing: PulseSpacing.xs) {
                    HStack(spacing: 6) {
                        Image(systemName: info.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.zh(info.label, en: info.labelEn))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(info.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(info.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.badge)
                            .stroke(info.color.opacity(0.3), lineWidth: 1)
                    )

                    // Resolved badge
                    if record.resolved {
                        Text(L10n.Risk.resolved)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(PulseColors.StateColors.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PulseColors.StateColors.green.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Timestamp
                    if let createdAt = record.createdAt {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(formatTimestamp(createdAt))
                                .font(PulseFonts.micro)
                        }
                        .foregroundStyle(colors.textMuted)
                    }
                }

                // Reason codes as pills
                if !record.reasonCodes.isEmpty {
                    HStack(spacing: PulseSpacing.xs) {
                        ForEach(record.reasonCodes, id: \.self) { code in
                            Text(code)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(info.color.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(info.color.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Related IDs row + Mark Resolved button
                HStack(spacing: PulseSpacing.md) {
                    if let cmdId = record.relatedCommandId {
                        HStack(spacing: 3) {
                            Text("CMD")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(colors.textMuted)
                            Text(cmdId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    if let reconId = record.relatedReconciliationId {
                        HStack(spacing: 3) {
                            Text("RECON")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(colors.textMuted)
                            Text(reconId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Mark Resolved button (only for eligible records)
                    if canResolve {
                        Button {
                            resolveEventId = record.id
                        } label: {
                            Label(L10n.Risk.markResolved, systemImage: "checkmark.circle")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .tint(PulseColors.warning)
                        .help(L10n.Risk.markResolved)
                    } else if record.type == "kill_switch" || record.type == "emergency_stop" {
                        Text(L10n.Risk.cannotResolveKillSwitch)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(colors.textMuted.opacity(0.5))
                    }

                    // Record ID
                    Text(record.id)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(colors.textMuted.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(PulseSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .stroke(info.color.opacity(record.resolved ? 0.06 : 0.12), lineWidth: 1)
                    )
            )
            .padding(.bottom, PulseSpacing.sm)
        }
    }

    // MARK: - Helpers

    private func canMarkResolved(_ record: CircuitBreakerRecordResponse) -> Bool {
        let nonResolvableTypes = ["kill_switch", "emergency_stop"]
        return !nonResolvableTypes.contains(record.type) && !record.resolved
    }

    // MARK: - Filtering

    private func filteredRecords(_ records: [CircuitBreakerRecordResponse]) -> [CircuitBreakerRecordResponse] {
        var filtered = records

        // Apply resolve-status filter
        if selectedFilter == "unresolved" {
            filtered = filtered.filter { !$0.resolved }
        } else if selectedFilter == "resolved" {
            filtered = filtered.filter { $0.resolved }
        }

        // Apply type filter
        if let type = selectedType {
            if type == "daily_loss_lock" {
                filtered = filtered.filter { $0.type == "daily_loss_lock" || $0.type == "weekly_loss_lock" }
            } else {
                filtered = filtered.filter { $0.type == type }
            }
        }

        return filtered
    }

    // MARK: - Timestamp

    private func formatTimestamp(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: isoString)
        }() else {
            return String(isoString.prefix(16))
        }

        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60: return L10n.zh("刚刚", en: "just now")
        case ..<3600: return L10n.zh("\(Int(interval / 60)) 分钟前", en: "\(Int(interval / 60))m ago")
        case ..<86400: return L10n.zh("\(Int(interval / 3600)) 小时前", en: "\(Int(interval / 3600))h ago")
        default: return L10n.zh("\(Int(interval / 86400)) 天前", en: "\(Int(interval / 86400))d ago")
        }
    }
}
