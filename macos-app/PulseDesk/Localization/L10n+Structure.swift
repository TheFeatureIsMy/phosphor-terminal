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
