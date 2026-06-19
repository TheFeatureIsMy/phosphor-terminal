// StrategyWorkspaceViewModel.swift — 发射控制台聚合 ViewModel
// 用 async let 并行聚合 7 个数据源；后端实现 /workspace BFF 后可换成单调用。

import SwiftUI

@Observable
@MainActor
final class StrategyWorkspaceViewModel {
    // MARK: - Public state

    /// 左轨：候补策略列表
    var strategies: [StrategyV2] = []
    /// 当前选中策略 ID（与 selectedStrategy.id 同步）
    var selectedStrategyId: String?

    /// 当前选中策略的聚合快照
    var snapshot: LegacyWorkspaceSnapshot?

    var isLoadingList = true
    var isLoadingSnapshot = false
    var listError: String?
    var snapshotError: String?

    /// 左轨过滤桶
    var filter: TrackFilter = .all
    var search: String = ""

    /// 工作区视图模式（与画布融合，互斥切换）
    var mode: WorkspaceMode = .console
    /// 上下文抽屉折叠（仅 console 模式生效）
    var drawerCollapsed = true
    /// 上下文抽屉浮层选中的 tab；nil 表示未打开
    var inspectorTab: InspectorTab?
    /// 策略切换下拉是否展开
    var switcherOpen = false

    // MARK: - Internals

    private let client: NetworkClientProtocol
    private let strategiesAPI: APIStrategiesV2
    private let runsAPI: APIStrategyRuns
    private let backtestAPI: APIBacktest
    private let riskAPI: APIRiskBFF

    init(client: NetworkClientProtocol) {
        self.client = client
        self.strategiesAPI = APIStrategiesV2(client: client)
        self.runsAPI = APIStrategyRuns(client: client)
        self.backtestAPI = APIBacktest(client: client)
        self.riskAPI = APIRiskBFF(client: client)
    }

    // MARK: - Derived

    var selectedStrategy: StrategyV2? {
        guard let id = selectedStrategyId else { return nil }
        return strategies.first { $0.id == id }
    }

    var filteredStrategies: [StrategyV2] {
        var arr = strategies
        if !search.isEmpty {
            let q = search.lowercased()
            arr = arr.filter { $0.name.lowercased().contains(q) }
        }
        switch filter {
        case .all: return arr
        case .draft: return arr.filter { $0.status == "draft" }
        case .paper: return arr.filter { $0.status == "active" || $0.status == "paused" }
        case .live:  return arr.filter { $0.status == "active" }
        }
    }

    // MARK: - Load

    func loadList() async {
        isLoadingList = true
        listError = nil
        do {
            let list = try await strategiesAPI.list()
            strategies = list
            // 自动选中第一个，提供首屏内容
            if selectedStrategyId == nil, let first = list.first {
                await select(strategyId: first.id)
            }
        } catch {
            listError = error.localizedDescription
        }
        isLoadingList = false
    }

    func select(strategyId: String) async {
        selectedStrategyId = strategyId
        await reloadSnapshot()
    }

    /// 触发 lifecycle transition：在 latest version 上执行；成功后刷新快照。
    /// 后端会做合法性校验；若 409 / 403，错误填到 snapshotError 并维持原状态。
    func performTransition(_ transition: LifecycleTransition) async {
        guard let strategyId = selectedStrategyId,
              let version = snapshot?.latestVersion else {
            snapshotError = L10n.Workbench.transitionNoneAvailable
            return
        }
        do {
            _ = try await strategiesAPI.transitionVersionStatus(
                strategyId: strategyId,
                versionId: version.id,
                toStatus: transition.toStatus
            )
            await reloadSnapshot()
            // 列表里也同步更新状态字段，避免 switcher 旧标签残留
            if let idx = strategies.firstIndex(where: { $0.id == strategyId }) {
                strategies[idx].status = transition.toStatus
            }
        } catch {
            snapshotError = "\(L10n.Workbench.transitionFailed): \(error.localizedDescription)"
        }
    }

