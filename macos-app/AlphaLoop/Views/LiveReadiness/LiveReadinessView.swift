// LiveReadinessView.swift — 实盘准入检查页面

import SwiftUI

struct LiveReadinessView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var viewModel: LiveReadinessViewModel?

    var body: some View {
        ScrollView {
            if let vm = viewModel {
                if vm.isLoading {
                    LoadingView(type: .detail).padding(PulseSpacing.lg)
                } else if let data = vm.data {
                    VStack(spacing: PulseSpacing.lg) {
                        HStack(spacing: PulseSpacing.xl) {
                            scoreCard(score: data.score)
                            stateBanner(data: data)
                        }
                        .padding(.horizontal, PulseSpacing.lg)

                        if !data.blockingReasons.isEmpty {
                            reasonSection(title: "阻断项", reasons: data.blockingReasons, color: PulseColors.StateColors.red)
                        }

                        if !data.warnings.isEmpty {
                            reasonSection(title: "警告项", reasons: data.warnings, color: PulseColors.StateColors.yellow)
                        }

                        systemCheckGrid(checks: data.checks)
                        actionBar(data: data, vm: vm)
                    }
                    .padding(.vertical, PulseSpacing.lg)
                } else {
                    EmptyStateView(icon: "checkmark.shield", title: "加载失败", description: vm.error ?? "无法获取准入数据")
                        .padding(PulseSpacing.lg)
                }
            } else {
                LoadingView(type: .detail).padding(PulseSpacing.lg)
            }
        }
        .task {
            if viewModel == nil {
                let vm = LiveReadinessViewModel(client: networkClient)
                viewModel = vm
                await vm.loadData()
            }
        }
    }

    private func scoreCard(score: Int) -> some View {
        VStack(spacing: PulseSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(colors.surface, lineWidth: 8)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(PulseFonts.tabularLarge)
                        .foregroundStyle(scoreColor(score))
                    Text("/ 100")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
            Text("准入分数")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.lg)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }

    private func stateBanner(data: LiveReadinessResponse) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.xs) {
                Circle().fill(stateColor(data.state)).frame(width: 10, height: 10)
                Text(data.state)
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(stateColor(data.state))
            }
            Text(stateDescription(data.state))
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: PulseSpacing.md) {
                checkBadge(label: "Paper", allowed: data.canStartPaper)
                checkBadge(label: "Live Small", allowed: data.canStartLiveSmall)
                checkBadge(label: "Full Live", allowed: data.canStartFullLive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.lg)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }

    private func reasonSection(title: String, reasons: [[String: String]], color: Color) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(color)
                .padding(.horizontal, PulseSpacing.lg)
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                    Text(reason["code"] ?? "")
                        .font(PulseFonts.caption)
                        .foregroundStyle(color)
                    Text(reason["message"] ?? "")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.xxs)
            }
        }
        .padding(.vertical, PulseSpacing.sm)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        .padding(.horizontal, PulseSpacing.lg)
    }

    private func systemCheckGrid(checks: [ReadinessCheckResponse]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: PulseSpacing.sm) {
            ForEach(Array(checks.enumerated()), id: \.element.key) { index, check in
                checkCell(check)
                    .staggeredAppearance(index: index)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
    }

    private func checkCell(_ check: ReadinessCheckResponse) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Circle()
                .fill(checkColor(check.status))
                .frame(width: 8, height: 8)
            Text(check.label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .lineLimit(1)
            Text(check.value)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
            Text(check.threshold)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
        .padding(PulseSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    private func actionBar(data: LiveReadinessResponse, vm: LiveReadinessViewModel) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Spacer()
            Button {
                Task { await vm.runCheck() }
            } label: {
                HStack(spacing: PulseSpacing.xs) {
                    if vm.isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Text("重新检查")
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isChecking)

            if data.canStartPaper {
                Button("启动模拟") {}
                    .buttonStyle(.bordered)
            }
            if data.canStartLiveSmall {
                Button("启动小仓实盘") {}
                    .buttonStyle(.borderedProminent)
                    .tint(PulseColors.StateColors.orange)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
    }

    // Helpers
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return PulseColors.StateColors.green }
        if score >= 50 { return PulseColors.StateColors.yellow }
        return PulseColors.StateColors.red
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "LIVE_READY": return PulseColors.StateColors.green
        case "LIVE_SMALL_READY": return PulseColors.StateColors.orange
        case "PAPER_ONLY": return PulseColors.StateColors.yellow
        default: return PulseColors.StateColors.red
        }
    }

    private func stateDescription(_ state: String) -> String {
        switch state {
        case "LIVE_READY": return "所有检查通过，可启动实盘交易"
        case "LIVE_SMALL_READY": return "部分项存在警告，仅允许小仓实盘"
        case "PAPER_ONLY": return "存在阻断项，仅允许模拟交易"
        default: return "系统未就绪，请检查阻断项"
        }
    }

    private func checkBadge(label: String, allowed: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
            Text(label).font(PulseFonts.micro)
        }
        .foregroundStyle(allowed ? PulseColors.StateColors.green : PulseColors.StateColors.red)
    }

    private func checkColor(_ status: String) -> Color {
        switch status {
        case "healthy": return PulseColors.StateColors.green
        case "warning": return PulseColors.StateColors.yellow
        case "failed": return PulseColors.StateColors.red
        default: return PulseColors.StateColors.gray
        }
    }
}
