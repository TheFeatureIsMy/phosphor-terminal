// DataVacuumSettingsView.swift — 数据清理管理

import SwiftUI

struct DataVacuumSettingsView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @State private var vacuumJobs: [DataVacuumJob] = []
    @State private var isLoading = true
    @State private var isRunning = false
    @State private var activeJob: DataVacuumJob?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("数据清理")
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                runVacuumCard
                jobHistorySection
            }
        }
        .task { await loadData() }
    }

    // MARK: - Run Vacuum Card

    private var runVacuumCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("执行清理")
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text("扫描并归档过期信号数据，释放存储空间")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    KryptonButton(title: "执行清理", action: {
                            Task { await runVacuum() }
                        }, style: .ghost)
                }
            }

            if let job = activeJob {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: job.status == "running" ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                        .foregroundStyle(job.status == "running" ? PulseColors.warning : PulseColors.success)
                    Text(job.status == "running" ? "清理进行中..." : "清理已启动")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                    Text("ID: \(String(job.id.prefix(8)))")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Job History

    private var jobHistorySection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "清理历史")

            if vacuumJobs.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    StatusDot(status: .online)
                    Text("暂无清理记录")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: PulseSpacing.xxs) {
                    ForEach(Array(vacuumJobs.enumerated()), id: \.element.id) { index, job in
                        vacuumJobRow(job)
                            .staggeredAppearance(index: index)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func vacuumJobRow(_ job: DataVacuumJob) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            // Status indicator
            RoundedRectangle(cornerRadius: 1)
                .fill(jobStatusColor(job.status))
                .frame(width: 3, height: 28)

            Image(systemName: jobStatusIcon(job.status))
                .font(PulseFonts.monoLabel)
                .foregroundStyle(jobStatusColor(job.status))
                .frame(width: 14)

            // Status label
            Text(jobStatusLabel(job.status))
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            // Signals scanned
            if let scanned = job.signalsScanned {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(scanned)")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textPrimary)
                    Text("已扫描")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(width: 70, alignment: .trailing)
            }

            // Signals archived
            if let archived = job.signalsArchived {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(archived)")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                    Text("已归档")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(width: 70, alignment: .trailing)
            }

            // Time
            if let createdAt = job.createdAt {
                Text(String(createdAt.prefix(10)))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func jobStatusColor(_ status: String) -> Color {
        switch status {
        case "completed": return PulseColors.success
        case "running": return PulseColors.warning
        case "failed": return PulseColors.danger
        default: return colors.textMuted
        }
    }

    private func jobStatusIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "running": return "arrow.triangle.2.circlepath"
        case "failed": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private func jobStatusLabel(_ status: String) -> String {
        switch status {
        case "completed": return "完成"
        case "running": return "运行中"
        case "failed": return "失败"
        default: return status
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let api = APIAdmin(client: networkClient)
        vacuumJobs = (try? await api.listVacuumJobs()) ?? []
    }

    private func runVacuum() async {
        isRunning = true
        defer { isRunning = false }
        let api = APIAdmin(client: networkClient)
        activeJob = try? await api.runDataVacuum()
        // Refresh list after starting
        vacuumJobs = (try? await api.listVacuumJobs()) ?? []
    }
}