    func reloadSnapshot() async {
        guard let id = selectedStrategyId else { return }
        isLoadingSnapshot = true
        snapshotError = nil

        async let strategy   = strategiesAPI.get(id: id)
        async let versions   = strategiesAPI.listVersions(strategyId: id)
        async let runs       = runsAPI.listRuns(limit: 5)
        async let signals    = client.listAgentSignals()
        async let risk       = riskAPI.getOverview()
        async let backtests  = backtestAPI.list(limit: 3)

        do {
            // 注意：当前 APIStrategyRuns/Signals/Backtest 尚未按 strategyId 过滤；
            // 后端补齐前，这里先在客户端做 best-effort 过滤。
            let s = try await strategy
            let v = try await versions
            let r = try await runs
            let sig = try await signals
            let risk_ = try await risk
            let bt = try await backtests

            snapshot = LegacyWorkspaceSnapshot(
                strategy: s,
                versions: v,
                runs: r,
                signals: sig,
                risk: risk_,
                backtests: bt
            )
        } catch {
            snapshotError = error.localizedDescription
        }
        isLoadingSnapshot = false
    }
}

// MARK: - LegacyWorkspaceSnapshot (Task 15 will rewrite this VM and remove this struct)

struct LegacyWorkspaceSnapshot {
    let strategy: StrategyV2
    let versions: [StrategyVersionV2]
    let runs: [StrategyRunV2]
    let signals: [AgentSignal]
    let risk: RiskOverviewBFFResponse
    let backtests: [Backtest]

    var latestVersion: StrategyVersionV2? {
        versions.max(by: { $0.versionNo < $1.versionNo })
    }
    var currentRun: StrategyRunV2? {
        runs.first(where: { $0.status == "running" }) ?? runs.first
    }
    var latestBacktest: Backtest? { backtests.first }

    // 顶部 KPI 抽取（按 backtest/latestRun 推断）
    var equity: Double {
        if let bt = latestBacktest { return 10_000 + bt.totalReturn * 100 }
        return 10_000
    }
    var pnlPct: Double { latestBacktest?.totalReturn ?? 0 }
    var winRate: Double { latestBacktest?.winRate ?? 0 }
    var maxDrawdown: Double { latestBacktest?.maxDrawdown ?? 0 }
    var sharpe: Double { latestBacktest?.sharpeRatio ?? 0 }
}

// MARK: - Workspace mode

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case console
    case canvas
    var id: String { rawValue }
    var label: String {
        switch self {
        case .console: return L10n.Workbench.modeConsole
        case .canvas:  return L10n.Workbench.modeCanvas
        }
    }
    var icon: String {
        switch self {
        case .console: return "rectangle.grid.2x2"
        case .canvas:  return "point.3.connected.trianglepath.dotted"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case decision, reason, logs
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .decision: return "checkmark.seal"
        case .reason:   return "exclamationmark.bubble"
        case .logs:     return "clock.arrow.circlepath"
        }
    }
    var label: String {
        switch self {
        case .decision: return L10n.Workbench.drawerDecision
        case .reason:   return L10n.Workbench.drawerReason
        case .logs:     return L10n.Workbench.drawerLogs
        }
    }
}

// MARK: - Filter

enum TrackFilter: String, CaseIterable, Identifiable {
    case all, draft, paper, live
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:   return L10n.Workbench.filterAll
        case .draft: return L10n.Workbench.filterDraft
        case .paper: return L10n.Workbench.filterPaper
        case .live:  return L10n.Workbench.filterLive
        }
    }
}

// MARK: - Lifecycle stage helper

enum LifecycleStage: Int, CaseIterable, Identifiable {
    case draft = 0
    case validated
    case backtested
    case paperRun
    case paperPass
    case livePending
    case liveSmall

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .draft:       return L10n.Workbench.stageDraft
        case .validated:   return L10n.Workbench.stageValidated
        case .backtested:  return L10n.Workbench.stageBacktested
        case .paperRun:    return L10n.Workbench.stagePaperRun
        case .paperPass:   return L10n.Workbench.stagePaperPass
        case .livePending: return L10n.Workbench.stageLivePending
        case .liveSmall:   return L10n.Workbench.stageLiveSmall
        }
    }

    /// 10 态后端 → 7 节点 happy-path 映射（off-path 走 paused/archived/rejected 由 LifecycleOffPath 表示）
    static func from(status: String) -> LifecycleStage {
        switch status {
        case "draft", "rejected":            return .draft
        case "validated":                    return .validated
        case "backtested":                   return .backtested
        case "paper_running":                return .paperRun
        case "paper_passed":                 return .paperPass
        case "live_pending":                 return .livePending
        case "live_small", "active":         return .liveSmall
        case "paused":                       return .paperRun  // paused 从 paper_running 走来
        case "archived":                     return .draft     // 显示停在起点
        default:                             return .draft
        }
    }
}

