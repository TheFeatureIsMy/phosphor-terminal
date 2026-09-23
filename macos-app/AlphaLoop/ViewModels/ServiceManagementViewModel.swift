// ServiceManagementViewModel.swift - 服务管理视图模型

import SwiftUI

@Observable
@MainActor
final class ServiceManagementViewModel {
    var serviceStatus: ServiceStatusResponse?
    var isLoading = false
    var error: String?

    private let api: APIServiceManagement

    init(client: any NetworkClientProtocol) {
        self.api = APIServiceManagement(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            serviceStatus = try await api.getServiceStatus()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var services: [ServiceStatusItem] {
       guard let status = serviceStatus else { return [] }
        return status.services
   }

    var state: String { serviceStatus?.state ?? "unknown" }
    var healthyCount: Int { services.filter { isHealthy($0) }.count }
    var errorCount: Int { services.filter { isError($0) }.count }

    func isHealthy(_ s: ServiceStatusItem) -> Bool {
        s.status == "connected" || s.status == "configured" || s.status == "ok" || s.status == "available"
    }

    func isError(_ s: ServiceStatusItem) -> Bool {
        s.status == "disconnected" || s.status == "error"
    }

    func statusLabel(_ s: ServiceStatusItem) -> String {
        switch s.status {
        case "connected": return L10n.zh("已连接", en: "Connected")
        case "disconnected": return L10n.zh("未连接", en: "Disconnected")
        case "configured": return L10n.zh("已配置", en: "Configured")
        case "not_configured": return L10n.zh("未配置", en: "Not Configured")
        case "ok": return L10n.zh("正常", en: "OK")
        case "available": return L10n.zh("可用", en: "Available")
        case "error": return L10n.zh("异常", en: "Error")
        default: return s.status
        }
    }

    func statusColor(_ s: ServiceStatusItem) -> Color {
        if isHealthy(s) { return PulseColors.success }
        if isError(s) { return PulseColors.danger }
        return PulseColors.warning
    }

    func displayName(_ name: String) -> String {
        switch name {
        case "backend": return L10n.zh("后端 API", en: "Backend API")
        case "database": return L10n.zh("数据库", en: "Database")
        case "redis": return L10n.zh("Redis 缓存", en: "Redis Cache")
        case "freqtrade": return L10n.zh("Freqtrade", en: "Freqtrade")
        case "ollama": return L10n.zh("Ollama (本地 LLM)", en: "Ollama (Local LLM)")
        case "openai": return L10n.zh("OpenAI", en: "OpenAI")
        case "anthropic": return L10n.zh("Anthropic", en: "Anthropic")
        case "deepseek": return L10n.zh("DeepSeek", en: "DeepSeek")
        case "telegram": return L10n.zh("Telegram 通知", en: "Telegram Notifications")
        default: return name.capitalized
        }
    }

    func iconFor(_ name: String) -> String {
        switch name {
        case "backend": return "server.rack"
        case "database": return "cylinder.split.1x2"
        case "redis": return "internaldrive"
        case "freqtrade": return "chart.line.uptrend.xyaxis"
        case "ollama": return "cpu"
        case "openai", "anthropic", "deepseek": return "brain"
        case "telegram": return "paperplane"
        default: return "gearshape"
        }
    }

    // MARK: - Add Provider

    var showAddSheet = false
    var newCategory = "llm"
    var newProviderName = ""
    var newInstanceName = ""
    var newApiKey = ""
    var isCreating = false

    func createProvider() async {
        guard !newProviderName.isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let body = ProviderConfigPayload(
                category: newCategory,
                providerName: newProviderName,
                instanceName: newInstanceName.isEmpty ? nil : newInstanceName,
                enabled: true,
                priority: 100,
                config: [:],
                credentials: newApiKey.isEmpty ? nil : ["api_key": newApiKey]
            )
            let providerAPI = APIAIProviders(client: api.client)
            _ = try await providerAPI.updateConfig(body: body)
            resetForm()
            showAddSheet = false
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resetForm() {
        newProviderName = ""
        newInstanceName = ""
        newApiKey = ""
        newCategory = "llm"
    }
}
