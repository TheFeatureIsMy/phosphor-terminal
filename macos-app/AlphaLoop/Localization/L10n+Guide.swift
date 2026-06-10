// L10n+Guide.swift — 用户指南文案

extension L10n {
    enum Guide {
        static var title: String              { zh("用户指南", en: "User Guide") }
        static var sidebarLabel: String       { zh("用户指南", en: "Guide") }
        static var dashboardTitle: String     { zh("学习 AlphaLoop", en: "Learn AlphaLoop") }
        static var dashboardSubtitle: String  { zh("5 分钟读完每个页面", en: "Understand every page in 5 minutes") }
        static var chipWelcome: String        { zh("欢迎", en: "Welcome") }
        static var chipConcepts: String       { zh("核心概念", en: "Core Concepts") }
        static var chipFirstStrategy: String  { zh("第一个策略", en: "First Strategy") }
        static var openFailed: String         { zh("无法打开用户指南", en: "Couldn't open the user guide") }
        static var restoreCard: String        { zh("显示 Dashboard 学习卡", en: "Show Dashboard learn card") }
        static var dismissCard: String        { zh("不再显示", en: "Don't show again") }
    }
}
