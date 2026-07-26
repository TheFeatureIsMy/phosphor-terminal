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

        // Service Management
        static var serviceManagement: String { zh("服务管理", en: "Service Management") }
        static var serviceStatus: String { zh("服务状态", en: "Service Status") }
        static var allServicesHealthy: String { zh("所有服务正常运行", en: "All Services Healthy") }
        static var someServicesDegraded: String { zh("部分服务异常", en: "Some Services Degraded") }
        static var serviceError: String { zh("服务异常", en: "Service Error") }
        static var backendAPI: String { zh("后端 API", en: "Backend API") }
        static var database: String { zh("数据库", en: "Database") }
        static var redisCache: String { zh("Redis 缓存", en: "Redis Cache") }
        static var connected: String { zh("已连接", en: "Connected") }
        static var disconnected: String { zh("未连接", en: "Disconnected") }
        static var configured: String { zh("已配置", en: "Configured") }
        static var notConfigured: String { zh("未配置", en: "Not Configured") }
        static var noStartStopButtons: String { zh("服务通过 Docker Compose 或系统服务管理，不支持从 UI 启停", en: "Services are managed via Docker Compose or system services; start/stop from UI is not supported") }
    }
}
