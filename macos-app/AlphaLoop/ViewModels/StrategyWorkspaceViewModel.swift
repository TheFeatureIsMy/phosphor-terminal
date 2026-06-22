// StrategyWorkspaceViewModel.swift — Canvas-first workbench ViewModel.
// Spec §7.2 / Plan 2026-06-18 Task 15.
//
// Drives the strategy workbench shell: list rail (⌘1), HUD actions, ⌘1–⌘6
// floating panel state, and canvas bridge counters. Reads everything via the
// /workspace BFF aggregator (single round-trip) instead of fan-out async let.

import SwiftUI

@Observable
@MainActor
final class StrategyWorkspaceViewModel {

    // MARK: - Data

    var strategies: [StrategyV2] = []
    var selectedStrategyId: String?
    var snapshot: WorkspaceSnapshot?

    var isLoadingList = true
    var isLoadingSnapshot = false
    var listError: String?
    var snapshotError: String?

    // MARK: - UI state

    /// Currently open floating panel; nil = canvas full-screen.
    var activePanel: WorkbenchPanel?

    /// Left-rail filter & search.
    var search: String = ""
    var filter: TrackFilter = .all

    /// Canvas bridge state (written by CanvasWebViewModel from canvas-web messages).
    var selectedCanvasNodeId: String?
    var canvasNodeCount: Int = 0
    var canvasEdgeCount: Int = 0
    var canvasValidationValid: Bool?

    // MARK: - Internals

    private let client: NetworkClientProtocol
    private let strategiesAPI: APIStrategiesV2
    private let workspaceAPI: APIStrategyWorkspace
    private let dryrunAPI: APIDryrunV2

    init(client: NetworkClientProtocol) {
        self.client = client
        self.strategiesAPI = APIStrategiesV2(client: client)
        self.workspaceAPI = APIStrategyWorkspace(client: client)
        self.dryrunAPI = APIDryrunV2(client: client)
    }

    // MARK: - Derived

    var selectedStrategy: StrategyV2? {
        guard let id = selectedStrategyId else { return nil }
        return strategies.first { $0.id == id } ?? snapshot?.strategy
    }

    var filteredStrategies: [StrategyV2] {
        var arr = strategies
        if !search.isEmpty {
            let q = search.lowercased()
            arr = arr.filter { $0.name.lowercased().contains(q) }
        }
        switch filter {
        case .all:   return arr
        case .draft: return arr.filter { $0.status == "draft" }
        case .paper: return arr.filter { $0.status == "paper_running" || $0.status == "paper_passed" || $0.status == "paused" }
        case .live:  return arr.filter { $0.status == "live_pending" || $0.status == "live_small" || $0.status == "active" }
        }
    }

    /// Quick accessor for HUD "下一步" action chip.
    var nextActionCode: String? {
        snapshot?.readiness.nextAction.code
    }

    var latestVersion: StrategyVersionV2? {
        guard let id = snapshot?.latestVersionId else {
            return snapshot?.versions.max(by: { $0.versionNo < $1.versionNo })
        }
        return snapshot?.versions.first { $0.id == id }
    }

    // MARK: - Load

