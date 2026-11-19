import SwiftUI

struct IOSStrategiesView: View {
    let client: LiveNetworkClient
    @State private var strategies: [StrategyV2] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && strategies.isEmpty {
                    ProgressView("加载策略…")
                } else if let error, strategies.isEmpty {
                    ContentUnavailableView("加载失败", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if strategies.isEmpty {
                    ContentUnavailableView("暂无策略", systemImage: "square.stack.3d.up")
                } else {
                    List(strategies) { strategy in
                        NavigationLink {
                            IOSStrategyDetailView(strategy: strategy, client: client)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(strategy.name).font(.headline)
                                Text(strategy.statusLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("策略")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            strategies = try await APIStrategiesV2(client: client).list()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct IOSStrategyDetailView: View {
    let strategy: StrategyV2
    let client: LiveNetworkClient

    @State private var versions: [StrategyVersionV2] = []
    @State private var isLoading = false
    @State private var runningVersion: String?
    @State private var runStatus: String?
    @State private var run: BacktestRunV2?
    @State private var error: String?

    var body: some View {
        List {
            Section("版本") {
                if isLoading && versions.isEmpty {
                    ProgressView()
                }
                ForEach(versions) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("v\(version.versionNo)").font(.headline)
                            Text(version.status).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            NavigationLink("画布") {
                                IOSCanvasScreen(
                                    title: "v\(version.versionNo) · 只读",
                                    dsl: version.ruleDsl
                                )
                            }
                            .buttonStyle(.bordered)

                            Button(runningVersion == version.id ? "运行中…" : "回测") {
                                Task { await runBacktest(version) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(runningVersion != nil)
                        }
                    }
                }
            }

            if let error {
                Section {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }

            if let run {
                Section("结果") {
                    LabeledContent("状态", value: run.status)
                    if run.status == "completed" {
                        LabeledContent("总收益", value: String(format: "%.2f%%", run.totalReturn))
                        LabeledContent("最大回撤", value: String(format: "%.2f%%", run.maxDrawdown))
                        LabeledContent("胜率", value: String(format: "%.1f%%", run.winRate * 100))
                        LabeledContent("交易数", value: "\(run.totalTrades)")
                        LabeledContent("Sharpe", value: String(format: "%.2f", run.sharpeRatio))
                    }
                }
            } else if let runStatus {
                Section("结果") {
                    LabeledContent("命令状态", value: runStatus)
                }
            }
        }
        .navigationTitle(strategy.name)
        .task { await loadVersions() }
    }

    private func loadVersions() async {
        isLoading = true
        do {
            versions = try await APIStrategiesV2(client: client).listVersions(strategyId: strategy.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func runBacktest(_ version: StrategyVersionV2) async {
        runningVersion = version.id
        run = nil
        runStatus = nil
        error = nil
        let symbols = (version.ruleDsl["symbols"]?.value as? [String]) ?? ["BTC/USDT"]
        do {
            let response = try await client.startBacktestV2(
                dsl: version.ruleDsl,
                timerange: Self.last90Days(),
                symbols: symbols,
                initialCapital: 10000,
                strategyId: 0,
                strategyVersionId: version.id
            )
            runStatus = response.status
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                let status = try await client.backtestStatusV2(commandId: response.commandId)
                runStatus = status.commandStatus
                if let backtest = status.backtestRun {
                    run = backtest
                }
                if ["succeeded", "failed", "timeout", "cancelled"].contains(status.commandStatus) {
                    break
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        runningVersion = nil
    }

    private static func last90Days() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let end = Date()
        let start = Calendar(identifier: .gregorian).date(byAdding: .day, value: -90, to: end) ?? end
        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }
}
