// L10n+Structure.swift — 市场结构文案

extension L10n {
    enum Structure {
        static var title: String { zh("市场结构", en: "Market Structure") }
        static var matrix: String { zh("结构矩阵", en: "Structure Matrix") }

        // Summary metrics
        static var marketState: String { zh("市场状态", en: "Market State") }
        static var structureScore: String { zh("结构评分", en: "Structure Score") }
        static var premiumDiscount: String { zh("溢价/折价", en: "Premium/Discount") }
        static var activeZones: String { zh("活跃区域", en: "Active Zones") }
        static var liquidityPools: String { zh("流动性池", en: "Liquidity Pools") }

        // Zones
        static var zones: String { zh("结构区域", en: "Structure Zones") }
        static var zoneType: String { zh("类型", en: "Type") }
        static var direction: String { zh("方向", en: "Direction") }
        static var priceRange: String { zh("价格区间", en: "Price Range") }
        static var strength: String { zh("强度", en: "Strength") }
        static var fillRate: String { zh("填充率", en: "Fill Rate") }
        static var bullish: String { zh("多头", en: "Bullish") }
        static var bearish: String { zh("空头", en: "Bearish") }
        static var neutral: String { zh("中性", en: "Neutral") }

        // Zone types
        static var orderBlock: String { zh("订单块", en: "Order Block") }
        static var fairValueGap: String { zh("公允价值缺口", en: "Fair Value Gap") }
        static var liquidityPool: String { zh("流动性池", en: "Liquidity Pool") }

        // Pool types
        static var equalHigh: String { zh("等高点", en: "Equal Highs") }
        static var equalLow: String { zh("等低点", en: "Equal Lows") }
        static var swingHigh: String { zh("波段高点", en: "Swing High") }
        static var swingLow: String { zh("波段低点", en: "Swing Low") }
        static var buySide: String { zh("买方", en: "Buy Side") }
        static var sellSide: String { zh("卖方", en: "Sell Side") }
        static var touchCount: String { zh("触及次数", en: "Touch Count") }

        // Events
        static var events: String { zh("结构事件", en: "Structure Events") }
        static var breakOfStructure: String { zh("结构突破", en: "Break of Structure") }
        static var changeOfCharacter: String { zh("特征变化", en: "Change of Character") }
        static var sweep: String { zh("扫荡", en: "Sweep") }
        static var fvgFill: String { zh("FVG 填充", en: "FVG Fill") }

        // Matrix
        static var timeframe: String { zh("时间周期", en: "Timeframe") }
        static var violation: String { zh("违规", en: "Violation") }
        static var shadowWindow: String { zh("影子窗口", en: "Shadow Window") }
        static var action: String { zh("操作", en: "Action") }
        static var allow: String { zh("允许", en: "Allow") }
        static var block: String { zh("阻断", en: "Block") }
        static var reduce: String { zh("减仓", en: "Reduce") }

        // Matrix · Column-First redesign
        static var consistencyTowers: String { zh("区域一致性矩阵", en: "Zone Consistency Towers") }
        static var aligned: String { zh("对齐", en: "aligned") }
        static var auditLog: String { zh("审计日志", en: "Audit Log") }
        static var htf: String { zh("高周期", en: "HTF") }
        static var ltf: String { zh("低周期", en: "LTF") }
        static var preEntryGuard: String { zh("多周期一致性裁判", en: "multi-timeframe consistency referee") }
        static var observe: String { zh("观察", en: "Observe") }

