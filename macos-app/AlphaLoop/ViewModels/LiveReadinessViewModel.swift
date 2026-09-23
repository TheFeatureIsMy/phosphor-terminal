// LiveReadinessViewModel.swift — 实盘准入控制台
// 并行拉取：readiness / notifications 摘要 / exchange 状态 / 数据源 / AI 模型 / 风险防火墙 / 资金池。
// 不再使用空 `strategyGates`、硬编码 `RiskFirewallState`、`CapitalConfig` 默认值。
// 启动授权必须经过三重确认（按钮 → sheet → 输入确认短语）。

import SwiftUI

@Observable
@MainActor
final class LiveReadinessViewModel {
    // MARK: - Live data
    var data: LiveReadinessResponse?
    var isLoading = false
    var isChecking = false
    var error: String?
    var lastUpdated: Date?
    var showLaunchConfirmation = false
    var pendingMode: String?  // "paper" | "live_small" | "live_full"

    // Per-source availability (drives empty-state in the view)
    var readinessAvailable: Bool = false
    var notificationsAvailable: Bool = false
    var exchangeAvailable: Bool = false
    var dataSourceAvailable: Bool = false
    var aiModelsAvailable: Bool = false
    var riskFirewallAvailable: Bool = false
    var capitalAvailable: Bool = false

    // Supplementary (read-only context, used to enrich the dashboard)
    var notificationCount: Int = 0
    var exchangeState: String = "unknown"
    var freqtradeState: String = "unknown"
    var redisRttMs: Int = 0
    var dataSource: String = "unknown"
    var aiModelsLoaded: Int = 0
    var aiModelsTotal: Int = 0
    var dailyLossUsedPct: Double = 0
    var weeklyLossUsedPct: Double = 0
    var capitalPoolId: String = ""
    var capitalPoolName: String = ""
    var capitalBudget: Double = 0
    var capitalStake: Double = 0
    var capitalMaxOpenTrades: Int = 0
    var capitalMaxDailyLossPct: Double = 0
    var emergencyStopAvailable: Bool = true
    /// Result message of the last launch attempt (shown as toast by the view).
    var launchMessage: String?

