---
title: Manipulation Radar — 市场操纵智能识别引擎
status: draft
date: 2026-06-15
authors: claude (product design)
supersedes: none
related:
  - docs/product/ia_backend_redesign.md (§4.3 Manipulation Radar)
  - docs/architecture/00_master_architecture_decision_v2_5.md (ADR-004 ManipulationFilter)
  - backend/app/services/manipulation/ (existing Layer A implementation)
---

# Manipulation Radar — 市场操纵智能识别引擎

## 1. 产品定位

操纵雷达不是一个信息展示页面。它是 AlphaLoop 的**市场操纵行为识别引擎** —— 一个能自主学习、分类、追踪市场操纵行为全生命周期的系统，并在每个阶段给出可交易的建议。

**两类用户画像**：

| 用户类型 | 使用方式 | 核心价值 |
|---------|---------|---------|
| 谨慎型 | 规避被操纵品种，保护本金 | "这个币正在被操纵，别碰" |
| 激进型 | 理解操纵底层逻辑，顺势交易 | "庄家在拉盘初期，可以埋伏跟车" |

**核心主张**：只有理解这个残酷市场的操纵规律，才能产出更好的交易策略。

## 2. 操纵行为分类体系

### 2.1 一级分类（按操纵者类型）

| ID | 类型 | 典型场景 | 数据特征 |
|----|------|---------|---------|
| M1 | **资金协同控盘** | A 股游资/主力合力推高后砸盘 | 大单同向集中出现 → 突然反转；龙虎榜席位重合 |
| M2 | **老庄无规律控盘** | 单一庄家长期驻守某票，无规律拉砸 | 成交量异常集中在少数时段；长期横盘后突然暴力拉升/砸盘 |
| M3 | **KOL 社交拉盘** | 加密一级市场代币，KOL 刷屏推广 | 社交媒体提及量突增 → 价格滞后跟随 → 提及量下降后价格崩盘 |
| M4 | **少数钱包控盘** | 极少量地址持有/控制大部分流通量 | 链上 Top-N 地址集中度极高；转账图谱呈星状 |
| M5 | **跨市场操纵** | DEX 拉现货 → 逼空合约 → 资金费率收割 → 崩盘杀多 | 现货与永续价差剧烈偏离 → 资金费率极端 → 价格剧烈回归 |
| M6 | **Wash Trading** | 自成交刷量，制造虚假流动性 | 买卖价完全一致的高频对手成交；成交量/订单簿深度比异常 |
| M7 | **Spoofing / 幽灵挂单** | 挂大单制造假压力后快速撤单 | 订单簿大单出现 → 价格移动 → 大单消失；挂撤比极高 |
| M8 | **流动性猎杀** | 精确打穿关键止损位后反转 | 价格精准触及密集止损区域 → 成交量骤增 → 快速反转 |

### 2.2 二级分类（按操纵生命周期阶段）

每种操纵行为都有生命周期。**这是产品的核心创新 —— 不只告诉用户"有操纵"，而是告诉用户"操纵到了哪个阶段"以及"你现在该怎么做"**。

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  建仓期   │ →  │  拉升期   │ →  │  派发期   │ →  │  崩盘期   │
│ ACCUMULATE│    │   MARKUP  │    │ DISTRIBUTE│    │  COLLAPSE │
│           │    │           │    │           │    │           │
│ 低调吸筹  │    │ 快速拉升  │    │ 高位震荡  │    │ 价格崩盘  │
│ 量缩价稳  │    │ 量增价升  │    │ 量价背离  │    │ 恐慌抛售  │
│ 筹码集中  │    │ 散户跟风  │    │ 庄家出货  │    │ 无接盘方  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
  ↑                ↑                ↑                ↑
 埋伏              上车             谨慎/离场         绝对回避
 AMBUSH           RIDE             CAUTIOUS          AVOID
