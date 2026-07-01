// DryrunStatusPanel.swift — Dryrun 状态面板（无 equity/trades，只有状态指标）

import SwiftUI

struct DryrunStatusPanel: View {
    let run: DryRunRunV2
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            HStack {
                Text(L10n.BacktestLab.dryrunStatus)
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                statusBadge
            }

            metricsGrid

            if let url = run.apiUrl, !url.isEmpty {
                infoRow(L10n.BacktestLab.dryrunApiUrl, value: url, copyable: true)
            }
            if let pid = run.pid {
                infoRow(L10n.BacktestLab.dryrunPid, value: "\(pid)")
            }
            if let started = run.startedAt {
                infoRow(L10n.BacktestLab.dryrunStarted, value: started.prefix(19).description)
            }
            if let stopped = run.stoppedAt {
                infoRow(L10n.BacktestLab.dryrunStopped, value: stopped.prefix(19).description)
            }
            if let err = run.errorMessage, !err.isEmpty {
                Text(err)
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.danger)
                    .padding(PulseSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(PulseColors.danger.opacity(0.1)))
            }

            HStack(spacing: PulseSpacing.md) {
                if run.status == "running" {
                    Button { Task { await vm.stopDryrun(id: run.id) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill").font(.system(size: 11))
                            Text(L10n.BacktestLab.stopDryrun).font(PulseFonts.captionMedium)
                        }
                        .padding(.horizontal, PulseSpacing.md).padding(.vertical, 8)
                        .background(PulseColors.danger)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                    }
                    .buttonStyle(.plain)
                }
                Button { Task { await vm.syncDryrun(id: run.id) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                        Text(L10n.BacktestLab.syncDryrun).font(PulseFonts.captionMedium)
                    }
                    .padding(.horizontal, PulseSpacing.md).padding(.vertical, 8)
                    .background(colors.surfaceHover.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: PulseRadii.button).stroke(colors.border, lineWidth: 1))
                    .foregroundStyle(colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PulseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }

    private var statusBadge: some View {
        let isRunning = run.status == "running"
        return Text(run.status.uppercased())
            .font(PulseFonts.micro)
            .padding(.horizontal, PulseSpacing.sm).padding(.vertical, 2)
            .background(Capsule().fill((isRunning ? PulseColors.accent : colors.textMuted).opacity(0.2)))
            .foregroundStyle(isRunning ? PulseColors.accent : colors.textMuted)
    }

    private var metricsGrid: some View {
        HStack(spacing: PulseSpacing.md) {
            metricCell(L10n.BacktestLab.dryrunTotalTrades, value: "\(run.totalTrades)")
            metricCell(L10n.BacktestLab.dryrunOpenTrades, value: "\(run.openTrades)")
            metricCell(L10n.BacktestLab.dryrunTotalProfit, value: String(format: "%+.2f", run.totalProfit), color: run.totalProfit >= 0 ? PulseColors.accent : PulseColors.danger)
        }
    }

    private func metricCell(_ label: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(color ?? colors.textPrimary)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }

    private func infoRow(_ label: String, value: String, copyable: Bool = false) -> some View {
        HStack {
            Text(label).font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
            Spacer()
            Text(value).font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
