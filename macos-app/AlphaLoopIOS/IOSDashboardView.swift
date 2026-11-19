import SwiftUI

struct IOSDashboardView: View {
    let client: LiveNetworkClient
    let onLogout: () -> Void

    @State private var viewModel: DashboardViewModel
    @State private var refreshID = UUID()

    init(client: LiveNetworkClient, onLogout: @escaping () -> Void) {
        self.client = client
        self.onLogout = onLogout
        _viewModel = State(initialValue: DashboardViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.account == nil {
                    ProgressView("加载中…")
                } else if viewModel.isDataSourceUnavailable && viewModel.account == nil {
                    ContentUnavailableView(
                        "数据源不可用",
                        systemImage: "exclamationmark.triangle",
                        description: Text(viewModel.reasonCodes.joined(separator: ", "))
                    )
                } else {
                    content
                }
            }
            .navigationTitle("总览")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出", role: .destructive, action: onLogout)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task(id: refreshID) {
                await viewModel.load()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let account = viewModel.account {
                    card {
                        Text(account.currency)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(account.equity, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        HStack(spacing: 16) {
                            metric("今日", account.todayPnlPct, suffix: "%")
                            metric("本周", account.weekPnlPct, suffix: "%")
                            metric("回撤", account.maxDrawdownPct, suffix: "%")
                        }
                        if let sharpe = account.sharpeRatio {
                            Text("Sharpe \(sharpe, format: .number.precision(.fractionLength(2)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let runtime = viewModel.runtime {
                    card {
                        Text("运行状态").font(.headline)
                        HStack {
                            metric("策略", Double(runtime.runningStrategies))
                            metric("持仓", Double(runtime.openPositions))
                            metric("挂单", Double(runtime.pendingOrders))
                            metric("对账", Double(runtime.reconcilingCount))
                        }
                    }
                }

                if let risk = viewModel.risk {
                    card {
                        Text("风控").font(.headline)
                        HStack {
                            Text(risk.globalState)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(risk.emergencyLocked ? "已锁定" : "正常")
                                .font(.caption)
                                .foregroundStyle(risk.emergencyLocked ? .red : .secondary)
                        }
                    }
                }

                card {
                    Text("持仓 (\(viewModel.positions.count))").font(.headline)
                    if viewModel.positions.isEmpty {
                        Text("暂无持仓").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.positions) { position in
                            HStack {
                                Text(position.symbol).font(.subheadline.monospaced())
                                Spacer()
                                Text(position.pnlPct, format: .number.precision(.fractionLength(2)))
                                    .foregroundStyle(position.pnl >= 0 ? .green : .red)
                                    .font(.subheadline.monospaced())
                            }
                        }
                    }
                }

                if let error = viewModel.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ label: String, _ value: Double, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(value, specifier: "%.2f")\(suffix)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(value < 0 ? .red : .primary)
        }
    }
}
