// StrategyRunsTab.swift — 策略运行记录列表

import SwiftUI

struct StrategyRunsTab: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Bindable var viewModel: StrategyDetailViewModel
    let client: NetworkClientProtocol

    @State private var runs: [StrategyRunV2] = []
    @State private var isLoading = true
    @State private var filterMode: String? = nil
    @State private var filterStatus: String? = nil

    private let modeOptions: [(String?, String)] = [
        (nil, L10n.zh("全部", en: "All")), ("dryrun", L10n.zh("模拟", en: "Paper")), ("live", L10n.zh("实盘", en: "Live")),
    ]

    private let statusOptions: [(String?, String)] = [
        (nil, L10n.zh("全部", en: "All")), ("running", L10n.zh("运行中", en: "Running")), ("stopped", L10n.zh("已停止", en: "Stopped")), ("error", L10n.zh("异常", en: "Error")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider().foregroundStyle(colors.border)

            if isLoading {
                loadingView
            } else if runs.isEmpty {
                EmptyStateView(
                    icon: "play.circle",
                    title: L10n.zh("暂无运行记录", en: "No Run History"),
                    description: L10n.zh("启动策略后将在此显示运行记录", en: "Run history will appear here after launching a strategy")
                )
            } else {
                runsList
            }
        }
        .animation(nil, value: runs.count)
        .task { await loadRuns() }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: PulseSpacing.md) {
            Text(L10n.zh("模式", en: "Mode")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            ForEach(modeOptions, id: \.1) { value, label in
                Button {
                    filterMode = value
                    Task { await loadRuns() }
                } label: {
                    Text(label)
                        .font(PulseFonts.caption)
                        .foregroundStyle(filterMode == value ? PulseColors.accent : colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(filterMode == value ? PulseColors.accent.opacity(0.1) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Text("|").foregroundStyle(colors.border).font(PulseFonts.micro)

            Text(L10n.zh("状态", en: "Status")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            ForEach(statusOptions, id: \.1) { value, label in
                Button {
                    filterStatus = value
                    Task { await loadRuns() }
                } label: {
                    Text(label)
                        .font(PulseFonts.caption)
                        .foregroundStyle(filterStatus == value ? PulseColors.accent : colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(filterStatus == value ? PulseColors.accent.opacity(0.1) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                Task { await loadRuns() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - Runs List

    private var runsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PulseSpacing.xs) {
                ForEach(runs) { run in
                    runRow(run)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .id(settingsState.language)
    }

    private func runRow(_ run: StrategyRunV2) -> some View {
        KryptonCard(emphasis: .bold) {
            HStack(spacing: PulseSpacing.md) {
                // Mode badge
                Text(run.mode == "live" ? L10n.zh("实盘", en: "Live") : L10n.zh("模拟", en: "Paper"))
                    .font(PulseFonts.micro)
                    .foregroundStyle(run.mode == "live" ? PulseColors.loss : PulseColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((run.mode == "live" ? PulseColors.loss : PulseColors.accent).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Status badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(runStatusColor(run.status))
                        .frame(width: 6, height: 6)
                    Text(runStatusLabel(run.status))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                }

                // Start time
                if let startedAt = run.startedAt {
                    Text(formatDate(startedAt))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                }

                // Duration
                Text(durationText(run))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)

                Spacer()

                // Version ID (truncated)
                Text(String(run.strategyVersionId.prefix(8)))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: PulseSpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 52)
                    .shimmer()
            }
        }
        .padding(PulseSpacing.lg)
    }

    // MARK: - Data

    private func loadRuns() async {
        withAnimation(nil) {
            isLoading = true
        }
        do {
            let api = APIStrategyRuns(client: client)
            let result = try await api.listRuns(mode: filterMode, status: filterStatus)
            withAnimation(nil) {
                runs = result
            }
        } catch {
            withAnimation(nil) {
                runs = []
            }
        }
        withAnimation(nil) {
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func runStatusColor(_ status: String) -> Color {
        switch status {
        case "running": return PulseColors.statusActive
        case "stopped": return colors.textMuted
        case "error": return PulseColors.statusError
        default: return colors.textMuted
        }
    }

    private func runStatusLabel(_ status: String) -> String {
        switch status {
        case "running": return L10n.zh("运行中", en: "Running")
        case "stopped": return L10n.zh("已停止", en: "Stopped")
        case "error": return L10n.zh("异常", en: "Error")
        default: return status
        }
    }

    private func durationText(_ run: StrategyRunV2) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        guard let startStr = run.startedAt,
              let start = formatter.date(from: startStr) ?? fallback.date(from: startStr)
        else { return "--" }

        let end: Date
        if let stoppedStr = run.stoppedAt,
           let stopped = formatter.date(from: stoppedStr) ?? fallback.date(from: stoppedStr) {
            end = stopped
        } else {
            end = Date()
        }

        let interval = end.timeIntervalSince(start)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        let hours = Int(interval / 3600)
        let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(mins)m"
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        let display = DateFormatter()
        display.dateFormat = "MM-dd HH:mm"
        return display.string(from: date)
    }
}
