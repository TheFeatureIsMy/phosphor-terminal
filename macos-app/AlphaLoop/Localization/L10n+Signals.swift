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

        // Status filters
        static var status: String { zh("状态", en: "Status") }
        static var statusAll: String { zh("全部", en: "All") }
        static var statusActive: String { zh("active", en: "active") }
        static var statusPending: String { zh("pending", en: "pending") }
        static var statusRejected: String { zh("rejected", en: "rejected") }

        // Symbol filters
        static var symbol: String { zh("标的", en: "Symbol") }
        static var symbolAll: String { zh("全部", en: "All") }
        static var symbolOther: String { zh("其他", en: "Others") }

        // Sort
        static var sort: String { zh("排序", en: "Sort") }
        static var sortScoreDesc: String { zh("评分 高→低", en: "Score ↓") }
        static var sortConfidenceDesc: String { zh("置信度 高→低", en: "Confidence ↓") }
        static var sortExpiryAsc: String { zh("有效期 近→远", en: "Expiry ↑") }

        // Hero stat band
        static var statInField: String { zh("在场 Signal", en: "In-field") }
        static var statActive: String { zh("active", en: "active") }
        static var statPending: String { zh("pending", en: "pending") }
        static var statExpired: String { zh("expired", en: "expired") }
        static var statRejected: String { zh("rejected", en: "rejected") }
        static var statConflicts: String { zh("冲突待裁决", en: "Conflicts") }

        // Conflicts
        static var conflictTitle: String { zh("冲突检测 · 需人工裁决", en: "Conflicts · Awaiting Adjudication") }
        static var conflictNone: String { zh("当前无多空冲突", en: "No directional conflicts") }
        static var conflictDirection: String { zh("方向对立", en: "Opposed") }
        static var conflictVS: String { zh("VS", en: "VS") }
        static var conflictAdjudicate: String { zh("裁决冲突 →", en: "Adjudicate →") }
        static var conflictHint: String { zh("同标的多空对立，建议裁决后再发布到策略", en: "Same-symbol long/short opposed; adjudicate before publishing") }

        // Table header
        static var colSymbolTF: String { zh("标的 / 周期", en: "Symbol / TF") }
        static var colDirection: String { zh("方向", en: "Direction") }
        static var colSource: String { zh("来源", en: "Source") }
        static var colConfidence: String { zh("置信度", en: "Confidence") }
        static var colScore: String { zh("评分", en: "Score") }
        static var colRisk: String { zh("风险", en: "Risk") }
        static var colExpiry: String { zh("有效期", en: "Expires") }
        static var colStatus: String { zh("状态", en: "Status") }
        static var expandHint: String { zh("点击行展开完整信号", en: "Click row to expand") }

        // Expanded detail
        static var detSource: String { zh("谁产生的 · Source", en: "Source") }
        static var detTarget: String { zh("看什么标的 · Target", en: "Target") }
        static var detDirection: String { zh("什么方向 · Direction", en: "Direction") }
        static var detConfidence: String { zh("多可信 · Confidence", en: "Confidence") }
        static var detReasoning: String { zh("为什么 · Reasoning", en: "Reasoning") }
        static var detValidity: String { zh("何时有效 · Validity", en: "Validity") }
        static var detPermission: String { zh("能做什么 · Permission", en: "Permission") }
        static var detLifecycle: String { zh("生命周期 · Lifecycle", en: "Lifecycle") }

        // Direction labels
        static var dirLong: String { zh("看多 Long", en: "Long") }
        static var dirShort: String { zh("看空 Short", en: "Short") }
        static var dirHold: String { zh("观望 Hold", en: "Hold") }
        static var dirRisk: String { zh("风险 Risk", en: "Risk") }

        // Actions
        static var actionPublish: String { zh("发布到策略", en: "Publish to Strategy") }
        static var actionDryrun: String { zh("加入 dry-run 观察", en: "Add to dry-run") }
        static var actionDraft: String { zh("生成 StrategyDraft", en: "Create StrategyDraft") }
        static var actionArchive: String { zh("归档", en: "Archive") }
        static var actionAdjudicate: String { zh("裁决冲突", en: "Adjudicate") }
        static var comingSoon: String { zh("（后端待接入）", en: " (backend pending)") }
    }
}
