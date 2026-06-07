// DashboardView.swift — Krypton Pro AI 总控台
// 高密度 Bento Grid：行情、AI 判断、人工确认、权益、持仓与风控

import SwiftUI

struct DashboardView: View {
    @Environment(PulseColors.self) private var colors
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.md) {
                if viewModel.isLoading {
                    loadingSkeleton
                } else {
                    mainContent
                }
            }
            .padding(PulseSpacing.md)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task {
            await viewModel.loadAll()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Main Content Bento Grid

    private var mainContent: some View {
        VStack(spacing: PulseSpacing.md) {
            UnifiedToolbar(
                providerStatus: viewModel.aiProviderStatus,
                gpuStatus: viewModel.gpuStatus,
                todayCost: viewModel.todayAICost,
                pendingJobs: viewModel.pendingAIJobs
            )

            TickerTapeView()

            HStack(alignment: .top, spacing: PulseSpacing.md) {
                // Left column: AI + Pending + Risk
                VStack(spacing: PulseSpacing.md) {
                    if let judgment = viewModel.aiMarketJudgment {
                        AIMarketJudgmentCard(judgment: judgment)
                    }

                    PendingConfirmationsCard(
                        confirmations: viewModel.pendingConfirmations,
                        onApprove: { viewModel.approveConfirmation($0) },
                        onReject: { viewModel.rejectConfirmation($0) }
                    )

                    if let riskStats = viewModel.riskInterceptions {
                        RiskInterceptionStatsCard(summary: riskStats)
                    }
                }
                .frame(maxWidth: .infinity)

                // Right column: Equity + Positions + Signals + Health
                VStack(spacing: PulseSpacing.md) {
                    BentoEquityCard(points: viewModel.equityCurve)

                    PositionsRiskCard(positions: viewModel.positions)

                    AgentSignalDistributionCard(groups: viewModel.agentSignalDistribution)

                    ServiceHealthCard(services: ServiceHealthCard.ServiceStatus.previewData)
                }
                .frame(maxWidth: .infinity)
            }

            // Bottom: Recent Risk Events (full width)
            RecentRiskEventsCard(events: RecentRiskEventsCard.RiskEventItem.previewData)
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surface).frame(height: 52).shimmer()
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface).frame(height: 36).shimmer()

            HStack(spacing: PulseSpacing.md) {
                VStack(spacing: PulseSpacing.md) {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 160).shimmer()
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 180).shimmer()
                }
                VStack(spacing: PulseSpacing.md) {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 220).shimmer()
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 140).shimmer()
                }
            }
        }
    }
}
