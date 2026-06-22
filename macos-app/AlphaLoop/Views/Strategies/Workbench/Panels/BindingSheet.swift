// BindingSheet.swift — modal sheet for ⌘4 binding entry (Plan Task 22).
// Lists active risk_policy_versions + capital_pools (pool_type=live_small),
// posts vm.createBinding(versionId:policyVersionId:poolId:mode:).
import SwiftUI

struct BindingSheet: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel
    @Binding var isPresented: Bool

    @State private var policies: [RiskPolicyVersionSummary] = []
    @State private var pools: [CapitalPoolDetail] = []
    @State private var selectedPolicyId: String?
    @State private var selectedPoolId: String?
    @State private var mode: String = "live_small"
    @State private var loading = true
    @State private var submitting = false
    @State private var error: String?

    private let modes = ["dry_run", "shadow", "live_small"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Workbench.bindingSheetTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.textPrimary)

            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                policyPicker
                poolPicker
                modePicker
                if let error {
                    Text(error)
                        .font(PulseFonts.caption)
                        .foregroundStyle(PulseColors.danger)
                }
                actions
            }
        }
        .padding(24)
        .frame(width: 460)
        .task { await loadOptions() }
    }

    private var policyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Workbench.bindingSheetPick)
                .font(PulseFonts.micro).tracking(0.6).foregroundStyle(colors.textMuted)
            Picker("", selection: Binding(
                get: { selectedPolicyId ?? policies.first?.id ?? "" },
                set: { selectedPolicyId = $0 }
            )) {
                ForEach(policies) { p in
                    Text("\(p.policyName) · v\(p.versionNo)").tag(p.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var poolPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Workbench.bindingSheetPickPool)
                .font(PulseFonts.micro).tracking(0.6).foregroundStyle(colors.textMuted)
            Picker("", selection: Binding(
                get: { selectedPoolId ?? pools.first?.id ?? "" },
                set: { selectedPoolId = $0 }
            )) {
                ForEach(pools) { p in
                    Text("\(p.name) · \(String(format: "%.0f", p.totalBudget)) \(p.currency)").tag(p.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Workbench.bindingSheetMode)
                .font(PulseFonts.micro).tracking(0.6).foregroundStyle(colors.textMuted)
            Picker("", selection: $mode) {
                ForEach(modes, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Spacer()
            Button(L10n.Workbench.bindingSheetCancel) { isPresented = false }
                .buttonStyle(.bordered)
            Button {
                Task { await submit() }
            } label: {
                if submitting { ProgressView().controlSize(.small) }
                else { Text(L10n.Workbench.bindingSheetApply) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(submitting || selectedPolicyId == nil || selectedPoolId == nil || vm.latestVersion == nil)
        }
    }

    private func loadOptions() async {
        loading = true
        defer { loading = false }
        let api = APIRiskLookup(client: networkClient)
        do {
            async let p = api.listRiskPolicyVersions(status: "active")
            async let pl = api.listCapitalPools(poolType: "live_small")
            policies = try await p
            pools = try await pl
            if selectedPolicyId == nil { selectedPolicyId = policies.first?.id }
            if selectedPoolId == nil { selectedPoolId = pools.first?.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submit() async {
        guard let policyId = selectedPolicyId,
              let poolId = selectedPoolId,
              let versionId = vm.latestVersion?.id else { return }
        submitting = true
        await vm.createBinding(
            versionId: versionId,
            policyVersionId: policyId,
            poolId: poolId,
            mode: mode
        )
        submitting = false
        isPresented = false
    }
}
