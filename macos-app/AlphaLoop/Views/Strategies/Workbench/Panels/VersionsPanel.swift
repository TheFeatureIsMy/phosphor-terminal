// VersionsPanel.swift — ⌘3 panel showing recent activity + version list
// (Plan 2026-06-18 Task 21). Reads vm.snapshot.{activity,versions}.
import SwiftUI

struct VersionsPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelVersion,
            icon: WorkbenchPanel.version.icon,
            onClose: { vm.closePanel() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                recentSection
                Divider().overlay(colors.border)
                versionsSection
            }
        }
    }

    // MARK: - Recent activity

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(L10n.Workbench.versionsRecent)
            let entries = (vm.snapshot?.activity ?? []).prefix(3)
            if entries.isEmpty {
                emptyText(L10n.Workbench.versionsActivityEmpty)
            } else {
                ForEach(Array(entries), id: \.id) { entry in
                    activityRow(entry)
                }
            }
        }
    }

    private func activityRow(_ entry: ActivityEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: kindIcon(entry.kind))
                .font(.system(size: 10))
                .foregroundStyle(PulseColors.cyan)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(shortenDate(entry.occurredAt))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    if let actor = entry.actor {
                        Text("· \(actor)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func kindIcon(_ kind: String) -> String {
        switch kind {
        case _ where kind.hasPrefix("version"):  return "doc.badge.gearshape"
        case _ where kind.hasPrefix("binding"):  return "shield"
        case _ where kind.hasPrefix("run"):      return "play.circle"
        case _ where kind.hasPrefix("backtest"): return "chart.bar"
        default:                                  return "circle.dotted"
        }
    }

    // MARK: - Version list

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(L10n.Workbench.versionsList)
            let versions = vm.snapshot?.versions ?? []
            let latestId = vm.snapshot?.latestVersionId
            if versions.isEmpty {
                emptyText(L10n.Workbench.versionsEmpty)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(versions) { v in
                            versionRow(v, isLatest: v.id == latestId)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private func versionRow(_ v: StrategyVersionV2, isLatest: Bool) -> some View {
        HStack(spacing: 8) {
            Text("v\(v.versionNo)")
                .font(PulseFonts.captionMedium.monospaced())
                .foregroundStyle(isLatest ? PulseColors.accent : colors.textPrimary)
                .frame(width: 36, alignment: .leading)
            statusBadge(v.status)
            Text(String(v.dslHash.prefix(7)))
                .font(PulseFonts.micro.monospaced())
                .foregroundStyle(colors.textMuted)
            Spacer()
            if let createdAt = v.createdAt {
                Text(shortenDate(createdAt))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isLatest ? PulseColors.accent.opacity(0.08) : colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "validated", "live":         return PulseColors.cyan
            case "paper_run", "paper_pass":   return PulseColors.amber
            case "draft":                     return colors.textMuted
            case "archived", "rejected":      return PulseColors.danger
            default:                          return colors.textSecondary
            }
        }()
        return Text(status)
            .font(PulseFonts.micro)
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .tracking(0.8)
            .foregroundStyle(colors.textMuted)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    private func shortenDate(_ iso: String) -> String {
        // server returns ISO-8601 like "2026-06-18T14:23:00Z" — keep "06-18 14:23"
        guard iso.count >= 16 else { return iso }
        let part = iso.dropFirst(5).prefix(11)  // "06-18T14:23"
        return part.replacingOccurrences(of: "T", with: " ")
    }
}
