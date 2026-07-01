// ManipulationViewModel.swift — 操纵雷达视图模型
// 管理雷达概览、聚焦案例详情、策略联动、相似案例、告警流、WS 实时推送

import SwiftUI

@Observable
@MainActor
final class ManipulationViewModel {
    var radarOverview: ManipulationRadarOverview?
    var alerts: [ManipulationAlertItem] = []
    var userProfile: String = "conservative" // 仍传给 /signals，UI 不再暴露切换
    var scanSymbol: String = ""

    // 聚焦 case 状态
    var focusedCaseId: String?
    var focusedDetail: ManipulationCaseDetail?
    var strategyImpact: StrategyImpactResponse?
    var similar: SimilarCasesResponse?
    var focusError: String?

    // legacy
    var scores: [ManipulationScoreV2] = []

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIManipulation
    private var pollingTask: Task<Void, Never>?
    private var wsTask: Task<Void, Never>?
    private(set) var streamClient = ManipulationStreamClient()
    private var isLive: Bool = false

    init(client: NetworkClientProtocol) {
        self.api = APIManipulation(client: client)
        // Mock 模式判定：LiveNetworkClient 才连 WS
        self.isLive = client is LiveNetworkClient
    }

    /// Alias used by ManipulationRadarView
    func load() async { await loadRadar() }

    /// 扫描特定 symbol
    func scan() async {
        guard !scanSymbol.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            scores = try await api.listScores(limit: 20)
        } catch {
            errorHandler?.handle(error, context: "扫描 \(scanSymbol)")
            self.error = error.localizedDescription
        }
    }

    /// 加载雷达概览 + 告警 + 传统评分
    func loadRadar() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let overviewTask = api.getRadarOverview()
            async let alertsTask = api.getAlerts()
            async let scoresTask = api.listScores(limit: 20)
            radarOverview = try await overviewTask
            alerts = try await alertsTask
            scores = (try? await scoresTask) ?? []
            await ensureFocusInitialized()
        } catch {
            errorHandler?.handle(error, context: "加载操纵雷达")
            self.error = error.localizedDescription
        }
    }

    /// 首次加载后自动选第一个 active case
    func ensureFocusInitialized() async {
        guard focusedCaseId == nil,
              let firstId = radarOverview?.activeCases.first?.id else { return }
        await focusCase(firstId)
    }

    /// 聚焦某个 case：三并发加载 detail / strategyImpact / similar
    /// 任一失败不影响其他章节渲染（每个状态独立 nil / error）
    func focusCase(_ caseId: String) async {
        focusedCaseId = caseId
        focusError = nil
        // 立即清空旧数据，UI 显示 loading 态
        focusedDetail = nil
        strategyImpact = nil
        similar = nil

        async let detailTask = try? api.getCaseDetail(caseId)
        async let impactTask = try? api.getStrategyImpact(caseId)
        async let similarTask = try? api.getSimilar(caseId, limit: 5)

        let (detail, impact, sim) = await (detailTask, impactTask, similarTask)
        focusedDetail = detail
        strategyImpact = impact
        similar = sim
        if detail == nil && impact == nil && sim == nil {
            focusError = "全部加载失败"
        }
    }

    /// 启动实时更新：30s polling（兜底）+ WS 监听
    func startLiveUpdates() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await loadRadar()
            }
        }
        guard isLive else { return } // mock 模式不连 WS
        wsTask?.cancel()
        wsTask = Task { [weak self] in
            guard let self else { return }
            let eventStream = await self.streamClient.events()
            for await event in eventStream {
                guard !Task.isCancelled else { break }
                await self.handleStreamEvent(event)
            }
        }
    }

    /// 停止实时更新：同步关闭 polling + WS
    func stopLiveUpdates() {
        pollingTask?.cancel()
        pollingTask = nil
        wsTask?.cancel()
        wsTask = nil
        // streamClient.disconnect() is called by the AsyncStream's onTermination handler
        // when wsTask is cancelled — no explicit disconnect needed here.
    }

    /// 由 view 在 onAppear 时注入 WS baseURL 并连接
    func connectStream(baseURL: URL?) {
        Task { await streamClient.connect(baseURL: baseURL) }
    }

    private func handleStreamEvent(_ event: ManipulationEvent) async {
        switch event {
        case .stageChange(let caseId, _, _, _):
            if caseId == focusedCaseId {
                await focusCase(caseId) // 重新拉详情
            }
            await loadRadar() // 刷新概览 + alerts
        case .newCase:
            await loadRadar()
        case .snapshot:
            await loadRadar()
        case .heartbeat, .unknown:
            break
        }
    }

    /// legacy: 按风险等级排序
    var sortedScores: [ManipulationScoreV2] {
        scores.sorted { riskOrder($0.riskLevel) > riskOrder($1.riskLevel) }
    }

    private func riskOrder(_ level: String) -> Int {
        switch level {
        case "critical": return 4
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 0
        }
    }
}