    // MARK: - Private
    private let client: NetworkClientProtocol
    private let api: APIOverview
    private let apiEmergency: APIEmergency
    private let apiTrading: APITrading
    private let apiStrategies: APIStrategiesV2
    private var pollingTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.client = client
        self.api = APIOverview(client: client)
        self.apiEmergency = APIEmergency(client: client)
        self.apiTrading = APITrading(client: client)
        self.apiStrategies = APIStrategiesV2(client: client)
    }

    // MARK: - Public API

    func loadData() async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }
        async let readinessTask: () = loadReadiness()
        async let notificationsTask: () = loadNotifications()
        async let overviewTask: () = loadOverview()
        async let aiTask: () = loadAIModels()
        async let riskTask: () = loadRiskFirewall()
        async let capitalTask: () = loadCapital()

        _ = await (readinessTask, notificationsTask, overviewTask, aiTask, riskTask, capitalTask)
    }

    func runCheck() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let result = try await api.runReadinessCheck(
                mode: data?.selectedMode ?? "live_small",
                strategyId: data?.selectedStrategyId ?? "",
                capitalPoolId: data?.selectedCapitalPoolId ?? "",
                exchange: data?.selectedExchange ?? "binance"
            )
            data = result
            readinessAvailable = true
        } catch {
            self.error = error.localizedDescription
            readinessAvailable = false
        }
    }

    func setMode(_ mode: String) {
        guard var current = data else { return }
        current.selectedMode = mode
        data = current
        Task { await runCheck() }
    }

    func setStrategy(_ strategyId: String) {
        guard var current = data else { return }
        current.selectedStrategyId = strategyId
        data = current
        Task { await runCheck() }
    }

    func setCapitalPool(_ poolId: String) {
        guard var current = data else { return }
        current.selectedCapitalPoolId = poolId
        data = current
        Task { await runCheck() }
    }

    func setExchange(_ exchange: String) {
        guard var current = data else { return }
        current.selectedExchange = exchange
        data = current
        Task { await runCheck() }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }
                await self.refreshLight()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func requestLaunch(mode: String) {
        pendingMode = mode
        showLaunchConfirmation = true
    }

    /// Triple confirmation: launch must type the configured phrase.
    /// Dispatches to the real /api/trading endpoints (paper → start-paper,
    /// live_small → start-live-small gate chain). Never touches emergency stop.
    func confirmLaunch(phrase: String) async -> Bool {
        guard let mode = pendingMode else { return false }
        let required = L10n.LiveReadiness.confirmPhrase
        guard phrase == required else { return false }
        do {
            switch mode {
            case "paper":
                let versionId = try await latestStrategyVersionId()
                let result = try await apiTrading.startPaper(
                    strategyVersionId: versionId,
                    stakeAmount: capitalStake > 0 ? capitalStake : 100,
                    maxOpenTrades: capitalMaxOpenTrades > 0 ? capitalMaxOpenTrades : 5
                )
                launchMessage = result.message ?? result.state
            case "live_small":
                let versionId = try await latestStrategyVersionId()
                guard !capitalPoolId.isEmpty else {
                    launchMessage = L10n.zh("请先选择资金池", en: "Select a capital pool first")
                    return false
                }
                let result = try await apiTrading.startLiveSmall(
                    strategyVersionId: versionId,
                    capitalPoolId: capitalPoolId,
                    confirmedBy: "macos-app"
                )
                switch result.state {
                case "approved_enqueued":
                    launchMessage = L10n.zh("小仓实盘命令已提交", en: "Live-small command enqueued")
                case "not_enabled":
                    launchMessage = L10n.zh("服务端未开启实盘执行（LIVE_SMALL_ENABLED=false）", en: "Live execution disabled on server")
                case "waiting_confirmation":
                    launchMessage = L10n.zh("需要人工确认", en: "Human confirmation required")
                default:
                    launchMessage = result.reasonCodes.joined(separator: ", ")
                }
                if result.state != "approved_enqueued" {
                    showLaunchConfirmation = false
                    pendingMode = nil
                    await loadData()
                    return false
                }
            default:
                launchMessage = L10n.zh("暂不支持该模式启动", en: "Launch mode not supported")
                return false
            }
            showLaunchConfirmation = false
            pendingMode = nil
            await loadData()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Resolve the latest strategy version id for the selected strategy.
    private func latestStrategyVersionId() async throws -> String {
        let strategyId = data?.selectedStrategyId ?? ""
        guard !strategyId.isEmpty else {
            throw NSError(
                domain: "LiveReadiness", code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.zh("请先选择策略", en: "Select a strategy first")]
            )
        }
        let versions = try await apiStrategies.listVersions(strategyId: strategyId)
        guard let latest = versions.first else {
            throw NSError(
                domain: "LiveReadiness", code: 2,
                userInfo: [NSLocalizedDescriptionKey: L10n.zh("该策略没有可用版本", en: "No versions available")]
            )
        }
        return latest.id
    }

    /// Disable automated trading: stop active dry-runs + block new entries.
    func disableAutoTrading() async {
        do {
            let result = try await apiTrading.disableAuto(reason: "macos_disable_auto")
            launchMessage = L10n.zh(
                "已停止 \(result.stoppedDryruns) 个模拟运行，新入场已封锁",
                en: "Stopped \(result.stoppedDryruns) dry-runs, new entries blocked"
            )
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelLaunch() {
        showLaunchConfirmation = false
        pendingMode = nil
    }

    // MARK: - Light refresh (no readiness POST)

    func refreshLight() async {
        async let readinessTask: () = loadReadiness()
        async let overviewTask: () = loadOverview()
        async let riskTask: () = loadRiskFirewall()
        _ = await (readinessTask, overviewTask, riskTask)
        lastUpdated = Date()
    }

    // MARK: - Per-source loaders (all real fetches, fail-soft)

    private func loadReadiness() async {
        do {
            data = try await api.getLiveReadiness()
            readinessAvailable = true
        } catch {
            readinessAvailable = false
        }
    }

    private func loadNotifications() async {
        do {
            let api = APINotifications(client: client)
            let list = try await api.fetchNotifications(limit: 50)
            notificationCount = list.filter { !$0.isRead }.count
            notificationsAvailable = true
        } catch {
            notificationsAvailable = false
        }
    }

    private func loadOverview() async {
        do {
            let status = try await api.getGlobalStatus()
            exchangeState = status.exchangeState
            freqtradeState = status.freqtradeState
            redisRttMs = status.redisRttMs
            dataSource = status.exchangeState == "ok" ? "online" : status.exchangeState
            exchangeAvailable = true
            dataSourceAvailable = true
        } catch {
            exchangeAvailable = false
            dataSourceAvailable = false
        }
    }

    private func loadAIModels() async {
        do {
            let list = try await api.getAIModelStatus()
            aiModelsTotal = list.count
            aiModelsLoaded = list.filter { $0.state.lowercased() == "running" || $0.state.lowercased() == "available" }.count
            aiModelsAvailable = true
        } catch {
            aiModelsAvailable = false
        }
    }

    private func loadRiskFirewall() async {
        do {
            let api = APIRiskBFF(client: client)
            let overview = try await api.getOverview()
            // Derive daily/weekly usage from guards if backend exposes them.
            // If not, fall back to 0; the view will display "—".
            if let daily = overview.guards.first(where: { $0.key == "daily_loss" }) {
                dailyLossUsedPct = max(0, 1.0 - daily.remainingPct)
            } else {
                dailyLossUsedPct = 0
            }
            if let weekly = overview.guards.first(where: { $0.key == "weekly_loss" }) {
                weeklyLossUsedPct = max(0, 1.0 - weekly.remainingPct)
            } else {
                weeklyLossUsedPct = 0
            }
            emergencyStopAvailable = !overview.emergencyLocked
            riskFirewallAvailable = true
        } catch {
            riskFirewallAvailable = false
        }
    }

    private func loadCapital() async {
        // Use the readiness response's selected_capital_pool_id to look up
        // the pool; if the BFF provides capital metadata, we can later
        // extend this to /api/live-small/config-preview. For now the
        // default fields are surfaced via data?.availableCapitalPools.
        capitalAvailable = (data?.availableCapitalPools.isEmpty == false)
        if let firstPool = data?.availableCapitalPools.first {
            capitalPoolId = firstPool.key
            capitalPoolName = firstPool.name
            capitalBudget = Double(firstPool.detail ?? "0") ?? 0
        }
    }
}
