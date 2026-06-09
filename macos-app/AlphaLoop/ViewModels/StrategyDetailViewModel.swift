// StrategyDetailViewModel.swift — v2.5 策略详情 + 版本管理 + DSL 验证 + 回测

import SwiftUI

@Observable
@MainActor
final class StrategyDetailViewModel {
    // Strategy
    var strategy: StrategyV2?
    var mtfGuards: [MTFGuardInfo] = []
    var versions: [StrategyVersionV2] = []
    var isLoading = true
    var error: String?

    // DSL Editor
    var dslText: String = ""
    var validationReport: DSLValidationReport?
    var isValidating = false
    var isSavingVersion = false
    var versionSaveSuccess = false

    // Backtest
    var backtestTimerange = "20250101-20251231"
    var backtestCapital: Double = 10000
    var backtestSymbols: Set<String> = ["BTC/USDT"]
    var backtestCommandId: String?
    var backtestStatus: BacktestStatusV2?
    var backtestRun: BacktestRunV2?
    var backtestHistory: [BacktestRunV2] = []
    var isStartingBacktest = false
    var isPollingBacktest = false
    var backtestError: String?

    var errorHandler: ErrorHandler?

    private let api: APIStrategiesV2
    private let mtfGuardAPI: APIMTFGuard
    nonisolated(unsafe) private var pollTimer: Timer?
    let strategyId: String

    init(strategyId: String, client: NetworkClientProtocol) {
        self.strategyId = strategyId
        self.api = APIStrategiesV2(client: client)
        self.mtfGuardAPI = APIMTFGuard(client: client)
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil
        do {
            async let s = api.get(id: strategyId)
            async let v = api.listVersions(strategyId: strategyId)
            strategy = try await s
            versions = try await v

            mtfGuards = (try? await mtfGuardAPI.getGuardState(strategyId: strategyId, symbol: "BTC/USDT"))?.guards ?? []
            if let latest = versions.first {
                loadDSLFromVersion(latest)
            } else {
                loadDefaultDSL()
            }
        } catch {
            errorHandler?.handle(error, context: "加载策略详情")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadDSLFromVersion(_ version: StrategyVersionV2) {
        do {
            let data = try JSONSerialization.data(withJSONObject: encodableDict(version.ruleDsl), options: [.prettyPrinted, .sortedKeys])
            dslText = String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            dslText = "{}"
        }
        validationReport = nil
    }

    private func loadDefaultDSL() {
        dslText = """
        {
          "schema_version": "2.5",
          "timeframe": "1h",
          "symbols": ["BTC/USDT"],
          "entry": {
            "logic": "AND",
            "rules": [
              {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30
              }
            ]
          },
          "exit": {
            "logic": "OR",
            "rules": [
              {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70
              }
            ]
          },
          "filters": [],
          "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
          "risk": {"stoploss": -0.05, "max_open_trades": 3},
          "metadata": {}
        }
        """
    }

    // MARK: - DSL Validation

    func validateDSL() async {
        guard let dsl = parseDSLText() else {
            validationReport = DSLValidationReport(
                valid: false, errorCount: 1, warningCount: 0,
                safeHoldRequired: false, safeHoldReasons: [],
                errors: [DSLValidationError(code: "JSON_PARSE_ERROR", path: "", message: "JSON 格式错误，请检查语法", severity: "error")],
                warnings: []
            )
            return
        }
        isValidating = true
        do {
            nonisolated(unsafe) let safeDsl = dsl
            validationReport = try await api.validateDSL(safeDsl)
        } catch {
            errorHandler?.handle(error, context: "验证 DSL")
            self.error = error.localizedDescription
        }
        isValidating = false
    }

    // MARK: - Create Version

    func saveVersion() async {
        guard let dsl = parseDSLText() else {
            error = "JSON 格式错误"
            return
        }
        isSavingVersion = true
        versionSaveSuccess = false
        do {
            nonisolated(unsafe) let safeDsl2 = dsl
            let version = try await api.createVersion(strategyId: strategyId, ruleDsl: safeDsl2)
            versions.insert(version, at: 0)
            versionSaveSuccess = true
            validationReport = nil
        } catch {
            errorHandler?.handle(error, context: "保存版本")
            self.error = error.localizedDescription
        }
        isSavingVersion = false
    }

    // MARK: - Backtest

    func startBacktest() async {
        guard let dsl = parseDSLText() else {
            backtestError = "JSON 格式错误"
            return
        }
        isStartingBacktest = true
        backtestError = nil
        backtestRun = nil
        backtestStatus = nil
        do {
            nonisolated(unsafe) let safeDsl3 = dsl
            let resp = try await api.startBacktest(
                dsl: safeDsl3,
                timerange: backtestTimerange,
                symbols: Array(backtestSymbols),
                initialCapital: backtestCapital,
                strategyVersionId: versions.first?.id
            )
            backtestCommandId = resp.commandId
            startPolling()
        } catch {
            errorHandler?.handle(error, context: "启动回测")
            backtestError = error.localizedDescription
        }
        isStartingBacktest = false
    }

    func startPolling() {
        isPollingBacktest = true
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollBacktestStatus()
            }
        }
    }

    func pollBacktestStatus() async {
        guard let cmdId = backtestCommandId else { return }
        do {
            let status = try await api.backtestStatus(commandId: cmdId)
            backtestStatus = status
            if let run = status.backtestRun {
                backtestRun = run
            }
            if status.commandStatus == "completed" || status.commandStatus == "failed" {
                stopPolling()
                if status.commandStatus == "failed" {
                    backtestError = status.errorMessage ?? "回测失败"
                }
            }
        } catch {
            // Polling error — don't stop, just retry
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPollingBacktest = false
    }

    func loadBacktestHistory() async {
        do {
            backtestHistory = try await api.listBacktests()
        } catch {}
    }

    // MARK: - Helpers

    private func parseDSLText() -> [String: Any]? {
        guard let data = dslText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private func encodableDict(_ dict: [String: AnyCodable]) -> [String: Any] {
        dict.mapValues { $0.value }
    }

    var canSaveVersion: Bool {
        validationReport?.valid == true
    }

    var canStartBacktest: Bool {
        !backtestTimerange.isEmpty && backtestCapital > 0 && !backtestSymbols.isEmpty && !isPollingBacktest
    }

    var latestVersion: StrategyVersionV2? {
        versions.first
    }
}
