// SettingsTab.swift - 设置页 Tab 枚举

import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general        // 基础偏好 (language, timezone, appearance, default mode)
    case notifications  // 通知管理
    case security       // 安全 / 审计 / 网络
    case advanced       // 高级 (备份/导出/danger zone)

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .security: return "lock.shield"
        case .advanced: return "exclamationmark.triangle"
        }
    }

    var title: String {
        switch self {
        case .general: return L10n.Settings.tabGeneral
        case .notifications: return L10n.Settings.tabNotifications
        case .security: return L10n.Settings.tabSecurity
        case .advanced: return L10n.Settings.tabAdvanced
        }
    }
}
