// Language.swift — 语言枚举

import Foundation

enum Language: String, Codable, CaseIterable, Identifiable {
    case zhCN = "zh-CN"
    case enUS = "en-US"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhCN: return "中文"
        case .enUS: return "English"
        }
    }

    var flag: String {
        switch self {
        case .zhCN: return "🇨🇳"
        case .enUS: return "🇺🇸"
        }
    }
}