```

**阶段判定特征**：

| 阶段 | 核心特征 | 交易建议（激进型） | 交易建议（谨慎型） |
|------|---------|-------------------|-------------------|
| **ACCUMULATE 建仓期** | 成交量萎缩+筹码集中度上升+价格窄幅波动+链上大额转入 | ⚡ 可埋伏 — 跟随早期建仓，仓位小，止损紧 | ⚠ 观望 — 存在操纵迹象，暂不参与 |
| **MARKUP 拉升期** | 放量突破+散户情绪升温+社交提及增加+资金净流入 | 🚀 可上车 — 顺势做多，设好止损不被洗下车 | ⚠ 谨慎 — 已有操纵特征，如参与须严格风控 |
| **DISTRIBUTE 派发期** | 量价背离+高位震荡+大户转出增加+社交 FOMO 达峰 | 🔻 减仓/做空 — 高位分批出货或反手 | 🚫 离场 — 立即清仓，不要贪最后一段 |
| **COLLAPSE 崩盘期** | 价格暴跌+流动性枯竭+资金费率极端反转 | 🚫 回避 — 不要抄底，等稳定后再评估 | 🚫 绝对回避 — 远离 |

### 2.3 操纵案例库（Auto-Learning）

系统维护一个**自动更新的操纵案例库**，每个案例包含：

```
ManipulationCase {
    id: UUID
    type: M1-M8                          // 操纵类型
    symbol: String                       // 涉及品种
    market: "crypto" | "stock"           // 市场
    exchange: String                     // 交易所
    detected_at: DateTime                // 首次检测时间
    lifecycle_stage: "accumulate" | "markup" | "distribute" | "collapse" | "completed"
    confidence: 0.0-1.0                  // 识别置信度
    evidence: {                          // 多维证据
        price_pattern: {...}             // 价格模式特征
        volume_profile: {...}            // 量能分布特征
        onchain_signals: {...}           // 链上信号
        social_signals: {...}            // 社交信号
        orderbook_anomaly: {...}         // 盘口异常
        cross_market: {...}              // 跨市场数据
    }
    timeline: [                          // 生命周期时间线
        { stage, entered_at, features_snapshot }
    ]
    outcome: {                           // 结局（已完成的案例）
        peak_price_change: +340%
        collapse_depth: -87%
        duration_days: 23
        estimated_profit_if_early: +180%
        estimated_loss_if_late: -65%
    }
    similar_historical: [case_id, ...]   // 相似历史案例
    auto_discovered: Boolean             // 是否自动发现
    source: "rule_engine" | "ml_model" | "community_report"
}
```

**案例自动发现机制**：

1. **规则触发** — 当多个检测器同时告警（如筹码集中度 + 社交异常 + 资金费率偏离），自动创建案例
2. **模式匹配** — 将当前市场特征与历史已确认案例的特征做向量相似度匹配
3. **结局回溯** — 对未确认案例持续追踪，当价格走完完整周期后，自动标注结局并加入训练集
4. **社区标注**（可选）— 用户可手动标记"我认为这是操纵"，供系统学习

## 3. 数据层架构

### 3.1 多维数据源

```
┌─────────────────────────────────────────────────────────────┐
│                    MANIPULATION RADAR ENGINE                 │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│  Layer A │  Layer B │  Layer C │  Layer D │    Layer E     │
│  OHLCV   │ ORDERBOOK│ ON-CHAIN │  SOCIAL  │ CROSS-MARKET   │
│          │          │          │          │                │
│ 蜡烛图特征│ 盘口深度  │ 钱包追踪  │ 社交情绪  │ 现货-合约联动  │
│ 成交量    │ 挂撤单比  │ 筹码集中度│ KOL 提及  │ 资金费率      │
│ 技术指标  │ 大单追踪  │ 交易所流入│ 新闻情绪  │ 基差偏离      │
│ 波动率    │ 流动性深度│ DeFi 交互│ 搜索热度  │ 持仓量变化    │
└──────────┴──────────┴──────────┴──────────┴────────────────┘
     ✅            ◐             ◯            ◯             ◯
   已实现       部分可行      需外部API    需外部API     可从交易所获取
