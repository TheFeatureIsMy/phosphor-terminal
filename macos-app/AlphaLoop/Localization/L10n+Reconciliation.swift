// L10n+Reconciliation.swift — 对账总线文案

extension L10n {
    enum Reconciliation {
        static var title: String { zh("对账总线", en: "Reconciliation Bus") }
        static var refreshExchangeState: String { zh("刷新交易所状态", en: "Refresh Exchange State") }
        static var retryReconciliation: String { zh("重试对账", en: "Retry Reconciliation") }
        static var commandBus: String { zh("命令总线", en: "Command Bus") }
        static var reconciliationRuns: String { zh("对账运行", en: "Reconciliation Runs") }
        static var discrepancies: String { zh("差异数", en: "Discrepancies") }
        static var status: String { zh("状态", en: "Status") }
        static var runId: String { zh("运行 ID", en: "Run ID") }
        static var startedAt: String { zh("开始时间", en: "Started At") }
        static var completedAt: String { zh("完成时间", en: "Completed At") }
        static var retry: String { zh("重试", en: "Retry") }
        static var confirmRetry: String { zh("确认重试对账", en: "Confirm Retry Reconciliation") }
        static var confirmRetryMessage: String {
            zh("将重新触发对账运行 %@。当前模式: %@。",
               en: "Will re-trigger reconciliation run %@. Current mode: %@.")
        }
        static var noRuns: String { zh("暂无对账记录", en: "No reconciliation runs") }
        static var refreshing: String { zh("刷新中…", en: "Refreshing…") }

        // Additional strings found in ReconciliationBusView
        static var loadFailed: String { zh("加载失败", en: "Load Failed") }
        static var noData: String { zh("暂无对账数据", en: "No Reconciliation Data") }
        static var noRecordsYet: String { zh("尚未产生对账记录", en: "No reconciliation records have been generated yet") }
        static var reconciliationError: String { zh("对账异常", en: "Reconciliation Error") }
        static var reconciliationWarning: String { zh("对账状态警告", en: "Reconciliation Warning") }
        static var noCommandRecords: String { zh("暂无命令记录", en: "No command records") }
    }
}
