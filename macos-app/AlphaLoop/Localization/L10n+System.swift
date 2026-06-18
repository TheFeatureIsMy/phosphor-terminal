// L10n+System.swift — 系统级文案（连接状态、错误页等）

extension L10n {
    enum System {
        static var backendUnavailable: String { zh("后端未连接", en: "Backend Unavailable") }
        static var backendUnavailableDescription: String {
            zh("无法连接到 AlphaLoop 后端服务。请确保后端正在运行（默认端口 8000）。",
               en: "Unable to connect to the AlphaLoop backend service. Please ensure the backend is running (default port 8000).")
        }
        static var retryConnection: String { zh("重试连接", en: "Retry Connection") }

        static var dataSourceUnavailable: String { zh("数据源暂不可用", en: "Data Source Unavailable") }
        static var dataSourceUnavailableDescription: String {
            zh("后端数据源暂时不可用，部分数据可能为空。请稍后重试或检查数据源配置。",
               en: "Backend data source is temporarily unavailable. Some data may be empty. Please retry later or check data source configuration.")
        }
        static var dataSourceUnavailableDetails: String { zh("原因代码", en: "Reason Codes") }
    }
}
