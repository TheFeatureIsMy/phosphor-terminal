// RiskBindingPanel.swift — ⌘4 panel showing current binding(s) + binding entry
// (Plan 2026-06-18 Task 22). Reads vm.snapshot.bindings + readiness guards.
// Opens BindingSheet for the live_small binding flow.
import SwiftUI

struct RiskBindingPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel

    @State private var showingSheet = false

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelRisk,
            icon: WorkbenchPanel.risk.icon,
            onClose: { vm.closePanel() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                bindingsSection
                Divider().overlay(colors.border)
                guardsSection
            }
        }
        .sheet(isPresented: $showingSheet) {
            BindingSheet(vm: vm, isPresented: $showingSheet)
        }
    }

    // MARK: - Bindings

    private var bindingsSection: some View {
        let bindings = vm.snapshot?.bindings ?? []
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(L10n.Workbench.panelRisk)
            if bindings.isEmpty {
                emptyCard
            } else {
                ForEach(bindings) { b in bindingRow(b) }
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Workbench.bindingNoneTitle)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
            Text(L10n.Workbench.bindingNoneDesc)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showingSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill").font(.system(size: 11))
                    Text(L10n.Workbench.bindingBindLiveSmall).font(PulseFonts.captionMedium)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(PulseColors.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private func bindingRow(_ b: StrategyBinding) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
                Text(b.mode.uppercased())
                    .font(PulseFonts.micro)
                    .tracking(0.8)
                    .foregroundStyle(PulseColors.accent)
                Spacer()
                Text(L10n.Workbench.bindingActive)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            kvRow(L10n.Workbench.bindingPolicyLabel, "\(b.riskPolicy.name) · v\(b.riskPolicy.versionNo)")
            kvRow(L10n.Workbench.bindingPoolLabel, b.capitalPool.name)
            kvRow(
                L10n.Workbench.bindingRemaining,
                String(format: "%.2f / %.2f %@", b.capitalPool.remainingBudget, b.capitalPool.totalBudget, b.capitalPool.currency)
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private func kvRow(_ k: String, _ v: String) -> some View {
        HStack(spacing: 6) {
            Text(k).font(PulseFonts.micro).foregroundStyle(colors.textMuted).frame(width: 60, alignment: .leading)
            Text(v).font(PulseFonts.caption).foregroundStyle(colors.textPrimary).lineLimit(1)
        }
    }

    // MARK: - Guards (derived from readiness.gates)

    private var guardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(L10n.Workbench.bindingGuardsTitle)
            let gates = vm.snapshot?.readiness.strategyGates ?? []
            let relevant = gates.filter {
                ["max_position", "daily_loss", "drawdown", "total_exposure"].contains($0.key)
            }
            if relevant.isEmpty {
                Text("—").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            } else {
                ForEach(relevant) { gate in
                    guardRow(gate)
                }
            }
        }
    }

    private func guardRow(_ gate: ReadinessGate) -> some View {
        let color: Color = {
            switch gate.status {
            case "healthy": return PulseColors.success
            case "warning": return PulseColors.warning
            case "failed":  return PulseColors.danger
            default:        return colors.textMuted
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(displayName(for: gate.key))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text("\(gate.value) / \(gate.threshold)")
                .font(PulseFonts.micro.monospaced())
                .foregroundStyle(colors.textMuted)
        }
    }

    private func displayName(for key: String) -> String {
        switch key {
        case "max_position":    return L10n.Workbench.bindingGuardMaxPosition
        case "daily_loss":      return L10n.Workbench.bindingGuardDailyLoss
        case "drawdown":        return L10n.Workbench.bindingGuardDrawdown
        case "total_exposure":  return L10n.Workbench.bindingGuardExposure
        default:                return key
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .tracking(0.8)
            .foregroundStyle(colors.textMuted)
    }
}