```

### 3.2 数据源接入优先级

| 优先级 | 数据源 | 实现方式 | 支撑的检测能力 |
|-------|--------|---------|--------------|
| P0 | OHLCV 蜡烛图 | Freqtrade / 交易所 REST | 价格异常、量价背离、止猎检测 |
| P0 | 资金费率 + 持仓量 | 交易所 REST (Binance/OKX) | 跨市场操纵（M5）、逼空检测 |
| P1 | 订单簿 L2 | 交易所 WebSocket | Spoofing（M7）、流动性猎杀（M8） |
| P1 | 链上钱包追踪 | Etherscan/Solscan API | 少数钱包控盘（M4）、交易所流入 |
| P2 | 社交媒体 | Twitter/Telegram API + NLP | KOL 拉盘（M3）、FOMO 检测 |
| P2 | 新闻情绪 | RSS + 情绪分析 | 协同操纵中的信息配合 |

### 3.3 特征工程

每个品种定期计算以下特征向量（feature snapshot）：

**Layer A — 价格特征**（已实现，需增强）：
- `wick_ratio` — 上下影线比率（止猎信号）
- `volume_zscore` — 成交量 Z-score（异常放量）
- `pump_then_dump` — 快速拉升后回撤比例
- `price_range_spike` — 价格振幅突变
- `volume_price_divergence` — 量价背离度
- **新增**: `consolidation_score` — 横盘压缩度（建仓期特征）
- **新增**: `breakout_velocity` — 突破速度（拉升期特征）
- **新增**: `distribution_signature` — 高位放量滞涨（派发期特征）

**Layer B — 盘口特征**（待实现）：
- `bid_ask_imbalance` — 买卖盘不平衡度
- `large_order_frequency` — 大单出现频率
- `cancel_rate` — 撤单率（Spoofing 信号）
- `depth_volatility` — 订单簿深度波动（幽灵挂单）
- `liquidity_void_score` — 流动性空洞分数

**Layer C — 链上特征**（待实现）：
- `top_holder_concentration` — Top-10 地址持仓集中度
- `exchange_inflow_zscore` — 交易所充值 Z-score（砸盘预警）
- `whale_transfer_count` — 大额转账次数
- `new_wallet_accumulation` — 新钱包建仓速度

**Layer D — 社交特征**（待实现）：
- `social_mention_velocity` — 社交提及增速
- `kol_mention_count` — KOL 提及数
- `sentiment_extreme_score` — 情绪极端度（FOMO/FUD）
- `search_trend_zscore` — 搜索趋势 Z-score

**Layer E — 跨市场特征**（部分可实现）：
- `spot_perp_basis` — 现货-永续基差
- `funding_rate_zscore` — 资金费率 Z-score
- `open_interest_change` — 持仓量变化率
- `long_short_ratio` — 多空比变化
- `liquidation_volume` — 爆仓金额

## 4. 识别算法框架

### 4.1 三层识别架构

```
┌──────────────────────────────────────────────────┐
│            Layer 3: 生命周期追踪器                │
│   Lifecycle Tracker (状态机)                      │
│   输入: 时间序列 anomaly + 案例库匹配            │
│   输出: 当前阶段 + 阶段置信度 + 交易建议          │
├──────────────────────────────────────────────────┤
│            Layer 2: 操纵模式分类器                │
│   Pattern Classifier (规则 + ML)                 │
│   输入: multi-layer feature vector               │
│   输出: 操纵类型 M1-M8 + 置信度                  │
├──────────────────────────────────────────────────┤
│            Layer 1: 异常检测器                    │
│   Anomaly Detectors (per-layer)                  │
│   输入: raw data per layer (A/B/C/D/E)           │
│   输出: per-feature anomaly scores               │
└──────────────────────────────────────────────────┘
```

### 4.2 Layer 1 — 异常检测器

每个数据层独立运行异常检测，输出 0-1 的异常分数：

- **统计方法**: Z-score、IQR、滑动窗口标准差
- **时序方法**: 与自身历史分布比较（lookback 7d/30d/90d）
- **跨品种方法**: 与同板块/同市值品种的均值比较

关键设计：**每个检测器必须输出 `data_quality` 指标**（0-1），表明数据是否可靠。当某个 Layer 数据不可用时，该 Layer 的所有特征标记为 `data_quality = 0`，不参与后续评分。

### 4.3 Layer 2 — 操纵模式分类器

**规则引擎（v1，当前可实现）**：

```python
class ManipulationPatternRules:
    """基于特征阈值的规则分类器"""
    
    def classify(self, features: FeatureSnapshot) -> list[PatternMatch]:
        matches = []
        
        # M5: 跨市场操纵
        if (features.spot_perp_basis_zscore > 3.0 and
            features.funding_rate_zscore > 2.5 and
            features.open_interest_change > 0.3):
            matches.append(PatternMatch(
                type="M5_CROSS_MARKET",
                confidence=min(features.spot_perp_basis_zscore / 5.0, 1.0),
                evidence={"basis": ..., "funding": ..., "oi": ...}
            ))
        
        # M8: 流动性猎杀
        if (features.wick_ratio > 0.7 and
            features.volume_zscore > 2.0 and
            features.price_reversal_speed > 0.8):
            matches.append(PatternMatch(
                type="M8_LIQUIDITY_HUNT",
                confidence=...,
                evidence=...
            ))
        
        # M4: 少数钱包控盘
        if (features.top_holder_concentration > 0.6 and
            features.whale_transfer_count_zscore > 2.0):
            matches.append(PatternMatch(...))
        
        # ... 更多规则
        return matches
