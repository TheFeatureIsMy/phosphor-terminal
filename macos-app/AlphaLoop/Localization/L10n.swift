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

/// 响应式本地化文本 — 随语言设置自动切换
struct L10nText: View {
    @Environment(SettingsState.self) private var settings
    let zh: String
    let en: String

    init(_ zh: String, en: String) {
        self.zh = zh
        self.en = en
    }

    var body: some View {
        Text(settings.language == .zhCN ? zh : en)
    }
}
