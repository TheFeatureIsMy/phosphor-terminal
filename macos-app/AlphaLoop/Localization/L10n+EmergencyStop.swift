// L10n+EmergencyStop.swift — 紧急停止/恢复文案

extension L10n {
    enum EmergencyStop {
        static var emergencyStop: String { zh("紧急停止", en: "EMERGENCY STOP") }
        static var resume: String { zh("恢复运行", en: "RESUME") }
        static var confirmStop: String { zh("确认紧急停止", en: "Confirm Emergency Stop") }
        static var confirmStopMessage: String {
            zh("此操作将立即停止所有策略运行。受影响运行数: %d。当前模式: %@。此操作不可逆。",
               en: "This will immediately stop all strategy runs. Affected runs: %d. Current mode: %@. This action is irreversible.")
        }
        static var confirmResume: String { zh("确认恢复运行", en: "Confirm Resume") }
        static var confirmResumeMessage: String {
            zh("将解除紧急锁定并恢复策略运行。当前模式: %@。",
               en: "This will release the emergency lock and resume strategy runs. Current mode: %@.")
        }
        static var affectedRuns: String { zh("受影响运行数", en: "Affected runs") }
        static var thisActionIrreversible: String { zh("此操作不可逆", en: "This action is irreversible") }
        static var liveModeWarning: String { zh("实盘模式 — 操作将影响真实资金", en: "LIVE mode — real funds at risk") }
        static var paperModeNote: String { zh("模拟模式", en: "Paper mode") }
        static var emergencyLocked: String { zh("紧急锁定中", en: "EMERGENCY LOCKED") }
        static var strategiesRunning: String { zh("个策略运行中", en: "strategies running") }
    }
}