```

**ML 模型（v2，后续迭代）**：

- 用历史已标注案例训练分类器
- 输入：多层特征向量
- 输出：M1-M8 概率分布
- 模型选型：XGBoost（可解释性好）或 Transformer（序列模式识别好）
- 关键：**必须输出 evidence/feature importance**，不能是黑箱

### 4.4 Layer 3 — 生命周期追踪器

这是产品的**核心创新**。它是一个**状态机**，追踪每个疑似操纵案例从建仓到崩盘的完整生命周期：

```python
class ManipulationLifecycleTracker:
    """
    状态机：追踪操纵行为生命周期
    
    状态转移:
    SUSPECTED → ACCUMULATE → MARKUP → DISTRIBUTE → COLLAPSE → COMPLETED
                                                              ↗
    任何阶段 → FALSE_ALARM (当证据消失或不再支持)
    """
    
    class State(Enum):
        SUSPECTED    = "suspected"     # 初始疑似
        ACCUMULATE   = "accumulate"    # 建仓期 — 可埋伏
        MARKUP       = "markup"        # 拉升期 — 可上车
        DISTRIBUTE   = "distribute"    # 派发期 — 谨慎/离场
        COLLAPSE     = "collapse"      # 崩盘期 — 回避
        COMPLETED    = "completed"     # 已结束（归档到案例库）
        FALSE_ALARM  = "false_alarm"   # 误报
    
    def evaluate_transition(self, case: ManipulationCase, 
                            new_features: FeatureSnapshot) -> State:
        current = case.lifecycle_stage
        
        if current == State.SUSPECTED:
            # 确认建仓期特征：量缩、价格压缩、筹码集中
            if (new_features.consolidation_score > 0.7 and
                new_features.volume_zscore < -1.0 and
                new_features.top_holder_concentration_delta > 0):
                return State.ACCUMULATE
        
        elif current == State.ACCUMULATE:
            # 进入拉升期：放量突破、散户情绪升温
            if (new_features.breakout_velocity > 0.6 and
                new_features.volume_zscore > 2.0):
                return State.MARKUP
        
        elif current == State.MARKUP:
            # 进入派发期：量价背离、大户转出
            if (new_features.distribution_signature > 0.7 and
                new_features.volume_price_divergence > 0.5):
                return State.DISTRIBUTE
        
        elif current == State.DISTRIBUTE:
            # 进入崩盘期：价格暴跌、流动性枯竭
            if (new_features.price_drop_velocity > 0.8 and
                new_features.volume_zscore > 3.0):
                return State.COLLAPSE
        
        # 误报检测：如果关键特征回归正常
        if self._evidence_weakened(case, new_features):
            return State.FALSE_ALARM
        
        return current  # 保持当前状态
    
    def generate_trading_signal(self, case: ManipulationCase,
                                user_profile: str) -> TradingSignal:
        """根据阶段和用户画像生成交易建议"""
        stage = case.lifecycle_stage
        
        if user_profile == "conservative":
            return CONSERVATIVE_SIGNALS[stage]
        else:  # aggressive
            return AGGRESSIVE_SIGNALS[stage]

AGGRESSIVE_SIGNALS = {
    State.ACCUMULATE: TradingSignal(
        action="AMBUSH",          # 埋伏
        direction="long",
        sizing="small",           # 小仓位
        stop_loss="tight",        # 紧止损
        rationale="操纵者建仓期，可小仓位跟随埋伏",
        risk_level="high",
    ),
    State.MARKUP: TradingSignal(
        action="RIDE",            # 上车
        direction="long",
        sizing="medium",
        stop_loss="trailing",     # 追踪止损，不被洗下车
        rationale="拉升期确认，顺势跟车，设追踪止损防止被洗出",
        risk_level="medium",
    ),
    State.DISTRIBUTE: TradingSignal(
        action="EXIT_OR_SHORT",   # 减仓/反手
        direction="short",
        sizing="reduce",
        stop_loss="tight",
        rationale="派发期信号，高位减仓或反手做空",
        risk_level="high",
    ),
    State.COLLAPSE: TradingSignal(
        action="AVOID",
        direction="none",
        rationale="崩盘进行中，不要抄底",
        risk_level="extreme",
    ),
}

