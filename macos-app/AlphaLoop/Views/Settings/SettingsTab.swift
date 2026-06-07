// SettingsTab.swift — 设置页 Tab 枚举

import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general       // 通用 (language + profile)
    case trading       // 交易 (exchange + risk)
    case notifications // 通知
    case api           // API
    case services      // 服务 (MCP)
    case data          // 数据 (vacuum)
    case advanced      // 高级 (danger zone)

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .trading: return "chart.bar"
        case .notifications: return "bell"
        case .api: return "key"
        case .services: return "server.rack"
        case .data: return "externaldrive.fill"
        case .advanced: return "exclamationmark.triangle"
        }
    }

    var title: String {
        switch self {
        case .general: return L10n.Settings.tabGeneral
        case .trading: return L10n.Settings.tabTrading
        case .notifications: return L10n.Settings.tabNotifications
        case .api: return L10n.Settings.tabAPI
        case .services: return L10n.Settings.tabServices
        case .data: return L10n.Settings.tabData
        case .advanced: return L10n.Settings.tabAdvanced
        }
    }
}