    func loadList() async {
        isLoadingList = true
        listError = nil
        do {
            let list = try await strategiesAPI.list()
            strategies = list
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
        snapshot = nil
        selectedCanvasNodeId = nil
        await reloadSnapshot()
    }

    func reloadSnapshot() async {
        guard let id = selectedStrategyId else { return }
        isLoadingSnapshot = true
        snapshotError = nil
        do {
            snapshot = try await workspaceAPI.getSnapshot(strategyId: id)
        } catch {
            snapshotError = error.localizedDescription
        }
        isLoadingSnapshot = false
    }

    /// Refetch only the bindings list (cheap optimistic reload after binding sheet apply).
    func bindingsRefresh() async {
        guard let id = selectedStrategyId, var current = snapshot else { return }
        do {
            let bindings = try await workspaceAPI.listBindings(strategyId: id)
            current = WorkspaceSnapshot(
                strategy: current.strategy,
                versions: current.versions,
                latestVersionId: current.latestVersionId,
                bindings: bindings,
                recentBacktests: current.recentBacktests,
                recentDryruns: current.recentDryruns,
                readiness: current.readiness,
                activity: current.activity,
                signalLogicSummary: current.signalLogicSummary,
                dataDependencies: current.dataDependencies
            )
            snapshot = current
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    // MARK: - Actions

    // NOTE: validate(dsl:) and startBacktest(...) are called from the canvas
    // bridge layer (Phase 8 HUD wiring) — they take [String:Any] DSL payloads
    // that aren't Sendable across actor boundaries, so they sit on the
    // CanvasWebViewModel side rather than this MainActor VM.

    @discardableResult
    func createDraft(name: String) async -> StrategyV2? {
        do {
            let created = try await strategiesAPI.create(name: name)
            strategies.insert(created, at: 0)
            await select(strategyId: created.id)
            return created
        } catch {
            listError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func duplicate(name: String? = nil) async -> StrategyV2? {
        guard let id = selectedStrategyId else { return nil }
        do {
            let copy = try await workspaceAPI.duplicate(strategyId: id, name: name)
            strategies.insert(copy, at: 0)
            await select(strategyId: copy.id)
            return copy
        } catch {
            snapshotError = error.localizedDescription
            return nil
        }
    }

    func archive(reason: String? = nil) async {
        guard let id = selectedStrategyId else { return }
        do {
            let updated = try await workspaceAPI.archive(strategyId: id, reason: reason)
            if let idx = strategies.firstIndex(where: { $0.id == id }) {
                strategies[idx] = updated
            }
            await reloadSnapshot()
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    /// Reuses backend strategy_transition validator. system-only transitions are not exposed.
    func transitionStatus(_ transition: LifecycleTransition) async {
        guard let id = selectedStrategyId, let version = latestVersion else {
            snapshotError = L10n.Workbench.transitionNoneAvailable
            return
        }
        do {
            _ = try await strategiesAPI.transitionVersionStatus(
                strategyId: id,
                versionId: version.id,
                toStatus: transition.toStatus
            )
            if let idx = strategies.firstIndex(where: { $0.id == id }) {
                strategies[idx].status = transition.toStatus
            }
            await reloadSnapshot()
        } catch {
            snapshotError = "\(L10n.Workbench.transitionFailed): \(error.localizedDescription)"
        }
    }

    /// Kick off a dry-run command. Returns commandId for the caller (typically routes user to ⌘5).
    @discardableResult
    func startDryrun() async -> String? {
        guard let id = selectedStrategyId, let version = latestVersion else { return nil }
        let body: [String: Any] = [
            "strategy_id": id,
            "strategy_version_id": version.id,
        ]
        do {
            let resp = try await dryrunAPI.startDryrun(body)
            await reloadSnapshot()
            return resp.commandId
        } catch {
            snapshotError = error.localizedDescription
            return nil
        }
    }

    func createBinding(versionId: String, policyVersionId: String, poolId: String, mode: String) async {
        guard let id = selectedStrategyId else { return }
        do {
            _ = try await workspaceAPI.createBinding(
                strategyId: id,
                versionId: versionId,
                policyVersionId: policyVersionId,
                poolId: poolId,
                mode: mode
            )
            await bindingsRefresh()
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    func deleteBinding(_ bindingId: String) async {
        guard let id = selectedStrategyId else { return }
        do {
            try await workspaceAPI.deleteBinding(strategyId: id, bindingId: bindingId)
            await bindingsRefresh()
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    // MARK: - Panel control

    func openPanel(_ p: WorkbenchPanel) { activePanel = p }

    func togglePanel(_ p: WorkbenchPanel) {
        activePanel = (activePanel == p) ? nil : p
    }

    func closePanel() { activePanel = nil }
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

    /// 10 backend statuses → 7-node happy-path rail. Off-path states (paused/archived/rejected)
    /// are surfaced via LifecycleOffPath instead.
    static func from(status: String) -> LifecycleStage {
        switch status {
        case "draft", "rejected":            return .draft
        case "validated":                    return .validated
        case "backtested":                   return .backtested
        case "paper_running":                return .paperRun
        case "paper_passed":                 return .paperPass
        case "live_pending":                 return .livePending
        case "live_small", "active":         return .liveSmall
        case "paused":                       return .paperRun
        case "archived":                     return .draft
        default:                             return .draft
        }
    }
}

/// Off-happy-path version states. nil = on the main rail.
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

/// User-triggerable lifecycle transitions; mirrors backend ALLOWED_TRANSITIONS minus system-only edges.
enum LifecycleTransition: String, CaseIterable, Identifiable {
    case validate       // draft → validated
    case startPaper     // backtested → paper_running
    case promoteLive    // paper_passed → live_pending
    case approveLive    // live_pending → live_small
    case pause          // paper_running/live_small → paused
    case resume         // paused → paper_running
    case archive
    case reject
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