CONSERVATIVE_SIGNALS = {
    State.ACCUMULATE: TradingSignal(action="WATCH", rationale="存在操纵迹象，持续观察"),
    State.MARKUP: TradingSignal(action="CAUTION", rationale="操纵拉升中，如参与需严格风控"),
    State.DISTRIBUTE: TradingSignal(action="EXIT", rationale="立即清仓，不贪最后一段"),
    State.COLLAPSE: TradingSignal(action="AVOID", rationale="绝对回避"),
}
```

## 5. 案例库自动更新机制

### 5.1 案例生命周期

```
[自动发现] → [追踪中] → [结局确认] → [归档+特征抽取] → [训练集]
                ↓
          [误报标注] → [反例训练集]
```

### 5.2 自动发现触发条件

当满足以下任一条件时，自动创建新案例：

| 触发器 | 条件 | 初始阶段 |
|--------|------|---------|
| 多检测器共振 | ≥3 个 Layer 的异常分数同时 > 0.7 | SUSPECTED |
| 历史模式匹配 | 与已确认案例特征相似度 > 0.85 | 匹配到的阶段 |
| 资金费率极端 | funding_rate_zscore > 4.0 且 OI 大增 | SUSPECTED (M5) |
| 链上异常 | Top-10 地址集中度突增 > 20% | ACCUMULATE (M4) |
| 社交爆发 | KOL 提及增速 > 10x 且价格未动 | SUSPECTED (M3) |

### 5.3 结局自动标注

案例创建后持续追踪 30 天。当满足以下条件时自动标注结局：

- **确认操纵**: 价格经历完整 "拉升→崩盘" 周期（从高点回落 > 50%）
- **误报**: 30 天内价格走势平稳，无异常特征持续触发
- **未确认**: 30 天后仍有异常信号但未完成完整周期 → 继续追踪

已确认案例的特征快照自动加入训练集，供 ML 模型学习。

## 6. 策略集成 — 交易管线联动

### 6.1 DSL Filter Rule

现有 `ManipulationScoreFilterRule` 增强为生命周期感知：

```python
class ManipulationFilterRule:
    max_overall_score: float = 0.6         # 总分阈值
    blocked_stages: list = ["distribute", "collapse"]  # 禁止交易的阶段
    allowed_stages: list = ["accumulate", "markup"]     # 允许交易的阶段
    min_confidence: float = 0.7            # 最低识别置信度
    user_profile: str = "conservative"     # 用户画像
    missing_data_policy: str = "reject"    # 数据缺失时策略
```

### 6.2 Pre-Trade Gate

在交易执行前，检查目标品种的操纵状态：

```
策略发出交易信号 → ManipulationFilter 检查 →
  ├── 无操纵记录 → ALLOW
  ├── 有操纵 + 在 allowed_stages → ALLOW (附带风控约束)
  ├── 有操纵 + 在 blocked_stages → REJECT (记录 reason_code)
  └── 数据不足 → 按 missing_data_policy 处理
```

### 6.3 运行时信号推送

当追踪中的案例发生阶段转换时，向相关策略发送通知：

```python
ManipulationStageChangeEvent {
    case_id: UUID
    symbol: "SOL/USDT"
    old_stage: "markup"
    new_stage: "distribute"
    confidence: 0.82
    signal: TradingSignal(action="EXIT_OR_SHORT", ...)
    affected_strategies: ["BTC Momentum v3", "SOL Breakout"]
}
```

## 7. 后端实现规划

### 7.1 新增服务

| 服务 | 职责 | 优先级 |
|------|------|--------|
| `ManipulationFeatureEngine` | 多层特征计算 (A→E) | P0 |
| `ManipulationPatternClassifier` | 操纵类型识别 (M1-M8) | P0 |
| `ManipulationLifecycleTracker` | 生命周期状态机 | P0 |
| `ManipulationCaseRepository` | 案例库 CRUD + 自动发现 | P0 |
| `ManipulationSignalGenerator` | 交易建议生成 | P1 |
| `FundingRateAdapter` | 资金费率数据接入 | P0 |
| `OpenInterestAdapter` | 持仓量数据接入 | P0 |
| `OnChainAdapter` | 链上数据接入 (Etherscan/Solscan) | P2 |
| `SocialSentimentAdapter` | 社交数据接入 | P2 |

### 7.2 新增 API 端点

```
GET  /api/v2/manipulation/radar            # 雷达总览（活跃案例列表+统计）
GET  /api/v2/manipulation/cases            # 案例库（含历史）
GET  /api/v2/manipulation/cases/{id}       # 案例详情+时间线
POST /api/v2/manipulation/scan             # 手动扫描（已有）
GET  /api/v2/manipulation/alerts           # 实时告警流
GET  /api/v2/manipulation/features/{symbol}# 某品种的多层特征快照
POST /api/v2/manipulation/cases/{id}/label # 用户手动标注
GET  /api/v2/manipulation/signals          # 当前交易建议
WS   /api/v2/manipulation/stream           # WebSocket 实时推送
```

### 7.3 数据模型

```python
class ManipulationCase(Base):
    __tablename__ = "manipulation_cases"
    
    id = Column(UUID, primary_key=True)
    symbol = Column(String, index=True)
    market = Column(String)              # crypto / stock
    manipulation_type = Column(String)   # M1-M8
    lifecycle_stage = Column(String)     # suspected/accumulate/markup/distribute/collapse/completed/false_alarm
    confidence = Column(Float)
    evidence = Column(JSONB)             # multi-layer evidence
    timeline = Column(JSONB)             # stage transition history
    outcome = Column(JSONB)              # final results (for completed cases)
    similar_cases = Column(JSONB)        # references to similar historical cases
    auto_discovered = Column(Boolean, default=True)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    completed_at = Column(DateTime, nullable=True)

