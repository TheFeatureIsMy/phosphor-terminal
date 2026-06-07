// StrategyOverviewTab.swift — v2.5 策略概览

import SwiftUI

struct StrategyOverviewTab: View {
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var client
    @Bindable var viewModel: StrategyDetailViewModel

    @State private var preconditions: [LiveSmallPrecondition] = []
    @State private var isCheckingLiveSmall = false
    @State private var liveSmallChecked = false
    @State private var liveSmallError: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                if let s = viewModel.strategy {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        TerminalLabel(text: "策略信息")
                        infoRow("名称", value: s.name)
                        infoRow("类型", value: s.strategyType)
                        infoRow("来源", value: s.sourceType)
                        infoRow("状态", value: s.statusLabel)
                        if let desc = s.description {
                            infoRow("描述", value: desc)
                        }
                    }

                    Divider().foregroundStyle(colors.border)

                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        TerminalLabel(text: "最新版本")
                        if let v = viewModel.latestVersion {
                            infoRow("版本号", value: "v\(v.versionNo)")
                            infoRow("DSL 版本", value: v.dslVersion)
                            infoRow("哈希", value: String(v.dslHash.prefix(16)) + "...")
                            infoRow("创建者", value: v.createdBy)
                        } else {
                            Text("暂无版本 — 请在 DSL 规则中创建")
                                .font(PulseFonts.caption)
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    Divider().foregroundStyle(colors.border)

                    liveSmallSection
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    // MARK: - Live Small 评估

    private var liveSmallSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: "Live Small 评估")

            if !liveSmallChecked {
                Button {
                    Task { await runPreconditionCheck() }
                } label: {
                    HStack(spacing: 6) {
                        if isCheckingLiveSmall {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 12))
                        }
                        Text("Live Small 评估")
                            .font(PulseFonts.caption)
                    }
                    .foregroundStyle(PulseColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PulseColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(isCheckingLiveSmall || viewModel.latestVersion == nil)
            }

            if let errorMsg = liveSmallError {
                Text(errorMsg)
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.loss)
            }

            if liveSmallChecked && !preconditions.isEmpty {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    ForEach(preconditions, id: \.gateName) { gate in
                        HStack(spacing: PulseSpacing.xs) {
                            Image(systemName: gate.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(gate.passed ? colors.profit : PulseColors.loss)
                            Text(gate.gateName)
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textPrimary)
                            if let msg = gate.message {
                                Text(msg)
                                    .font(PulseFonts.micro)
                                    .foregroundStyle(colors.textMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if preconditions.allSatisfy({ $0.passed }) {
                    Button {
                        Task { await applyLiveSmall() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                            Text("申请 Live Small")
                                .font(PulseFonts.captionMedium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(PulseColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, PulseSpacing.xxs)
                }
            }
        }
    }

    // MARK: - Actions

    private func runPreconditionCheck() async {
        isCheckingLiveSmall = true
        liveSmallError = nil
        do {
            let api = APILiveSmall(client: client)
            let body: [String: Any] = ["strategy_id": viewModel.strategyId]
            let evaluation = try await api.evaluate(body: body)
            preconditions = evaluation.preconditions ?? []
            liveSmallChecked = true
        } catch {
            liveSmallError = "评估失败: \(error.localizedDescription)"
        }
        isCheckingLiveSmall = false
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(spacing: PulseSpacing.md) {
            Text(label)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textPrimary)
        }
    }

    private func applyLiveSmall() async {
        guard let strategy = viewModel.strategy else { return }
        let api = APILiveSmall(client: client)
        let body: [String: Any] = ["strategy_version_id": strategy.id]
        if let evaluation = try? await api.evaluate(body: body) {
            if evaluation.canExecute {
                liveSmallError = nil
            } else {
                liveSmallError = "Live Small 评估未通过"
            }
        } else {
            liveSmallError = "请求失败"
        }
    }
}
