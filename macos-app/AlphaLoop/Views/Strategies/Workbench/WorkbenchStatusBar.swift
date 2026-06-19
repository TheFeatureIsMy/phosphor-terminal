// WorkbenchStatusBar.swift — 26px persistent bottom bar.
// Spec §5.2: validation chip · version/hash · node/edge counts · ⌘1~⌘6 hint.
import SwiftUI

enum CanvasValidationState: Equatable {
    case unvalidated
    case valid
    case invalid(count: Int)

    static func from(valid: Bool?, errorCount: Int = 0) -> CanvasValidationState {
        guard let valid else { return .unvalidated }
        return valid ? .valid : .invalid(count: max(errorCount, 1))
    }
}

struct WorkbenchStatusBar: View {
    let validationState: CanvasValidationState
    let version: StrategyVersionV2?
    let nodeCount: Int
    let edgeCount: Int

    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 12) {
            validationChip
            if let version {
                separator
                versionLabel(version)
                separator
                hashLabel(version)
            }
            separator
            Text(String(format: L10n.Workbench.statusNodes, nodeCount))
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textMuted)
            Text("·").font(.system(size: 10)).foregroundStyle(colors.textMuted)
            Text(String(format: L10n.Workbench.statusEdges, edgeCount))
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textMuted)

            Spacer(minLength: 16)

            kbdHint
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(colors.background)
        .overlay(
            Rectangle()
                .fill(colors.border)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Pieces

    private var validationChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
            Text(chipLabel)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(chipColor)
        }
    }

    private func versionLabel(_ v: StrategyVersionV2) -> some View {
        Text("v\(v.versionNo) \(v.status)")
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textSecondary)
    }

    private func hashLabel(_ v: StrategyVersionV2) -> some View {
        Text(String(v.dslHash.prefix(8)))
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textMuted)
            .help(L10n.Workbench.versionsHash + " · " + v.dslHash)
    }

    private var separator: some View {
        Text("·")
            .font(.system(size: 10))
            .foregroundStyle(colors.textMuted)
    }

    private var kbdHint: some View {
        Text(L10n.Workbench.statusShortcutHint)
            .font(PulseFonts.captionMedium)
            .foregroundStyle(colors.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
            )
    }

    // MARK: - Validation chip color/label

    private var chipColor: Color {
        switch validationState {
        case .unvalidated:    return colors.textMuted
        case .valid:          return PulseColors.accent
        case .invalid:        return PulseColors.danger
        }
    }

    private var chipLabel: String {
        switch validationState {
        case .unvalidated:        return L10n.Workbench.statusUnvalidated
        case .valid:              return L10n.Workbench.statusValid
        case .invalid(let count): return String(format: L10n.Workbench.statusInvalid, count)
        }
    }
}
