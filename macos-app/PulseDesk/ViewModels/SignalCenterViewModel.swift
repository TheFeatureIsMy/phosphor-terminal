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
    var errorHandler: ErrorHandler?

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
        signals.filter { signal in
            if let src = filterSource, src != "全部" {
                let mapping: [String: String] = [
                    "AI研究": "ai_research",
                    "TradingAgents": "tradingagents",
                    "手动": "manual",
                    "Canvas": "canvas",
                ]
                if let mapped = mapping[src], signal.sourceType != mapped {
                    return false
                }
            }
            if let dir = filterDirection, dir != "全部", signal.direction.lowercased() != dir.lowercased() {
                return false
            }
            if let risk = filterRisk, risk != "全部" {
                let mapping: [String: String] = [
                    "低": "low", "中": "medium", "高": "high", "极高": "critical",
                ]
                if let mapped = mapping[risk], signal.riskLevel != mapped {
                    return false
                }
            }
            return true
        }
    }
}
