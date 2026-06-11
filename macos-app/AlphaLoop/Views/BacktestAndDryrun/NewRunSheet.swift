// NewRunSheet.swift — 抽离的回测配置 sheet

import SwiftUI

struct NewRunSheet: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss
    let vm: BacktestLabViewModel

    @State private var startDate: String = "2025-01-01"
    @State private var endDate: String = "2026-06-01"
    @State private var capital: String = "100000"
    @State private var symbols: String = "BTC/USDT"
    @State private var versionId: String = ""
    @State private var submitting = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 14) {
            header
            Divider().overlay(colors.border)
            VStack(spacing: 10) {
                row(label: L10n.BacktestLab.fieldVersion, placeholder: vm.selectedStrategy?.name ?? "", text: $versionId)
                HStack(spacing: 10) {
                    row(label: L10n.BacktestLab.fieldStart, placeholder: "2025-01-01", text: $startDate)
                    row(label: L10n.BacktestLab.fieldEnd, placeholder: "2026-06-01", text: $endDate)
                }
                row(label: L10n.BacktestLab.fieldCapital, placeholder: "100000", text: $capital)
                row(label: L10n.BacktestLab.fieldSymbols, placeholder: L10n.BacktestLab.hintSymbols, text: $symbols)
            }

            if let err = errorMsg {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PulseColors.danger)
                    Text(err).font(PulseFonts.caption).foregroundStyle(PulseColors.danger)
                }
            }

            HStack {
                Button(L10n.BacktestLab.cancel) { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 5) {
                        if submitting {
                            ProgressView().controlSize(.mini).tint(colors.background)
                        } else {
                            Image(systemName: "play.fill").font(.system(size: 10))
                        }
                        Text(submitting ? L10n.BacktestLab.submitting : L10n.BacktestLab.submit)
                            .font(PulseFonts.monoLabel).tracking(0.6)
                    }
                    .foregroundStyle(colors.background)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(PulseColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
                .buttonStyle(.plain)
                .disabled(submitting)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(colors.background)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 14)).foregroundStyle(PulseColors.accent)
            Text(L10n.BacktestLab.sheetTitle)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)
            Spacer()
        }
    }

    private func row(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PulseFonts.micro).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(colors.textMuted)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(colors.surface)
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        submitting = true
        errorMsg = nil
        let symbolArr = symbols.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let cap = Double(capital) ?? 100_000
        let ok = await vm.submitNewRun(
            versionId: versionId.isEmpty ? nil : versionId,
            start: startDate,
            end: endDate,
            capital: cap,
            symbols: symbolArr
        )
        submitting = false
        if ok {
            dismiss()
        } else {
            errorMsg = L10n.BacktestLab.submitFailed
        }
    }
}
