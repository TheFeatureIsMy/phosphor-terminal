// L10n+Growth.swift — 增长引擎文案

extension L10n {
    enum Growth {
        // Header
        static var title: String { zh("增长引擎", en: "Growth Engine") }
        static var subtitle: String { zh("自动发现 · 回测验证 · 策略进化", en: "Auto-Discovery · Backtest Validation · Strategy Evolution") }

        // Tabs
        static var reports: String { zh("分析报告", en: "Reports") }
        static var candidates: String { zh("候选策略", en: "Candidates") }
        static var shapAnalysis: String { zh("SHAP 分析", en: "SHAP Analysis") }
        static var signalValidity: String { zh("Signal 有效性", en: "Signal Validity") }

        // Reports tab
        static var analysisReports: String { zh("分析报告", en: "Analysis Reports") }
        static var runDailyReview: String { zh("运行日报", en: "Run Daily Review") }
        static var noReports: String { zh("暂无报告", en: "No Reports") }
        static var noReportsDesc: String { zh("点击「运行日报」生成第一份增长分析报告", en: "Click \"Run Daily Review\" to generate your first growth report") }

        // Candidates tab
        static var candidateStrategies: String { zh("候选策略", en: "Candidate Strategies") }
        static var noCandidates: String { zh("暂无候选策略", en: "No Candidates") }
        static var noCandidatesDesc: String { zh("增长引擎将自动发现并推荐有潜力的交易策略", en: "The growth engine will automatically discover and recommend promising strategies") }

        // SHAP tab
        static var shapFeatureImportance: String { zh("SHAP 特征重要性", en: "SHAP Feature Importance") }
        static var shapDescription: String { zh("全局特征对交易决策的影响程度", en: "Global feature impact on trading decisions") }

        // Signal Validity tab
        static var signalValidityTracking: String { zh("Signal 有效性追踪", en: "Signal Validity Tracking") }
        static func signalAccuracyBySource(_ period: String) -> String { zh("各来源信号预测准确率（\(period)）", en: "Signal prediction accuracy by source (\(period))") }
        static var totalSignals: String { zh("总信号数", en: "Total Signals") }
        static var avgAccuracy: String { zh("平均准确率", en: "Avg Accuracy") }
        static var bestSource: String { zh("最佳来源", en: "Best Source") }
        static var worstSource: String { zh("最差来源", en: "Worst Source") }

        // Period
        static var day: String { zh("日", en: "Day") }
        static var week: String { zh("周", en: "Week") }
        static var month: String { zh("月", en: "Month") }

        // Times suffix
       static func times(_ n: Int) -> String { zh("\(n)次", en: "\(n)x") }

        // Evidence & version tracking
        static var evidenceSource: String { zh("证据来源", en: "Evidence Source") }
        static var rationale: String { zh("改进依据", en: "Rationale") }
        static var sourceReport: String { zh("来源报告", en: "Source Report") }
        static var sourceVersion: String { zh("源版本", en: "Source Version") }
        static var confirmedVersion: String { zh("确认版本号", en: "Confirmed Version") }
        static var dslValid: String { zh("DSL 校验通过", en: "DSL Valid") }
        static var dslInvalid: String { zh("DSL 校验失败", en: "DSL Invalid") }
        static var findings: String { zh("发现", en: "Findings") }
        static var suggestions: String { zh("优化建议", en: "Suggestions") }
        static var strategyVersion: String { zh("策略版本", en: "Strategy Version") }
        static var noMetricsData: String { zh("暂无指标数据", en: "No metrics data") }
        static var dataUnavailable: String { zh("数据源不可用", en: "Data source unavailable") }
   }
}
