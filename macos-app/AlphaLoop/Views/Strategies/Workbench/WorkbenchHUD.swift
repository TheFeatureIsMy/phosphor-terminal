// WorkbenchHUD.swift — 40px persistent top bar for the strategy workbench.
// Spec §5.1: identity (name·v#·hash·time) + StagePill + ReadinessPill +
// next-action chip + 5 buttons + ⋯ menu. Buttons enable per the §5.1 table.
import SwiftUI

struct WorkbenchHUD: View {
    let vm: StrategyWorkspaceViewModel
    let onTriggerPanel: (WorkbenchPanel) -> Void

    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 16) {
            identitySection

            Spacer(minLength: 16)

            StagePill(currentStatus: vm.selectedStrategy?.status ?? "draft")

            ReadinessPill(
                passedCount: vm.snapshot?.readiness.passedCount ?? 0,
                total: vm.snapshot?.readiness.total ?? 11,
                grandStatus: vm.snapshot?.readiness.grandStatus ?? "not_live"
            )

            nextActionChip

            actionGroup
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(colors.background)
        .overlay(
            Rectangle()
                .fill(colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Identity (left side)

    private var identitySection: some View {
        HStack(spacing: 8) {
            if let strategy = vm.selectedStrategy {
                Text(strategy.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                if let version = vm.latestVersion {
                    dot
                    Text("v\(version.versionNo) \(version.status)")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)

                    dot
                    Button(action: { copyHash(version.dslHash) }) {
                        Text(String(version.dslHash.prefix(8)))
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.Workbench.versionsHash + " · " + version.dslHash)

                    if let createdAt = version.createdAt, let ago = relativeTimeAgo(from: createdAt) {
                        dot
                        Text(ago)
                            .font(PulseFonts.captionMedium)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            } else {
                Text(L10n.Workbench.noStrategySelected)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    private var dot: some View {
        Text("·")
            .font(.system(size: 11))
            .foregroundStyle(colors.textMuted)
    }

    // MARK: - Next-action chip

    private var nextActionChip: some View {
        Group {
            if let next = vm.snapshot?.readiness.nextAction, !next.label.isEmpty {
                HStack(spacing: 4) {
                    Text(L10n.Workbench.hudNextLabel)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textMuted)
                    Text(next.label)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColors.accent)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PulseColors.accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(PulseColors.accent.opacity(0.20), lineWidth: 1)
                )
                .onTapGesture { jumpToNextActionPanel(next.targetPanel) }
            }
        }
    }

    // MARK: - Action buttons

    private var actionGroup: some View {
        HStack(spacing: 6) {
            HUDButton(
                title: L10n.Workbench.hudActionValidate,
                systemImage: "checkmark.shield",
                disabled: vm.selectedStrategyId == nil,
                tooltip: vm.selectedStrategyId == nil ? L10n.Workbench.hudReasonNoStrategy : nil
            ) {
                Task { await vm.reloadSnapshot() }
            }

            HUDButton(
                title: L10n.Workbench.hudActionDuplicate,
                systemImage: "doc.on.doc",
                disabled: vm.selectedStrategyId == nil,
                tooltip: vm.selectedStrategyId == nil ? L10n.Workbench.hudReasonNoStrategy : nil
            ) {
                Task { _ = await vm.duplicate() }
            }

            HUDButton(
                title: L10n.Workbench.hudActionArchive,
                systemImage: "archivebox",
                disabled: !canArchive,
                tooltip: canArchive ? nil : L10n.Workbench.hudReasonAlreadyArchived
            ) {
                Task { await vm.archive() }
            }

            HUDButton(
                title: L10n.Workbench.hudActionBindLive,
                systemImage: "shield.lefthalf.filled",
                emphasized: bindLiveIsHot,
                disabled: vm.selectedStrategyId == nil,
                tooltip: bindLiveIsHot ? nil : L10n.Workbench.hudReasonNotPaperPassed
            ) {
                onTriggerPanel(.risk)
            }

            HUDButton(
                title: L10n.Workbench.hudActionRunDryrun,
                systemImage: "play.fill",
                emphasized: canRunDryrun,
                disabled: !canRunDryrun,
                tooltip: canRunDryrun ? nil : L10n.Workbench.hudReasonNotRunnable
            ) {
                Task {
                    _ = await vm.startDryrun()
                    onTriggerPanel(.backtest)
                }
            }

            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            if let status = vm.selectedStrategy?.status {
                let allowed = LifecycleTransition.allowed(from: status)
                if allowed.isEmpty {
                    Text(L10n.Workbench.transitionNoneAvailable)
                } else {
                    ForEach(allowed) { transition in
                        Button(role: transition.isDestructive ? .destructive : nil) {
                            Task { await vm.transitionStatus(transition) }
                        } label: {
                            Label(transition.label, systemImage: transition.icon)
                        }
                    }
                }
            } else {
                Text(L10n.Workbench.hudReasonNoStrategy)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(colors.border, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .help(L10n.Workbench.hudActionMore)
    }

    // MARK: - Predicates

    private var canArchive: Bool {
        guard let s = vm.selectedStrategy else { return false }
        return s.status != "archived"
    }

    private var bindLiveIsHot: Bool {
        vm.selectedStrategy?.status == "paper_passed"
    }

    private var canRunDryrun: Bool {
        guard let status = vm.selectedStrategy?.status else { return false }
        return ["validated", "backtested", "paper_passed"].contains(status)
    }

    // MARK: - Helpers

    private func copyHash(_ hash: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hash, forType: .string)
    }

    private func jumpToNextActionPanel(_ targetPanel: String?) {
        switch targetPanel {
        case "risk":      onTriggerPanel(.risk)
        case "backtest":  onTriggerPanel(.backtest)
        case "readiness": onTriggerPanel(.readiness)
        default:          break
        }
    }

    private func relativeTimeAgo(from iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return nil }
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return L10n.Workbench.timeAgoNow }
        let minutes = secs / 60
        if minutes < 60 { return String(format: L10n.Workbench.timeAgoMinutes, minutes) }
        let hours = minutes / 60
        if hours < 24 { return String(format: L10n.Workbench.timeAgoHours, hours) }
        let days = hours / 24
        return String(format: L10n.Workbench.timeAgoDays, days)
    }
}

// MARK: - HUD button

private struct HUDButton: View {
    let title: String
    let systemImage: String
    var emphasized: Bool = false
    var disabled: Bool = false
    var tooltip: String? = nil
    let action: () -> Void

    @Environment(PulseColors.self) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(PulseFonts.captionMedium)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .foregroundStyle(emphasized ? Color.black : colors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(emphasized ? PulseColors.accent : colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(emphasized ? PulseColors.accent.opacity(0.4) : colors.border, lineWidth: 1)
            )
            .opacity(disabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(tooltip ?? title)
    }
}
