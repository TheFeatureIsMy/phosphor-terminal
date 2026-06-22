// ReadinessPanel.swift — ⌘6 panel showing grand status + strategy/system gates
// + the next-action shortcut. (Plan 2026-06-18 Task 24).
import SwiftUI

struct ReadinessPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelReadiness,
            icon: WorkbenchPanel.readiness.icon,
            onClose: { vm.closePanel() }
        ) {
            if let readiness = vm.snapshot?.readiness {
                VStack(alignment: .leading, spacing: 12) {
                    grandBadge(readiness)
                    gatesSection(L10n.Workbench.readinessStrategyGates, gates: readiness.strategyGates)
                    Divider().overlay(colors.border)
                    gatesSection(L10n.Workbench.readinessSystemGates, gates: readiness.systemGates)
                    nextAction(readiness.nextAction)
                }
            } else {
                Text("—")
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    private func grandBadge(_ r: PerStrategyReadiness) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(grandColor(r.grandStatus).opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: grandIcon(r.grandStatus))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(grandColor(r.grandStatus))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(grandLabel(r.grandStatus))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
                Text("\(r.passedCount) / \(r.total) \(L10n.Workbench.readinessPassed)")
                    .font(PulseFonts.micro.monospaced())
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
        }
        .padding(10)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private func gatesSection(_ title: String, gates: [ReadinessGate]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PulseFonts.micro).tracking(0.8)
                .foregroundStyle(colors.textMuted)
            ForEach(gates) { g in gateRow(g) }
        }
    }

    private func gateRow(_ gate: ReadinessGate) -> some View {
        let color = statusColor(gate.status)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(gate.key)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text("\(gate.value) / \(gate.threshold)")
                    .font(PulseFonts.micro.monospaced())
                    .foregroundStyle(colors.textMuted)
            }
            if !gate.reasonCodes.isEmpty {
                Text(gate.reasonCodes.joined(separator: " · "))
                    .font(PulseFonts.micro)
                    .foregroundStyle(color)
                    .padding(.leading, 12)
            } else if !gate.detail.isEmpty {
                Text(gate.detail)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.leading, 12)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func nextAction(_ next: ReadinessNextAction) -> some View {
        if let panelStr = next.targetPanel,
           let panel = mapTargetPanel(panelStr) {
            Button {
                vm.openPanel(panel)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 11))
                    Text("\(L10n.Workbench.readinessNextStep): \(next.label)").font(PulseFonts.captionMedium)
                    Spacer()
                    Image(systemName: panel.icon).font(.system(size: 10))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(PulseColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            }
            .buttonStyle(.plain)
        } else if !next.label.isEmpty {
            Text("\(L10n.Workbench.readinessNextStep): \(next.label)")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func mapTargetPanel(_ s: String) -> WorkbenchPanel? {
        switch s {
        case "risk":      return .risk
        case "backtest":  return .backtest
        case "readiness": return .readiness
        case "version":   return .version
        case "node":      return .node
        case "list":      return .list
        default:          return nil
        }
    }

    private func grandColor(_ status: String) -> Color {
        switch status {
        case "ready_for_live":    return PulseColors.success
        case "paper_passed":      return PulseColors.cyan
        case "needs_validation":  return PulseColors.warning
        case "needs_config":      return PulseColors.amber
        case "not_live":          return colors.textMuted
        default:                  return colors.textMuted
        }
    }

    private func grandIcon(_ status: String) -> String {
        switch status {
        case "ready_for_live":    return "checkmark.seal.fill"
        case "paper_passed":      return "checkmark.circle.fill"
        case "needs_validation":  return "exclamationmark.triangle.fill"
        case "needs_config":      return "wrench.fill"
        case "not_live":          return "minus.circle"
        default:                  return "questionmark.circle"
        }
    }

    private func grandLabel(_ status: String) -> String {
        switch status {
        case "ready_for_live":    return L10n.Workbench.readinessGrandReadyLive
        case "paper_passed":      return L10n.Workbench.readinessGrandPaperPassed
        case "needs_validation":  return L10n.Workbench.readinessGrandNeedsValidation
        case "needs_config":      return L10n.Workbench.readinessGrandNeedsConfig
        case "not_live":          return L10n.Workbench.readinessGrandNotLive
        default:                  return status
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "healthy":  return PulseColors.success
        case "warning":  return PulseColors.warning
        case "failed":   return PulseColors.danger
        default:         return colors.textMuted
        }
    }
}