/// 偏离 happy-path 的版本状态。nil 表示策略在主航道。
enum LifecycleOffPath: String, CaseIterable, Identifiable {
    case paused, archived, rejected
    var id: String { rawValue }

    var label: String {
        switch self {
        case .paused:   return L10n.Workbench.offPathPaused
        case .archived: return L10n.Workbench.offPathArchived
        case .rejected: return L10n.Workbench.offPathRejected
        }
    }
    var icon: String {
        switch self {
        case .paused:   return "pause.circle.fill"
        case .archived: return "archivebox.fill"
        case .rejected: return "xmark.octagon.fill"
        }
    }

    static func from(status: String) -> LifecycleOffPath? {
        switch status {
        case "paused":   return .paused
        case "archived": return .archived
        case "rejected": return .rejected
        default:         return nil
        }
    }
}

/// 用户可触发的 lifecycle transition；ALLOWED_TRANSITIONS 与 backend/app/services/strategy_transition.py 镜像。
/// system-only 跃迁 (validated→backtested、paper_running→paper_passed) 不暴露给用户。
enum LifecycleTransition: String, CaseIterable, Identifiable {
    case validate       // draft → validated
    case startPaper     // backtested → paper_running
    case promoteLive    // paper_passed → live_pending
    case approveLive    // live_pending → live_small
    case pause          // paper_running/live_small → paused
    case resume         // paused → paper_running
    case archive        // 多个状态 → archived
    case reject         // pre-live 状态 → rejected
    case reopen         // rejected → draft

    var id: String { rawValue }

    var label: String {
        switch self {
        case .validate:    return L10n.Workbench.transitionValidate
        case .startPaper:  return L10n.Workbench.transitionStartPaper
        case .promoteLive: return L10n.Workbench.transitionPromoteLive
        case .approveLive: return L10n.Workbench.transitionApproveLive
        case .pause:       return L10n.Workbench.transitionPause
        case .resume:      return L10n.Workbench.transitionResume
        case .archive:     return L10n.Workbench.transitionArchive
        case .reject:      return L10n.Workbench.transitionReject
        case .reopen:      return L10n.Workbench.transitionReopen
        }
    }

    var icon: String {
        switch self {
        case .validate:    return "checkmark.shield"
        case .startPaper:  return "play.circle"
        case .promoteLive: return "arrow.up.circle"
        case .approveLive: return "checkmark.seal"
        case .pause:       return "pause.circle"
        case .resume:      return "play.fill"
        case .archive:     return "archivebox"
        case .reject:      return "xmark.octagon"
        case .reopen:      return "arrow.counterclockwise.circle"
        }
    }

    var isDestructive: Bool {
        self == .archive || self == .reject
    }

    /// 后端目标 status 字符串
    var toStatus: String {
        switch self {
        case .validate:    return "validated"
        case .startPaper:  return "paper_running"
        case .promoteLive: return "live_pending"
        case .approveLive: return "live_small"
        case .pause:       return "paused"
        case .resume:      return "paper_running"
        case .archive:     return "archived"
        case .reject:      return "rejected"
        case .reopen:      return "draft"
        }
    }

    /// 根据当前 status 返回允许的用户跃迁集合（镜像 backend ALLOWED_TRANSITIONS 减去 system-only）。
    static func allowed(from status: String) -> [LifecycleTransition] {
        switch status {
        case "draft":          return [.validate, .archive, .reject]
        case "validated":      return [.archive, .reject]
        case "backtested":     return [.startPaper, .archive, .reject]
        case "paper_running":  return [.pause, .archive, .reject]
        case "paper_passed":   return [.promoteLive, .archive, .reject]
        case "live_pending":   return [.approveLive, .reject]
        case "live_small", "active": return [.pause, .archive]
        case "paused":         return [.resume, .archive]
        case "archived":       return []
        case "rejected":       return [.reopen]
        default:               return []
        }
    }
}
