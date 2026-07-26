// SignalCenterViewModel.swift — 信号中心视图模型
// 负责加载、过滤、状态转换、归档 V2 信号

import SwiftUI

@Observable
@MainActor
final class SignalCenterViewModel {
    var signals: [SignalV2] = []
    var isLoading = false
    var error: String?
    var selectedSignal: SignalV2?
    var filterSource: String? = nil
    var filterDirection: String? = nil
    var filterRisk: String? = nil
    var filterStatus: String? = nil
    var filterSymbol: String? = nil
    var sortOrder: SortOrder = .scoreDesc
    var errorHandler: ErrorHandler?

    enum SortOrder: String, CaseIterable {
        case scoreDesc, confidenceDesc, expiryAsc
        var label: String {
            switch self {
            case .scoreDesc: return L10n.Signals.sortScoreDesc
            case .confidenceDesc: return L10n.Signals.sortConfidenceDesc
            case .expiryAsc: return L10n.Signals.sortExpiryAsc
            }
        }
    }

    private let api: APISignalsV2

    init(client: NetworkClientProtocol) {
        self.api = APISignalsV2(client: client)
    }

    // MARK: - 加载信号列表

    func load() async {
        isLoading = true
        error = nil
        do {
            signals = try await api.listSignals()
        } catch {
            errorHandler?.handle(error, context: "加载信号列表")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 状态转换

    func transition(_ id: String, to status: String) async {
        do {
            let updated = try await api.transitionSignal(id, targetStatus: status)
            if let index = signals.firstIndex(where: { $0.id == id }) {
                signals[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "转换信号状态")
        }
    }

    // MARK: - 归档

    func archive(_ id: String) async {
        do {
            let updated = try await api.archiveSignal(id)
            if let index = signals.firstIndex(where: { $0.id == id }) {
                signals[index] = updated
            }
        } catch {
            errorHandler?.handle(error, context: "归档信号")
        }
    }

    // MARK: - 发布为策略

    func publishToStrategy(_ id: String) async {
        do {
            _ = try await api.publishToStrategy(id)
        } catch {
            errorHandler?.handle(error, context: "发布为策略")
        }
    }

    // MARK: - 冲突检测

    func conflictCheck(symbol: String, direction: String) async -> SignalConflictResult? {
        do {
            return try await api.conflictCheck(symbol: symbol, direction: direction)
        } catch {
            return nil
        }
    }

    // MARK: - 过滤逻辑

    var filteredSignals: [SignalV2] {
        let filtered = signals.filter { signal in
            if let src = filterSource, src != L10n.Signals.sourceAll {
                let mapping: [String: String] = [
                    "AI研究": "ai_research", "AI Research": "ai_research",
                    "TradingAgents": "tradingagents",
                    "手动": "manual", "Manual": "manual",
                    "Canvas": "canvas",
                ]
                if let mapped = mapping[src], signal.sourceType != mapped { return false }
            }
            if let dir = filterDirection, dir != L10n.Signals.directionAll, signal.direction.lowercased() != dir.lowercased() {
                return false
            }
            if let risk = filterRisk, risk != L10n.Signals.riskAll {
                let mapping: [String: String] = [
                    "低": "low", "Low": "low", "中": "medium", "Medium": "medium",
                    "高": "high", "High": "high", "极高": "critical", "Extreme": "critical",
                ]
                if let mapped = mapping[risk], signal.riskLevel != mapped { return false }
            }
            if let st = filterStatus, st != L10n.Signals.statusAll, signal.status.lowercased() != st.lowercased() {
                return false
            }
            if let sym = filterSymbol, sym != L10n.Signals.symbolAll, !signal.symbol.hasPrefix(sym) {
                return false
            }
            return true
        }
        return sortedSignals(filtered)
    }

    private func sortedSignals(_ list: [SignalV2]) -> [SignalV2] {
        switch sortOrder {
        case .scoreDesc:
            return list.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        case .confidenceDesc:
            return list.sorted { $0.confidence > $1.confidence }
        case .expiryAsc:
            return list.sorted { $0.expiresAt < $1.expiresAt }
        }
    }

    // MARK: - 状态计数(统计带)

    func count(status: String) -> Int {
        signals.filter { $0.status.lowercased() == status.lowercased() }.count
    }

    // MARK: - 冲突检测(同标的多空对立,真实数据派生)

    struct ConflictGroup: Identifiable {
        let id: String  // symbol
        let symbol: String
        let longs: [SignalV2]
        let shorts: [SignalV2]
    }

    var conflictGroups: [ConflictGroup] {
        let active = signals.filter { $0.status.lowercased() == "active" || $0.status.lowercased() == "pending" }
        let bySymbol = Dictionary(grouping: active, by: { $0.symbol })
        var groups: [ConflictGroup] = []
        for (symbol, list) in bySymbol {
            let longs = list.filter { $0.direction.lowercased() == "long" }
            let shorts = list.filter { $0.direction.lowercased() == "short" }
            if !longs.isEmpty && !shorts.isEmpty {
                groups.append(ConflictGroup(id: symbol, symbol: symbol, longs: longs, shorts: shorts))
            }
        }
        return groups
    }
}
