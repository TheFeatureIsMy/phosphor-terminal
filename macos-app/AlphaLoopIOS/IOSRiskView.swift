import SwiftUI

struct IOSRiskView: View {
    let client: LiveNetworkClient

    @State private var overview: RiskOverviewBFFResponse?
    @State private var rules: RiskRulesResponse?
    @State private var isLoading = false
    @State private var busy = false
    @State private var error: String?
    @State private var confirmBlock = false

    private var api: APIRiskBFF { APIRiskBFF(client: client) }
    private var isBlocked: Bool {
        overview?.activeLocks.contains { $0["lock"] == "manual_block" } ?? false
    }

    var body: some View {
        NavigationStack {
            List {
                if let overview {
                    Section("状态") {
                        LabeledContent("全局", value: overview.state)
                        LabeledContent("账户", value: overview.accountState)
                        LabeledContent("紧急锁定", value: overview.emergencyLocked ? "是" : "否")
                        if !overview.reasonCodes.isEmpty {
                            LabeledContent("原因", value: overview.reasonCodes.joined(separator: ", "))
                        }
                    }

                    if !overview.activeLocks.isEmpty {
                        Section("生效中的锁") {
                            ForEach(Array(overview.activeLocks.enumerated()), id: \.offset) { _, lock in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lock["lock"] ?? "unknown").font(.subheadline.monospaced())
                                    if let reason = lock["reason"] {
                                        Text(reason).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !overview.guards.isEmpty {
                        Section("风控护栏") {
                            ForEach(overview.guards) { guardItem in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(guardItem.label)
                                        Spacer()
                                        Text(guardItem.status)
                                            .font(.caption)
                                            .foregroundStyle(guardItem.status == "healthy" ? .green : .orange)
                                    }
                                    ProgressView(value: min(max(guardItem.remainingPct, 0), 1))
                                        .tint(guardItem.status == "healthy" ? .green : .orange)
                                }
                            }
                        }
                    }
                }

                if let rules {
                    Section("规则") {
                        LabeledContent("日亏损上限", value: String(format: "%.2f%%", rules.dailyLossLimit))
                        LabeledContent("周亏损上限", value: String(format: "%.2f%%", rules.weeklyLossLimit))
                        LabeledContent("连亏上限", value: "\(rules.consecutiveLossesLimit)")
                        LabeledContent("最大回撤", value: String(format: "%.2f%%", rules.maxDrawdown))
                        LabeledContent("相关性阈值", value: String(format: "%.2f", rules.correlationThreshold))
                        LabeledContent("Kill Switch", value: rules.killSwitch.active ? "开启" : "关闭")
                    }
                }

                Section {
                    if isBlocked {
                        Button("解除禁止新开仓") {
                            Task { await unblock() }
                        }
                        .disabled(busy)
                    } else {
                        Button("禁止新开仓", role: .destructive) {
                            confirmBlock = true
                        }
                        .disabled(busy)
                    }
                } footer: {
                    Text("禁止新开仓会持久化到服务端，重启后仍然生效，必须显式解除。")
                }

                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(IOSTheme.background)
            .navigationTitle("风控")
            .refreshable { await load() }
            .task { await load() }
            .confirmationDialog("确认禁止新开仓？", isPresented: $confirmBlock, titleVisibility: .visible) {
                Button("确认禁止", role: .destructive) {
                    Task { await block() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该操作会立即生效并持久化。")
            }
            .overlay {
                if busy { ProgressView().padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            async let overviewTask = api.getOverview()
            async let rulesTask = api.getRiskRules()
            overview = try await overviewTask
            rules = try await rulesTask
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func block() async {
        busy = true
        error = nil
        do {
            _ = try await api.blockNewEntries(reason: "ios_manual")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }

    private func unblock() async {
        busy = true
        error = nil
        do {
            _ = try await api.unblock()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
