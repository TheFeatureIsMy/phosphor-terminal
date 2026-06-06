// StrategyVersionsTab.swift — 版本历史列表

import SwiftUI

struct StrategyVersionsTab: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: StrategyDetailViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.md) {
                if viewModel.versions.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "暂无版本",
                        description: "在 DSL 规则标签页中保存版本"
                    )
                    .frame(height: 200)
                } else {
                    ForEach(Array(viewModel.versions.enumerated()), id: \.element.id) { index, version in
                        versionRow(version, isLatest: index == 0)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private func versionRow(_ version: StrategyVersionV2, isLatest: Bool) -> some View {
        HStack(spacing: PulseSpacing.md) {
            // Version badge
            Text("v\(version.versionNo)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(isLatest ? PulseColors.accent : colors.textSecondary)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xxs) {
                    Text("DSL \(version.dslVersion)")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    if isLatest {
                        Text("最新")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulseColors.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(PulseColors.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    statusBadge(version.status)
                }

                HStack(spacing: PulseSpacing.sm) {
                    Text("hash: \(String(version.dslHash.prefix(12)))...")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    Text("by \(version.createdBy)")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    if let date = version.createdAt {
                        Text(date.prefix(10))
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }

            Spacer()

            // Load into editor
            Button {
                viewModel.loadDSLFromVersion(version)
            } label: {
                Text("加载")
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(isLatest ? PulseColors.accent.opacity(0.04) : colors.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(isLatest ? PulseColors.accent.opacity(0.15) : Color.clear, lineWidth: 1)
        )
    }

    private func statusBadge(_ status: String) -> some View {
        let label: String
        let color: Color
        switch status {
        case "draft": label = "草稿"; color = colors.textMuted
        case "validated": label = "已验证"; color = PulseColors.info
        case "backtested": label = "已回测"; color = PulseColors.success
        default: label = status; color = colors.textMuted
        }
        return Text(label)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
