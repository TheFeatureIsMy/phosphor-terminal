// L10n.swift — 本地化字符串命名空间

import SwiftUI

enum L10n {
    @MainActor
    static var current: Language {
        SettingsState.shared.language
    }

    nonisolated static func zh(_ zh: String, en: String) -> String {
        MainActor.assumeIsolated {
            current == .zhCN ? zh : en
        }
    }
}