        // Matrix · HTF Tribunal redesign
        static var tribunalTitle: String { zh("结构审判庭", en: "The Structure Tribunal") }
        static var tribunalSubtitle: String { zh("多周期防御之庭", en: "chamber of multi-timeframe defense") }
        static var verdictTrustworthy: String { zh("裁决可信", en: "verdict trustworthy") }
        static var verdictSuspect: String { zh("裁决存疑", en: "verdict suspect") }
        static var labelLatency: String { zh("延迟", en: "latency") }
        static var labelDataAge: String { zh("数据年龄", en: "data age") }
        static var labelRedis: String { zh("Redis", en: "redis") }
        static var statusOk: String { zh("正常", en: "ok") }
        static var statusDown: String { zh("中断", en: "down") }
        static var stateMachine: String { zh("状态机", en: "State Machine") }
        static var stateInactive: String { zh("未激活", en: "INACTIVE") }
        static var stateWatching: String { zh("观察中", en: "WATCHING") }
        static var statePendingHtfClose: String { zh("等待HTF收盘", en: "PENDING HTF CLOSE") }
        static var stateTemporaryViolation: String { zh("暂时违规", en: "TEMPORARY VIOLATION") }
        static var stateReclaimPending: String { zh("等待夺回", en: "RECLAIM PENDING") }
        static var stateConfirmed: String { zh("已确认", en: "CONFIRMED") }
        static var stateInvalidated: String { zh("已无效", en: "INVALIDATED") }
        static var stateExpired: String { zh("已过期", en: "EXPIRED") }
        static var candleClosesIn: String { zh("收盘倒计时", en: "candle closes in") }
        static var verdict: String { zh("裁决", en: "VERDICT") }
        static var verdictAllow: String { zh("放行", en: "ALLOW") }
        static var verdictObserve: String { zh("观察", en: "OBSERVE") }
        static var verdictConfirm: String { zh("待确认", en: "CONFIRM") }
        static var verdictReduce: String { zh("减仓", en: "REDUCE") }
        static var verdictBlock: String { zh("阻断", en: "BLOCK") }
        static var verdictIdle: String { zh("空闲", en: "IDLE") }
        static var verdictSubAllow: String { zh("允许入场", en: "entry permitted") }
        static var verdictSubObserve: String { zh("观察但不操作", en: "watch but do not act") }
        static var verdictSubConfirm: String { zh("等待二次确认", en: "await confirmation") }
        static var verdictSubReduce: String { zh("仓位降至 50%", en: "size to 50%") }
        static var verdictSubBlock: String { zh("阻断新建仓", en: "block new entries") }
        static var verdictSubIdle: String { zh("无活跃裁判", en: "no active guard") }
        static var applyToOrderForm: String { zh("应用到下单表单", en: "Apply to Order Form") }
        static var evidenceMatrix: String { zh("证据矩阵", en: "EVIDENCE MATRIX") }
        static var evidenceMatrixSub: String { zh("· 4 周期 × 3 区域类型", en: "· 4 TF × 3 zone types") }
        static var inShadow: String { zh("影子中", en: "IN SHADOW") }
        static var filled: String { zh("已填充", en: "filled") }
        static var shadowWindows: String { zh("影子窗口", en: "SHADOW WINDOWS") }
        static var shadowWindowsSub: String { zh("· LTF 事件等待 HTF 收盘", en: "· LTF events awaiting HTF close") }
        static var noActiveShadowWindows: String { zh("当前无活跃影子窗口", en: "no active shadow windows") }
        static var statFast: String { zh("快周期", en: "FAST") }
        static var statViol: String { zh("违规", en: "VIOL") }
        static var statReclaim: String { zh("夺回", en: "RECLAIM") }
        static var statFill: String { zh("填充", en: "FILL") }
        static var chargesAndReasons: String { zh("罪状与理由", en: "CHARGES & REASONS") }
        static var noChargesFiled: String { zh("无罪状记录", en: "no charges filed") }
        static var hearingsAndRulings: String { zh("听证与历史裁定", en: "HEARINGS & PAST RULINGS") }
        static var noPastHearings: String { zh("无历史听证", en: "no past hearings") }
        static var cellDetail: String { zh("单元详情", en: "CELL DETAIL") }
        static var detailStatus: String { zh("状态", en: "Status") }
        static var detailStrength: String { zh("强度", en: "Strength") }
        static var detailFilledRatio: String { zh("填充率", en: "Filled Ratio") }
        static var detailAction: String { zh("操作", en: "Action") }
        static var detailShadow: String { zh("影子中", en: "Shadow") }
        static var yesLabel: String { zh("是", en: "yes") }
        static var noLabel: String { zh("否", en: "no") }
        static var reasonCodes: String { zh("理由码", en: "REASON CODES") }
        static var searchSymbols: String { zh("搜索交易对…", en: "search symbols…") }
        static var sectionRecent: String { zh("最近", en: "RECENT") }
        static var sectionAllSymbols: String { zh("全部", en: "ALL SYMBOLS") }
        static var loadFailed: String { zh("无法加载审判庭", en: "Failed to load tribunal") }
        static var retry: String { zh("重试", en: "Retry") }
        static var zoneOrderBlockShort: String { zh("订单块", en: "OrderBlock") }
        static var zoneFvgShort: String { zh("FVG", en: "FVG") }
        static var zoneLiquidityPoolShort: String { zh("流动性池", en: "LiquidityPool") }

        // States
        static var stateHealthy: String { zh("健康", en: "Healthy") }
        static var stateWarning: String { zh("警告", en: "Warning") }
        static var stateViolated: String { zh("违规", en: "Violated") }

        // Regime
        static var trending: String { zh("趋势", en: "Trending") }
        static var ranging: String { zh("震荡", en: "Ranging") }
        static var volatile: String { zh("高波动", en: "Volatile") }
        static var premium: String { zh("溢价区", en: "Premium") }
        static var discount: String { zh("折价区", en: "Discount") }
        static var equilibrium: String { zh("平衡区", en: "Equilibrium") }
    }
}
