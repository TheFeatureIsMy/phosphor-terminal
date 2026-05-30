// SettingsState.swift — 应用设置状态
// 替代 Zustand settings-store.ts
// 支持后端云端持久化（/auth/settings）

import SwiftUI

@MainActor
@Observable
final class SettingsState {
    // 交易所配置
    var exchange: Exchange = .binance
    var tradingMode: TradingMode = .spot
    var apiKey: String = ""
    var apiSecret: String = ""
    var dryRun: Bool = true

    // 风险参数
    var maxSingleLoss: Double = 5.0
    var maxDrawdown: Double = 15.0
    var dailyDrawdown: Double = 8.0
    var maxPositionSize: Double = 20.0
    var correlatedGroupLimit: Int = 3
    var correlationThreshold: Double = 0.85
    var autoPause: Bool = true

    // 通知配置
    var telegramBotToken: String = ""
    var telegramChatId: String = ""
    var notifyRiskEvents: Bool = true
    var notifyTradeExecuted: Bool = true
    var notifyDailySummary: Bool = true
    var notifySystemAlerts: Bool = true

    // 后端同步字段（对应 /auth/settings）
    var riskTolerance: String = "medium"

    // MARK: - 后端持久化

    private var settingsAPI: APISettings?
    private var saveTask: Task<Void, Never>?

    /// 注入网络客户端并从后端加载设置
    func configure(client: any NetworkClientProtocol) {
        self.settingsAPI = APISettings(client: client)
        Task { await loadFromBackend() }
    }

    /// 从后端拉取设置，覆盖本地对应字段
    func loadFromBackend() async {
        guard let api = settingsAPI else { return }
        do {
            let settings = try await api.fetch()
            self.exchange = Exchange(rawValue: settings.defaultExchange) ?? self.exchange
            self.tradingMode = TradingMode(rawValue: settings.defaultMarket) ?? self.tradingMode
            self.notifyRiskEvents = settings.notificationsEnabled
            self.riskTolerance = settings.riskTolerance
        } catch {
            // 离线或后端不可用时使用本地默认值，不中断用户操作
        }
    }

    /// 防抖保存：调用后 2 秒内无新变更才实际写入后端
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await saveToBackend()
        }
    }

    /// 将当前设置推送到后端
    func saveToBackend() async {
        guard let api = settingsAPI else { return }
        let body = UserSettingsUpdateBody(
            theme: nil,       // theme 由 ThemeManager 管理，暂不同步
            language: nil,    // 语言固定 zh-CN
            notificationsEnabled: notifyRiskEvents,
            defaultExchange: exchange.rawValue,
            defaultMarket: tradingMode.rawValue,
            riskTolerance: riskTolerance
        )
        _ = try? await api.update(body)
    }
}
