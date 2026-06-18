// BFFResponse.swift — BFF 响应协议，检测 data_source_unavailable 状态
// 任何 BFF endpoint 响应只要包含 state + reasonCodes 字段，都可实现本协议。
// 扩展通过 `isDataSourceUnavailable` 计算属性提供统一检测入口。

import Foundation

// MARK: - Protocol

/// BFF 响应协议。
/// 实现者必须提供 `state` 和 `reasonCodes`（通常来自后端 JSON 的 `state` 和 `reason_codes`）。
protocol BFFResponse: Decodable {
    var state: String { get }
    var reasonCodes: [String] { get }
}

extension BFFResponse {
    /// 当后端返回 `data_source_unavailable` 状态时返回 `true`。
    /// 检查 `state == "data_source_unavailable"` 或 `reasonCodes` 中包含 `"data_source_unavailable"`。
    var isDataSourceUnavailable: Bool {
        state == "data_source_unavailable" || reasonCodes.contains("data_source_unavailable")
    }
}

// MARK: - Conformances

extension DashboardBFFResponse: BFFResponse {}
