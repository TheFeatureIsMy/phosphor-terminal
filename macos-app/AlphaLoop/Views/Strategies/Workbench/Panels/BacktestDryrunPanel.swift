// BacktestDryrunPanel.swift — ⌘5 panel showing recent backtests / dryruns
// (Plan 2026-06-18 Task 23). Top summary rows + merged time-sorted list.
// "See all" jumps to AppRoute.backtestSimulation.
import SwiftUI

struct BacktestDryrunPanel: View {
    @Environment(PulseColors.self) private var colors
    @Environment(AppState.self) private var appState
    let vm: StrategyWorkspaceViewModel

    private enum RunKind { case backtest, dryrun }
    private struct RunRow: Identifiable, Hashable {
        let id: String
        let kind: RunKind
        let status: String
        let startedAt: String?
        let detail: String
    }

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelBacktest,
            icon: WorkbenchPanel.backtest.icon,
            onClose: { vm.closePanel() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                summary
                Divider().overlay(colors.border)
                allRuns
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryRow(
                label: L10n.Workbench.btLatestBacktest,
                bt: vm.snapshot?.recentBacktests.first,
                dr: nil
            )
            summaryRow(
                label: L10n.Workbench.btLatestDryrun,
                bt: nil,
                dr: vm.snapshot?.recentDryruns.first
            )
        }
    }

    private func summaryRow(label: String, bt: BacktestRunSummary?, dr: StrategyRunSummary?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(PulseFonts.micro)
                .tracking(0.6)
                .foregroundStyle(colors.textMuted)
                .frame(width: 90, alignment: .leading)
            if let bt {
                statusDot(bt.status)
                Text(formatBacktestDetail(bt))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
            } else if let dr {
                statusDot(dr.status)
                Text("\(dr.mode) · \(dr.status)")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
            } else {
                Text("—").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
            Spacer()
        }
    }

    private var allRuns: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.Workbench.btAllRuns)
                    .font(PulseFonts.micro).tracking(0.8).foregroundStyle(colors.textMuted)
                Spacer()
                Button {
                    appState.selectedRoute = .backtestSimulation
                    vm.closePanel()
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.Workbench.btSeeAll)
                        Image(systemName: "arrow.right")
                    }
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.accent)
                }
                .buttonStyle(.plain)
            }
            let rows = mergedRows()
            if rows.isEmpty {
                Text(L10n.Workbench.btEmpty)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(rows) { row in runRow(row) }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private func runRow(_ row: RunRow) -> some View {
        HStack(spacing: 8) {
            kindTag(row.kind)
            statusDot(row.status)
            Text(row.detail)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
            Spacer()
            if let t = row.startedAt { Text(shortenDate(t)).font(PulseFonts.micro).foregroundStyle(colors.textMuted) }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Helpers

    private func mergedRows() -> [RunRow] {
        let bts: [RunRow] = (vm.snapshot?.recentBacktests ?? []).map {
            RunRow(
                id: "bt-\($0.id)",
                kind: .backtest,
                status: $0.status,
                startedAt: $0.startedAt,
                detail: formatBacktestDetail($0)
            )
        }
        let drs: [RunRow] = (vm.snapshot?.recentDryruns ?? []).map {
            RunRow(
                id: "dr-\($0.id)",
                kind: .dryrun,
                status: $0.status,
                startedAt: $0.startedAt ?? $0.createdAt,
                detail: "\($0.mode) · \($0.status)"
            )
        }
        return (bts + drs).sorted { ($0.startedAt ?? "") > ($1.startedAt ?? "") }
    }

    private func formatBacktestDetail(_ b: BacktestRunSummary) -> String {
        if let ret = b.totalReturn {
            return "#\(b.id) · \(b.status) · \(L10n.Workbench.btReturn) \(String(format: "%.1f", ret * 100))%"
        }
        return "#\(b.id) · \(b.status)"
    }

    private func kindTag(_ kind: RunKind) -> some View {
        let (text, color): (String, Color) = {
            switch kind {
            case .backtest: return (L10n.Workbench.btKindBacktest, PulseColors.cyan)
            case .dryrun:   return (L10n.Workbench.btKindDryrun, PulseColors.amber)
            }
        }()
        return Text(text)
            .font(PulseFonts.micro)
            .tracking(0.6)
            .foregroundStyle(color)
            .frame(width: 36, alignment: .center)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func statusDot(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "success", "completed", "running", "active": return PulseColors.success
            case "failed", "error":                            return PulseColors.danger
            case "pending", "starting":                         return PulseColors.amber
            default:                                            return colors.textMuted
            }
        }()
        return Circle().fill(color).frame(width: 6, height: 6)
    }

    private func shortenDate(_ iso: String) -> String {
        guard iso.count >= 16 else { return iso }
        let part = iso.dropFirst(5).prefix(11)
        return part.replacingOccurrences(of: "T", with: " ")
    }
}
