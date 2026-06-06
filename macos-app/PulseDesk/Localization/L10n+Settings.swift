// L10n+Settings.swift — 设置页文案

extension L10n {
    enum Settings {
        static var title: String { zh("设置", en: "Settings") }

        // Tabs
        static var tabGeneral: String { zh("通用", en: "General") }
        static var tabTrading: String { zh("交易", en: "Trading") }
        static var tabNotifications: String { zh("通知", en: "Notifications") }
        static var tabAPI: String { zh("API", en: "API") }
        static var tabServices: String { zh("服务", en: "Services") }
        static var tabData: String { zh("数据", en: "Data") }
        static var tabAdvanced: String { zh("高级", en: "Advanced") }

        // General
        static var language: String { zh("语言", en: "Language") }
        static var profile: String { zh("个人资料", en: "Profile") }
        static var username: String { zh("用户名", en: "Username") }
        static var email: String { zh("邮箱", en: "Email") }
        static var role: String { zh("角色", en: "Role") }
        static var timezone: String { zh("时区", en: "Timezone") }
        static var twoFactor: String { zh("双因素认证", en: "2FA") }

        // Trading / Exchange
        static var exchangeConfig: String { zh("交易所配置", en: "Exchange Configuration") }
        static var exchange: String { zh("交易所", en: "Exchange") }
        static var tradingMode: String { zh("交易模式", en: "Trading Mode") }
        static var apiKey: String { zh("API Key", en: "API Key") }
        static var apiSecret: String { zh("API Secret", en: "API Secret") }
        static var dryRun: String { zh("模拟模式", en: "Dry Run Mode") }
        static var spot: String { zh("现货", en: "Spot") }
        static var futures: String { zh("合约", en: "Futures") }
        static var margin: String { zh("杠杆", en: "Margin") }

        // Risk
        static var riskParams: String { zh("风控参数", en: "Risk Parameters") }
        static var maxSingleLoss: String { zh("单笔最大亏损", en: "Max Single Loss") }
        static var maxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var dailyDrawdown: String { zh("日内回撤", en: "Daily Drawdown") }
        static var maxPositionSize: String { zh("最大仓位", en: "Max Position Size") }
        static var correlatedGroupLimit: String { zh("相关组上限", en: "Correlated Group Limit") }
        static var correlationThreshold: String { zh("相关性阈值", en: "Correlation Threshold") }
        static var autoPause: String { zh("自动暂停", en: "Auto Pause") }

        // Notifications
        static var notificationSettings: String { zh("通知设置", en: "Notification Settings") }
        static var telegramBotToken: String { zh("Telegram Bot Token", en: "Telegram Bot Token") }
        static var telegramChatId: String { zh("Telegram Chat ID", en: "Telegram Chat ID") }
        static var notifyRisk: String { zh("风控事件通知", en: "Risk Event Notifications") }
        static var notifyTrade: String { zh("交易执行通知", en: "Trade Execution Notifications") }
        static var notifyDaily: String { zh("每日摘要", en: "Daily Summary") }
        static var notifySystem: String { zh("系统警报", en: "System Alerts") }

        // API Keys
        static var apiKeys: String { zh("API 密钥", en: "API Keys") }
        static var binance: String { zh("Binance", en: "Binance") }
        static var telegramBot: String { zh("Telegram Bot", en: "Telegram Bot") }
        static var openAI: String { zh("OpenAI", en: "OpenAI") }

        // MCP
        static var mcpServer: String { zh("MCP 服务器", en: "MCP Server") }
        static var rotateToken: String { zh("轮换 Token", en: "Rotate Token") }
        static var auditLog: String { zh("审计日志", en: "Audit Log") }
        static var bindAddress: String { zh("绑定地址", en: "Bind Address") }
        static var totalRequests: String { zh("总请求数", en: "Total Requests") }
        static var lastRequest: String { zh("最后请求", en: "Last Request") }

        // Data
        static var dataVacuum: String { zh("数据清理", en: "Data Cleanup") }
        static var runVacuum: String { zh("执行清理", en: "Run Cleanup") }
        static var vacuumHistory: String { zh("清理历史", en: "Cleanup History") }
        static var signalsScanned: String { zh("扫描信号数", en: "Signals Scanned") }
        static var signalsArchived: String { zh("归档信号数", en: "Signals Archived") }

        // Danger
        static var dangerZone: String { zh("危险操作", en: "Danger Zone") }
        static var exportData: String { zh("导出数据", en: "Export Data") }
        static var deleteAccount: String { zh("删除账户", en: "Delete Account") }
        static var deleteAccountWarning: String { zh("此操作不可撤销，所有数据将被永久删除。", en: "This action cannot be undone. All data will be permanently deleted.") }
    }
}