class ManipulationAlert(Base):
    __tablename__ = "manipulation_alerts"
    
    id = Column(UUID, primary_key=True)
    case_id = Column(UUID, ForeignKey("manipulation_cases.id"))
    alert_type = Column(String)          # stage_change / new_case / anomaly_spike / signal
    severity = Column(String)            # info / warning / critical
    title = Column(String)
    detail = Column(JSONB)
    trading_signal = Column(JSONB)       # TradingSignal if applicable
    created_at = Column(DateTime)
```

## 8. 前端 UI 设计方向

基于以上引擎能力，UI 应围绕三个核心交互设计：

### 8.1 雷达总览 — "我的资产中有多少正在被操纵？"

- 活跃案例卡片网格（按生命周期阶段分组）
- 每张卡片：品种 + 操纵类型 + 当前阶段 + 交易建议 + 置信度
- 阶段进度指示器（ACCUMULATE → MARKUP → DISTRIBUTE → COLLAPSE）

### 8.2 案例详情 — "这个操纵是怎么发生的？我该怎么做？"

- 生命周期时间线（每个阶段的进入时间 + 关键特征快照）
- 多层证据面板（OHLCV / 盘口 / 链上 / 社交 / 跨市场 — 展示每层的异常信号）
- 交易建议卡片（根据用户画像切换保守/激进建议）
- 相似历史案例对比

### 8.3 案例库 — "历史上类似的操纵是什么结局？"

- 已完成案例的统计（成功识别率、平均获利/亏损、各类型分布）
- 可搜索/筛选的历史案例
- 学习功能："为什么系统认为这是操纵？" — 展示特征权重

### 8.4 告警流 — "现在正在发生什么？"

- 实时告警时间线（阶段转换、新案例发现、异常飙升）
- 关联到具体策略的影响评估

## 9. 实现路线图

| 阶段 | 内容 | 周期 |
|------|------|------|
| **Phase 1** | 增强 Layer A 特征（+建仓/拉升/派发/崩盘特征）+ 生命周期状态机 + 案例库 + 手动标注 | 1-2 周 |
| **Phase 2** | Layer E 跨市场数据（资金费率+持仓量+基差）+ M5 跨市场操纵识别 | 1 周 |
| **Phase 3** | 前端 UI 重建（雷达总览+案例详情+告警流）+ L10n | 1 周 |
| **Phase 4** | Layer B 盘口数据 + Spoofing/幽灵挂单检测 | 1-2 周 |
| **Phase 5** | Layer C 链上数据 + 钱包控盘检测 | 2 周 |
| **Phase 6** | Layer D 社交数据 + KOL 拉盘检测 | 2 周 |
| **Phase 7** | ML 模型训练 + 自动案例发现优化 | 持续 |

## 10. 与现有系统的关系

- **Structure Matrix** — 操纵雷达的输出（manipulationScore）已经是矩阵的一列；生命周期阶段可作为新列
- **Risk Center** — 操纵雷达的 blocked_stages 直接供给 ManipulationFilter 作为 Layer 1 风控门
- **Signal Center** — 操纵雷达的 TradingSignal 可作为信号源之一，供策略订阅
- **Dashboard** — 活跃操纵案例数 + 高危品种数可作为 Dashboard 的告警项
- **Strategy DSL** — ManipulationFilterRule 已集成，需增强为生命周期感知
