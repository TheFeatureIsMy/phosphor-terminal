// L10n+Execution.swift — 执行中心文案

extension L10n {
    enum Execution {
        // Execution Center
        static var loadFailed: String { zh("加载失败", en: "Load Failed") }
        static var noSessions: String { zh("暂无执行会话", en: "No Execution Sessions") }
        static var noSessionsDesc: String { zh("尚未启动任何策略会话", en: "No strategy sessions have been started") }

        // State banner
        static var systemError: String { zh("系统异常", en: "System Error") }
        static var engineError: String { zh("执行引擎异常", en: "Execution Engine Error") }

        // Summary cards
        static var runningSessions: String { zh("运行会话", en: "Sessions") }
        static var positions: String { zh("持仓", en: "Positions") }
        static var pendingOrders: String { zh("挂单", en: "Pending") }
        static var latency: String { zh("延迟", en: "Latency") }

        // Emergency stop
        static var emergencyStop: String { zh("紧急停止", en: "Emergency Stop") }
        static var confirmEmergencyStop: String { zh("确认紧急停止", en: "Confirm Emergency Stop") }
        static var emergencyStopWarning: String { zh("将立即停止所有运行中的策略会话并取消所有挂单。此操作不可撤销。", en: "This will immediately stop all running strategy sessions and cancel all pending orders. This action cannot be undone.") }
        static var confirmStop: String { zh("确认停止", en: "Confirm Stop") }

        // Session table
        static var executionSessions: String { zh("执行会话", en: "Execution Sessions") }
        static var noSessionsEmpty: String { zh("暂无会话", en: "No Sessions") }
        static var noSessionsEmptyDesc: String { zh("当前没有运行中的策略会话", en: "No strategy sessions currently running") }
        static func positionsCount(_ n: Int) -> String { zh("\(n) 持仓", en: "\(n) Position\(n == 1 ? "" : "s")") }
        static func pendingCount(_ n: Int) -> String { zh("\(n) 挂单", en: "\(n) Pending") }

        // Orders & Positions View
        static var orders: String { zh("订单", en: "Orders") }
        static var positionsTab: String { zh("持仓", en: "Positions") }

        // State banners (Orders/Positions)
        static var connectionError: String { zh("连接异常", en: "Connection Error") }
        static var statusError: String { zh("状态异常", en: "Status Error") }

        // Orders section
        static var noOrders: String { zh("暂无订单", en: "No Orders") }
        static var noOrdersDesc: String { zh("当前没有活跃订单", en: "No active orders") }
        static var noPositions: String { zh("暂无持仓", en: "No Positions") }
        static var noPositionsDesc: String { zh("当前没有未平仓头寸", en: "No open positions") }

        // Position labels
        static var entryPrice: String { zh("均价", en: "Entry") }
        static var currentPrice: String { zh("现价", en: "Current") }
        static var stopLoss: String { zh("止损", en: "SL") }

        // No data
        static var noData: String { zh("暂无数据", en: "No Data") }
        static var noDataDesc: String { zh("当前没有订单或持仓数据", en: "No order or position data available") }

        // Cancel / Close actions
        static var cancelAllOrders: String { zh("撤销全部挂单", en: "Cancel All Orders") }
        static var forceCloseAll: String { zh("强制平仓全部", en: "Force Close All") }
        static var cancelOrder: String { zh("撤销", en: "Cancel") }
        static var closePosition: String { zh("平仓", en: "Close") }
        static var confirmCancelAll: String { zh("确认撤销全部挂单", en: "Confirm Cancel All Orders") }
        static var confirmCancelAllMessage: String {
            zh("将撤销 %d 笔挂单。当前模式: %@。此操作不可逆。",
               en: "Will cancel %d pending orders. Current mode: %@. This action is irreversible.")
        }
        static var confirmForceCloseAll: String { zh("确认强制平仓全部", en: "Confirm Force Close All") }
        static var confirmForceCloseAllMessage: String {
            zh("将强制平仓 %d 个持仓。当前模式: %@。此操作不可逆。",
               en: "Will force-close %d positions. Current mode: %@. This action is irreversible.")
        }
        static var confirmCancelOrder: String { zh("确认撤销订单", en: "Confirm Cancel Order") }
        static var confirmCancelOrderMessage: String {
            zh("将撤销订单 %@。当前模式: %@。",
               en: "Will cancel order %@. Current mode: %@.")
        }
        static var confirmClosePosition: String { zh("确认平仓", en: "Confirm Close Position") }
        static var confirmClosePositionMessage: String {
            zh("将平仓持仓 %@。当前模式: %@。",
               en: "Will close position %@. Current mode: %@.")
        }
        static var affectedOrders: String { zh("受影响订单数", en: "Affected orders") }
        static var affectedPositions: String { zh("受影响持仓数", en: "Affected positions") }
    }
}
