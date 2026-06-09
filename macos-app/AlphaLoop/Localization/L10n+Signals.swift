// L10n+Signals.swift — 信号中心文案

extension L10n {
    enum Signals {
        // Header
        static var title: String { zh("信号中心", en: "Signal Center") }
        static var createSignal: String { zh("新建信号", en: "New Signal") }

        // Filter bar
        static var source: String { zh("来源", en: "Source") }
        static var direction: String { zh("方向", en: "Direction") }
        static var risk: String { zh("风险", en: "Risk") }

        // Source filters
        static var sourceAll: String { zh("全部", en: "All") }
        static var sourceAIResearch: String { zh("AI研究", en: "AI Research") }
        static var sourceTradingAgents: String { zh("TradingAgents", en: "TradingAgents") }
        static var sourceManual: String { zh("手动", en: "Manual") }
        static var sourceCanvas: String { zh("Canvas", en: "Canvas") }

        // Direction filters
        static var directionAll: String { zh("全部", en: "All") }

        // Risk filters
        static var riskAll: String { zh("全部", en: "All") }
        static var riskLow: String { zh("低", en: "Low") }
        static var riskMedium: String { zh("中", en: "Medium") }
        static var riskHigh: String { zh("高", en: "High") }
        static var riskCritical: String { zh("极高", en: "Critical") }

        // Empty state
        static var noSignals: String { zh("暂无信号", en: "No Signals") }
        static var noSignalsDesc: String { zh("运行 AI 研究或手动创建信号后，将在此处显示", en: "Signals will appear here after running AI research or creating one manually") }
    }
}
