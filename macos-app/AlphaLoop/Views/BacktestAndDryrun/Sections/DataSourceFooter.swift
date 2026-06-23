import SwiftUI

struct DataSourceFooter: View {
    @Bindable var viewModel: BacktestLabViewModel
    @State private var showConfig = false

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var body: some View {
        if let r = viewModel.selectedRun, viewModel.phase == .completed {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack(spacing: PulseSpacing.md) {
                    Label("\(L10n.BacktestLab.dsEngine): \(L10n.BacktestLab.dsFreqtrade)", systemImage: "cpu")
                    Label("\(L10n.BacktestLab.dsSource): \(r.symbols.first ?? "—")", systemImage: "chart.bar")
                    if let c = r.completedAt, let cr = r.createdAt,
                       let cd = parseISODate(c), let crd = parseISODate(cr) {
                        Label("\(L10n.BacktestLab.dsExecTime): \(formatDuration(cd.timeIntervalSince(crd)))", systemImage: "clock")
                    }
                    if let h = r.dslHash {
                        Label("\(L10n.BacktestLab.dsDslHash): \(h.prefix(8))", systemImage: "number")
                    }
                }
                .font(PulseFonts.caption)
                .foregroundStyle(.secondary)
                Button(L10n.BacktestLab.dsConfigSnapshot) { showConfig = true }
                    .font(PulseFonts.caption)
            }
            .sheet(isPresented: $showConfig) {
                ScrollView {
                    Text(String(describing: r.config)).font(PulseFonts.body.monospaced())
                        .padding()
                }
            }
        }
    }

    private func parseISODate(_ s: String) -> Date? {
        // Try with fractional seconds first, then without
        if let d = isoFormatter.date(from: s) { return d }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return "\(m)m\(sec)s"
    }
}
