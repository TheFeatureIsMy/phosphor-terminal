import SwiftUI

struct StatusPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionStatus) {
            HStack(spacing: PulseSpacing.md) {
                statusCard(
                    title: L10n.BacktestLab.statusBacktestCard,
                    status: viewModel.selectedRun?.status,
                    errorMessage: viewModel.selectedRun?.errorMessage
                )
                Divider().frame(height: 60)
                statusCard(
                    title: L10n.BacktestLab.statusDryrunCard,
                    status: viewModel.recentDryruns.first?.status,
                    errorMessage: nil
                )
            }
        }
    }

    private func statusCard(title: String, status: String?, errorMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title).font(PulseFonts.caption).foregroundStyle(.secondary)
            if let status {
                HStack {
                    Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                    Text(statusLabel(status)).font(PulseFonts.body)
                }
                if let errorMessage, status == "failed" || status == "error" {
                    Text(errorMessage).font(PulseFonts.caption).foregroundStyle(.red)
                    Button(L10n.BacktestLab.statusViewLog) { /* navigate to ExecutionRecordsView */ }
                        .font(PulseFonts.caption)
                }
            } else {
                Text(L10n.BacktestLab.statusNoRun).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "completed": return .green
        case "running": return .blue
        case "failed", "error": return .red
        default: return .gray
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "pending", "starting": return L10n.BacktestLab.statusPending
        case "running": return L10n.BacktestLab.statusRunning
        case "completed": return L10n.BacktestLab.statusCompleted
        case "failed", "error": return L10n.BacktestLab.statusFailed
        default: return s
        }
    }
}
