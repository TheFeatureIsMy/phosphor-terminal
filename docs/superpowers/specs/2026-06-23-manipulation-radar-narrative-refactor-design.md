---
title: Manipulation Radar — 九段叙事流页面重构
status: draft
date: 2026-06-23
authors: claude (product design)
supersedes:
  - docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md (§8 UI 设计方向)
related:
  - docs/superpowers/specs/2026-06-10-market-structure-causal-storyboard-design.md
  - docs/superpowers/specs/2026-06-10-structure-matrix-htf-tribunal-design.md
  - docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md (引擎层不变)
---

# Manipulation Radar — 九段叙事流页面重构

> **本 spec 仅取代 [2026-06-15-manipulation-radar-engine-design.md](2026-06-15-manipulation-radar-engine-design.md) 的第 8 章「前端 UI 设计方向」。**
> 引擎层、案例库、生命周期状态机、EvidenceSnapshot、历史扫描、训练管线全部保持不变 — 本 spec 只重做用户可见的页面与少量必要的 API 形态。

---

## 1. 背景与问题

当前 `ManipulationRadarView` 是「头部 + Stats Row + 双栏（案例网格 + 告警流）」的仪表板布局，案例详情通过 sheet 弹出。这个结构有四个问题：

1. **视觉风格游离** — 与同属"结构"分组的 `MarketStructureView`（SMC 因果叙事）和 `StructureMatrixView`（HTF 法庭叙事）不是同一家族。两个参考页都是单 symbol 多章节垂直流，带 ⌘K SymbolPicker、`staggeredAppearance` 入场、1200~1280 居中宽度、KryptonCard / TerminalLabel 章节卡。
2. **证据深度不足** — 13 项操纵风险信号（异常成交量、流动性异常、巨鲸异动、筹码集中度变化、资金费率/OI、社媒加速、风险等级、置信度、证据来源、影响交易对、防御建议、是否影响当前策略、是否触发风控）当前只在 sheet 里塞一个扁平 evidence 字典，无层次、无 data quality、无策略联动可见性。
3. **语气过度确定** — 当前 sheet 用 "Detected" / "Manipulation case" 这类定罪式词汇。操纵识别本质是统计推断，不能写成确定结论。
4. **激进/保守画像被简化为顶部 toggle** — 用户切换后视觉跳变，难以对比两种立场。

## 2. 设计目标

- **A. 风格家族对齐** — 视觉骨架、章节排布、动画时序与 `MarketStructureView` / `StructureMatrixView` 一致。
- **B. 单 case 叙事流** — 主体围绕"当前聚焦的一个 case"逐章节铺开 13 项风险信号；多 case 入口收敛为顶部 Hero Strip。
- **C. 诚实表达不确定性** — 概率语言（"疑似" / "证据指向"）+ 可视化诚实（置信度条、data_quality 徽章、available/missing layers）+ 顶部系统级免责声明。
- **D. 双画像并列** — 取消顶部 toggle，把保守/激进两种交易建议在同章节左右并列，让用户直接对比立场。
- **E. 策略与风控联动可见** — 明确标注"该 case 影响当前哪些策略" / "ManipulationFilter 是否会阻断它"。

## 3. 信息架构 — 九段叙事流

按从上到下的阅读路径排布：

```
┌─────────────────────────────────────────────────────────────────────┐
│ Masthead   ALPHALOOP · MANIPULATION RADAR · STATISTICAL INFERENCE   │
│            "evidence-based suspicion, not a verdict"                │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 0  Active Cases Strip  (horizontal scroll)                        │
│      [PEPE/USDT M3 ▍distrib 85%]  [SOL/USDT M5 ▎markup 78%]  …      │
│      点击任一卡片 → 切换下方所有章节的聚焦 case                       │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 1  Verdict Panel  (focused case)                                  │
│      M-type 标签 + 阶段进度条 + 置信度环 + 风险等级 + 数据完整度       │
│      "Likely Cross-Market Squeeze · markup stage · confidence 78%"  │
│      ⓘ 这是基于多层数据信号的统计推断，不是定罪。                       │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 2  Lifecycle Timeline                                             │
│      SUSPECTED → ACCUMULATE → MARKUP →[ DISTRIBUTE ]→ COLLAPSE       │
│      每个节点：进入时间 + 当时置信度 + 关键特征快照(可点击展开)         │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 3  Evidence Matrix  (5 Layers × n features)                       │
│      Layer A 价格量能   ▮▮▮▮▯ 0.78  quality 0.95                     │
│      Layer B 盘口流动性 ▮▮▯▯▯ 0.42  quality 0.60                     │
│      Layer C 链上集中度 ▮▮▮▯▯ 0.65  quality 0.55                     │
│      Layer D 社交加速   —    quality 0.10  ⚠ Data unavailable        │
│      Layer E 跨市场     ▮▮▮▮▮ 0.89  quality 0.85                     │
│      每行可展开 → 看到该 Layer 的具体特征 + z-score + 历史分位          │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 4  Whale & Concentration  (Layer C 详情放大)                       │
│      Top-10 持仓集中度变化曲线 + 近 24h 大额转账 + 交易所充值净流入     │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 5  Cross-Market Pressure  (Layer E 详情放大)                       │
│      资金费率 z-score + 现货-永续基差 + OI 变化 + 多空比 + 24h 爆仓     │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 6  Social Acceleration  (Layer D 详情放大，可缺失)                  │
│      Twitter/Telegram 提及增速 + KOL 提及时间线 + 情绪极端度           │
│      若 data_quality < 0.3 整段显示 "Data unavailable" 占位          │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 7  Defense & Strategy Impact                                      │
│      ┌─────────────────────┬─────────────────────┐                  │
│      │ CONSERVATIVE        │ AGGRESSIVE          │                  │
│      │ EXIT — 立即清仓     │ EXIT_OR_SHORT       │                  │
│      │ rationale …        │ rationale …        │                  │
│      │ 风险等级 ●●●        │ 风险等级 ●●●○        │                  │
│      └─────────────────────┴─────────────────────┘                  │
│      影响交易对：[SOL/USDT, SOL/USDC, …]                              │
│      当前策略联动：                                                   │
│        • "BTC Momentum v3"   ✅ ManipulationFilter 将阻断             │
│        • "SOL Breakout v2"   ⚠ ManipulationFilter 已禁用，请检查      │
│      → 跳转策略风控配置                                                │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 8  Alert Feed  +  Similar Historical Cases                        │
│      左半：该 case 的实时告警时间线（阶段切换/异常飙升）                │
│      右半：相似历史案例（基于 evidence 向量相似度），含 outcome 结局     │
└─────────────────────────────────────────────────────────────────────┘
```

宽度：与 `StructureMatrixView` 对齐为 `frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)`。

每段使用 `.staggeredAppearance(index: N)` 依序入场，间距 `PulseSpacing.xl`。

## 4. 视觉风格契约（与参考页对齐）

> 复用项，不引入新原语；只新增 4 个轻量子组件。

| 元素 | 复用自 |
|------|--------|
| 章节卡片 | `KryptonCard(emphasis: .subtle/.standard)` |
| 章节小标题 | `TerminalLabel(text:)` |
| 入场动画 | `.staggeredAppearance(index:)` |
| 颜色 | `PulseColors.*` — 阶段颜色映射沿用现有 LifecycleIndicator |
| 字体 | `PulseFonts.displayHeading/displaySubheading/tabular/micro` |
| 弹层 | 抽屉式 `StructureDetailDrawer` 同款模式（用于 Evidence 行展开） |
| Hero 入口 | 顶部 Symbol Picker — 不需要 ⌘K（聚焦切换走 Hero Strip 点击） |

**新增 4 个组件**（全部放在 `Views/Manipulation/Components/`）：

| 组件 | 职责 | 行数预算 |
|------|------|---------|
| `ActiveCasesStrip` | § 0 — 横向滚动的活跃 case 缩略卡 | ~120 行 |
| `VerdictPanel` | § 1 — M-type 标签 + 阶段进度 + 置信度环 + 数据完整度 | ~180 行 |
| `EvidenceLayerMatrix` | § 3 — 5 Layer × n feature 矩阵 + data_quality 徽章 | ~200 行 |
| `DualProfileSignalPanel` | § 7 — 保守/激进双栏 + 策略联动列表 | ~180 行 |

§ 2 Lifecycle Timeline 复用现有 `LifecycleIndicator.swift` 的色板与图标，但重写为水平时间线版本（不再是当前的简单进度条）。

§ 4/§5/§6/§8 用 KryptonCard + Swift Charts（资金费率折线、集中度曲线、提及速率柱状）；图表样式与 BacktestLab CurvePanel 一致。

## 5. 不确定性表达契约

### 5.1 文案前缀

所有判定文案在 L10n 层统一改成概率前缀：

| ❌ 旧（定罪式） | ✅ 新（统计推断） |
|----------------|------------------|
| "Manipulation detected" | "Likely manipulation pattern" / "疑似操纵迹象" |
| "Confirmed M5" | "Evidence consistent with M5" / "证据指向 M5" |
| "Distribution phase" | "Likely in distribution phase" / "疑似处于派发期" |

### 5.2 可视化诚实

- 每个 evidence 维度旁显示 `quality 0.55` 徽章，<0.3 整段标 "Data unavailable"
- Verdict Panel 显示 "Data completeness 3/5 layers" — 仅基于可用 Layer 计算
- 置信度环显示置信度上限 = `min(completeness × 1.2, 1.0)`，与设计文档 §12.4 一致

### 5.3 系统级免责声明

Masthead 下方一行：

> ⓘ AlphaLoop's manipulation radar is a statistical inference system. It surfaces evidence-based suspicions, not verdicts. Use it as one input among many.

L10n 键：`L10n.Manipulation.disclaimer`。

## 6. 双画像并列展示

§ 7 章节用一个 `HStack` 左右两栏 KryptonCard：

- 左：CONSERVATIVE（PulseColors.info 色调） — 显示 `signal.conservative.{action, rationale, sizing}`
- 右：AGGRESSIVE（PulseColors.amber 色调） — 显示 `signal.aggressive.{action, rationale, sizing, stop_loss}`

两栏下方共享：
- 影响交易对 chip 列表（数据源：当前 case 的 symbol + 同合约地址品种）
- 当前策略联动列表（数据源：新增 API `/cases/{id}/strategy-impact`）
- 跳转按钮 → `AppRoute.riskCenter`（如已有）或 `AppRoute.strategyWorkspace`（编辑策略 ManipulationFilter）

顶部 `userProfile` toggle 删除。`ManipulationViewModel.userProfile` / `toggleUserProfile()` 不再使用（保留属性以便后续 polling 默认还能传一个画像参数给 `/signals`，不破坏后端契约）。

## 7. 后端 API 补齐

### 7.1 改造 `GET /api/v2/manipulation/cases/{id}`

返回结构化分 Layer evidence + data_quality 字段。新形态：

```json
{
  "id": "...",
  "symbol": "SOL/USDT",
  "market": "crypto",
  "manipulation_type": "M5",
  "lifecycle_stage": "markup",
  "confidence": 0.78,
  "risk_level": "high",
  "evidence_layers": {
    "A_price":        { "available": true,  "data_quality": 0.95, "score": 0.78,
                        "features": [{ "name": "volume_zscore", "value": 2.4, "percentile": 0.92 }, …] },
    "B_orderbook":    { "available": true,  "data_quality": 0.60, "score": 0.42, "features": [...] },
    "C_onchain":      { "available": true,  "data_quality": 0.55, "score": 0.65, "features": [...] },
    "D_social":       { "available": false, "data_quality": 0.10, "score": null, "features": [],
                        "reason": "no adapter configured" },
    "E_cross_market": { "available": true,  "data_quality": 0.85, "score": 0.89, "features": [...] }
  },
  "completeness": 0.80,
  "max_confidence": 0.96,
  "timeline": [...],
  "trading_signal": {
    "conservative": { "action": "EXIT",        "rationale": "…", "sizing": "all", "risk_level": "high" },
    "aggressive":   { "action": "EXIT_OR_SHORT","rationale": "…", "sizing": "reduce", "stop_loss": "tight", "risk_level": "high" }
  },
  "affected_symbols": ["SOL/USDT", "SOL/USDC"],
  "sources": [{ "type": "rule_engine", "rule_id": "M5_CROSS_MARKET", "version": "v1.2" }],
  "created_at": "...", "updated_at": "..."
}
```

`trading_signal` 必须同时包含 conservative 与 aggressive 两份。后端实现：在 `lifecycle.py` 的 `generate_signal` 基础上加一个 `generate_dual_signal(stage)` 返回 `{conservative, aggressive}`。

向后兼容：`evidence` 旧字段保留为扁平 `{feature_name: value}`（取所有 layer 的 features flatten），便于尚未升级的客户端读取。

### 7.2 新增 `GET /api/v2/manipulation/cases/{id}/strategy-impact`

返回：

```json
{
  "case_id": "...",
  "affected_strategies": [
    {
      "strategy_id": "uuid",
      "name": "BTC Momentum v3",
      "matches_symbols": ["SOL/USDT"],
      "manipulation_filter": {
        "enabled": true,
        "would_block": true,
        "reason_codes": ["lifecycle_stage_blocked", "stage=markup"]
      }
    },
    {
      "strategy_id": "uuid",
      "name": "SOL Breakout v2",
      "matches_symbols": ["SOL/USDT"],
      "manipulation_filter": {
        "enabled": false,
        "would_block": false,
        "reason_codes": ["filter_disabled"]
      }
    }
  ],
  "total_affected": 2,
  "total_protected": 1
}
```

实现：扫描 `strategies` 表，对每个 enabled 策略解析其 DSL，检查 `ManipulationFilterRule` 配置与 case symbol 命中关系。

### 7.3 新增 `GET /api/v2/manipulation/cases/{id}/similar`

```json
{
  "case_id": "...",
  "similar": [
    {
      "id": "...", "symbol": "LUNA/USDT", "manipulation_type": "M5",
      "similarity": 0.87,
      "outcome": { "peak_change": 2.4, "collapse_depth": -0.92, "duration_days": 14 },
      "completed_at": "2025-08-15T00:00:00Z"
    }
  ],
  "total": 3
}
```

实现：复用 `case_repository` 已有的 evidence 向量；用余弦相似度对历史 completed 案例排序，top-N。

### 7.4 新增 `WS /api/v2/manipulation/stream`

推送两类事件：

- `stage_change` — `{ case_id, symbol, old_stage, new_stage, confidence, timestamp }`
- `new_case` — `{ case_id, symbol, manipulation_type, initial_stage, confidence, timestamp }`

实现：FastAPI WebSocket endpoint + 一个简单的 in-process pub/sub（`asyncio.Queue` per connection）。`case_repository` 在 `update_stage` / `create_case` 时 publish。

macOS 端：`URLSessionWebSocketTask` 维护连接，收到事件后更新 `ManipulationViewModel.alerts` 并触发 `loadCaseDetail` 刷新当前聚焦 case。

### 7.5 API 错误降级

所有新端点遵循现有 `state: "data_source_unavailable", reason_codes: [...]` 模式（与 `radar` / `cases` 等已实现端点一致）。

## 8. 数据流与状态机

```
┌──────────────────────┐
│ ManipulationViewModel│
│  - activeCases       │ ← polling /radar 每 30s
│  - focusedCaseId     │ ← Hero Strip 点击切换
│  - focusedDetail     │ ← /cases/{id}        — 含 evidence_layers
│  - strategyImpact    │ ← /cases/{id}/strategy-impact
│  - similar           │ ← /cases/{id}/similar
│  - alerts            │ ← /alerts (polling) + /stream (WS push)
└──────────────────────┘
        ↓                                       ↑
   ManipulationRadarView (9 sections)      EventStream
                                          (WebSocket)
```

聚焦切换约束：`focusedCaseId == nil` 时，自动选 `activeCases[0]`。点击 Hero Strip 卡片 → `focusedCaseId = card.id` → 并行触发 detail / strategyImpact / similar 三个请求。

## 9. L10n 新增键

`Localization/L10n+Manipulation.swift` 在现有键基础上新增：

```swift
// Disclaimer & uncertainty
static var disclaimer: String { zh("操纵雷达是统计推断系统，输出"基于证据的怀疑"而非"定罪"。请结合多源信息独立判断。",
                                    en: "Manipulation radar is a statistical inference system; surfaces evidence-based suspicions, not verdicts.") }
static var likely: String { zh("疑似", en: "Likely") }
static var evidenceConsistentWith: String { zh("证据指向", en: "Evidence consistent with") }
static var dataUnavailable: String { zh("数据不可用", en: "Data unavailable") }
static var dataQuality: String { zh("数据完整度", en: "Data quality") }
static var dataCompleteness: String { zh("数据完整度", en: "Data completeness") }
static var maxConfidence: String { zh("置信上限", en: "Max confidence") }

// Section titles (§1-§8)
static var verdict: String { zh("判定", en: "VERDICT") }
static var lifecycleTimeline: String { zh("生命周期", en: "LIFECYCLE") }
static var evidenceMatrix: String { zh("证据矩阵", en: "EVIDENCE MATRIX") }
static var whaleConcentration: String { zh("巨鲸与筹码集中", en: "WHALE & CONCENTRATION") }
static var crossMarketPressure: String { zh("跨市场压力", en: "CROSS-MARKET PRESSURE") }
static var socialAcceleration: String { zh("社交加速", en: "SOCIAL ACCELERATION") }
static var defenseStrategyImpact: String { zh("防御与策略联动", en: "DEFENSE & STRATEGY IMPACT") }
static var similarHistoricalCases: String { zh("相似历史案例", en: "SIMILAR HISTORICAL CASES") }

// Layer labels
static var layerPrice: String { zh("Layer A · 价格量能", en: "Layer A · Price/Volume") }
static var layerOrderbook: String { zh("Layer B · 盘口流动性", en: "Layer B · Orderbook Liquidity") }
static var layerOnchain: String { zh("Layer C · 链上", en: "Layer C · On-Chain") }
static var layerSocial: String { zh("Layer D · 社交新闻", en: "Layer D · Social & News") }
static var layerCrossMarket: String { zh("Layer E · 跨市场", en: "Layer E · Cross-Market") }

// Defense panel labels
static var affectedSymbols: String { zh("影响交易对", en: "Affected symbols") }
static var strategyImpact: String { zh("当前策略联动", en: "Strategy impact") }
static var wouldBlock: String { zh("将阻断", en: "Will block") }
static var filterDisabled: String { zh("过滤器未启用", en: "Filter disabled") }
static var openStrategyRisk: String { zh("跳转风控配置", en: "Open risk config") }

// Feature names (Layer C/E)
static var featTop10Concentration: String { zh("Top-10 集中度", en: "Top-10 concentration") }
static var featExchangeInflow: String { zh("交易所充值", en: "Exchange inflow") }
static var featFundingRate: String { zh("资金费率", en: "Funding rate") }
static var featOpenInterest: String { zh("持仓量", en: "Open interest") }
static var featLongShortRatio: String { zh("多空比", en: "Long/Short ratio") }
static var featBasis: String { zh("现货-永续基差", en: "Spot-perp basis") }
// … 其余维度按需在实现时补
```

## 10. 替换与删除清单

| 文件 | 操作 |
|------|------|
| `Views/Manipulation/ManipulationRadarView.swift` | 重写为九段叙事流根视图 |
| `Views/Manipulation/CaseCardView.swift` | 重写为 Hero Strip 缩略卡 (`ActiveCasesStripCard`)，移到 `Components/ActiveCasesStrip.swift` 内 |
| `Views/Manipulation/CaseDetailView.swift` | **删除**（sheet 模式废弃；详情就是主页面） |
| `Views/Manipulation/LifecycleIndicator.swift` | 保留色板与图标映射 helper；视图重写为水平时间线 |
| `Views/Manipulation/ManipulationAlertFeed.swift` | 保留并作为 § 8 左半子视图 |
| `Views/Manipulation/Components/ActiveCasesStrip.swift` | **新增** |
| `Views/Manipulation/Components/VerdictPanel.swift` | **新增** |
| `Views/Manipulation/Components/LifecycleTimeline.swift` | **新增**（取代旧 LifecycleIndicator 的视图部分） |
| `Views/Manipulation/Components/EvidenceLayerMatrix.swift` | **新增** |
| `Views/Manipulation/Components/WhaleConcentrationPanel.swift` | **新增** |
| `Views/Manipulation/Components/CrossMarketPressurePanel.swift` | **新增** |
| `Views/Manipulation/Components/SocialAccelerationPanel.swift` | **新增** |
| `Views/Manipulation/Components/DualProfileSignalPanel.swift` | **新增** |
| `Views/Manipulation/Components/SimilarCasesPanel.swift` | **新增** |
| `ViewModels/ManipulationViewModel.swift` | 加 `focusedCaseId / strategyImpact / similar` 状态 + WS 处理 |
| `Services/APIManipulation.swift` | 新增 `getStrategyImpact / getSimilar` 方法 + 升级 `ManipulationCaseDetail` 模型为分 Layer + 新增 WS 接入 |
| `Localization/L10n+Manipulation.swift` | 追加 § 9 所列键 |
| `backend/app/routers/manipulation.py` | 改造 `/cases/{id}`，新增 `/strategy-impact /similar /stream` |
| `backend/app/services/manipulation/lifecycle.py` | 加 `generate_dual_signal()` |
| `backend/app/services/manipulation/case_repository.py` | 加 `find_similar()` + pub/sub hooks |
| `backend/app/schemas/manipulation.py` | 加 `CaseDetailV2 / StrategyImpactResponse / SimilarCasesResponse` |

## 11. 文档同步

| 文档 | 改动 |
|------|------|
| `CLAUDE.md` | `Views/Manipulation/ManipulationRadarView` 描述改为"九段叙事流，按 § 0-§ 8 顺序展示" |
| `docs/user-guide/content/{zh,en}/pages/manipulation-radar.html` | 重写（章节顺序、不确定性声明、双画像对比、策略联动入口） |
| `docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md` | 在 frontmatter 顶部加 `superseded-by: 2026-06-23-... (§8 only)` 注记 |

## 12. 实施分期

| Phase | 内容 |
|-------|------|
| **P1 — 后端 API 补齐** | `/cases/{id}` 分 Layer + dual signal；`/strategy-impact`；`/similar`；schemas；服务层 `find_similar` / `generate_dual_signal`。先于 UI 落，便于 mock 切换到 live |
| **P2 — macOS 模型 + ViewModel** | `ManipulationCaseDetailV2` 与所有 Codable 子结构；ViewModel 增加状态；API 服务方法 + mock |
| **P3 — UI 九段** | § 0 Hero Strip → § 1 Verdict → § 2 Lifecycle → § 3 Evidence Matrix → § 4-§ 6 三个 Layer 详情 → § 7 Defense & Impact → § 8 Alerts + Similar |
| **P4 — WebSocket 实时推送** | 后端 `/stream` + macOS `URLSessionWebSocketTask` 接入；AlertFeed 改实时；阶段切换自动刷新聚焦 case |
| **P5 — L10n + 文档** | 追加 L10n 键；CLAUDE.md / user-guide / 旧 spec frontmatter 更新 |

每个 Phase 末尾 `swift build` + `pytest` 必须通过。

## 13. 验收清单

- [ ] 页面骨架 — 1280 居中、九段 `staggeredAppearance`、`KryptonCard` 与 `TerminalLabel` 全部复用
- [ ] 文案 — 所有判定文案使用概率前缀；Masthead 下方有 disclaimer
- [ ] 数据完整度 — Verdict 显示 N/5 layers + max confidence；每 Layer 显示 data_quality；缺失 Layer 标 Data unavailable
- [ ] 双画像 — § 7 同时呈现 conservative 与 aggressive，删除顶部 toggle
- [ ] 策略联动 — § 7 列出受影响策略 + filter 状态 + 跳转风控配置入口
- [ ] 相似案例 — § 8 右半呈现 top-N 相似历史 case 含 outcome
- [ ] 实时性 — WS 推送阶段切换后，自动刷新聚焦 case 与 alerts
- [ ] L10n — 所有新文案 zh/en 双语
- [ ] 后端测试 — `/cases/{id}` v2、`/strategy-impact`、`/similar`、`/stream` 都有 pytest 覆盖
- [ ] 旧 spec frontmatter 标注 superseded-by

## 14. 实现注意（避免下一个模型踩坑）

### 14.1 后端

- **案例库是 in-memory（`case_repository.py` v1）**。新增的 `find_similar()` 也要在内存里实现，不依赖任何数据库。pub/sub 同样在进程内，进程重启所有 case 与 WS 订阅都会丢，这是 v1 既有约束，不在本 spec 修复范围。
- **`/cases/{id}` 改造必须向后兼容**：保留扁平 `evidence` 字段（由 `evidence_layers` 各 layer features flatten 出来），同时新增 `evidence_layers`。其他客户端（Dashboard 的 manipulation 卡、Structure Matrix 的 manipulationScore 列）仍读旧字段。
- **现 case_repository 不存 evidence 向量**。create_case 接收的 `evidence: dict` 是扁平字典。本次需要：
  1. 升级 `create_case()` 接受可选 `evidence_layers: dict[str, dict]` 参数（默认 None，向后兼容）
  2. 内部存储时把 `evidence_layers` 一并存到 case dict 里
  3. `find_similar()` 基于 `evidence_layers` 各 layer score 拼成向量做余弦相似度；缺失 layer 用 0 填充
  4. `historical_scan` 与 rule_engine 调用路径都要适配新参数（旧的扁平 evidence 仍接受，新写入要补 evidence_layers）
- **DSL 规则名是 `manipulation_score_filter`**（不是 `ManipulationFilterRule`）。`/strategy-impact` 要扫描策略 DSL 的 `rules` 数组，找 `type == "manipulation_score_filter"` 的规则，读出 `max_overall_score / blocked_stages / min_confidence / missing_data_policy` 字段判断是否会阻断。规则解析逻辑放到一个新文件 `services/manipulation/strategy_impact.py`，不要污染 dsl_interpreter。
- **WebSocket 已有先例**：`backend/app/routers/providers_ws.py` 用 `asyncio.Queue` + 心跳。新的 `manipulation_ws.py` 直接照这个模板写，prefix `/api/v2/manipulation`，挂在主 `app` 的 `include_router` 上。pub/sub 用模块级 `_subscribers: list[asyncio.Queue]`，`case_repository.update_stage` / `create_case` 在末尾 push 事件即可（用 `try: from .pubsub import publish; publish(evt) except: pass` 解耦循环导入）。
- **`generate_dual_signal`**：现有 `lifecycle.py` 已经有 `AGGRESSIVE_SIGNALS / CONSERVATIVE_SIGNALS` 两个字典（参见原 engine spec §4.4），只需加一个返回 `{conservative, aggressive}` 的便捷方法。**不要**重复定义信号字典。

### 14.2 macOS 端

- **`ManipulationCaseDetail` 模型升级要注意**：当前是 `evidence: [String: Double]` 扁平字典。新增 `evidenceLayers: [String: EvidenceLayerPayload]?`（可选，向后兼容 mock 与旧响应）。**保留旧 evidence 字段**，老的 sheet/卡片暂时仍能读。
- **`CaseDetailView.swift` 删除前**，确认没有其他地方引用（搜 `CaseDetailView(`）。当前调用点只有 `ManipulationRadarView.swift:57` 的 sheet。
- **`@Environment(\.networkClient)`** 是协议注入。新增的 `getStrategyImpact / getSimilar / connectStream` 方法加到 `APIManipulation`（不是 `NetworkClientProtocol`）— 参考现有 `getCaseDetail` 的模式。
- **`ManipulationViewModel.userProfile` 属性保留**（不删），用于 `getSignals(userProfile:)` 调用；只是 UI 不再暴露切换按钮。`toggleUserProfile()` 方法可删。
- **WS 连接生命周期**：`startPolling()` 改为 `startLiveUpdates()`，里面同时启动 30s polling（兜底）和 WS 监听。WS 断线 → 退化为纯 polling，不阻塞 UI。`stopPolling()` 改名 `stopLiveUpdates()` 同步关闭两者。`onDisappear` 调用点已有，名字变了要一起改。
- **`StrategyWorkspaceRootView` 共享根**：操纵雷达不属于 Strategy/AIResearch/Growth 三视图共享根（见 CLAUDE.md），不需要担心保活。
- **聚焦切换的并发**：点 Hero Strip 时启动三个 `async let`（detail / strategyImpact / similar），用一个新方法 `focusCase(_ caseId: String) async` 统一处理。三个请求互相独立，任一失败不影响其他章节渲染（每个状态独立 `nil` / `error`）。
- **WebSocket 在 SwiftUI 里**：用 `URLSessionWebSocketTask`，包一层 `actor ManipulationStreamClient`，把 `URLSessionWebSocketTask.receive()` 包成 `AsyncStream<ManipulationEvent>`。基础 URL 从 `LiveNetworkClient` 拿（约定 `ws://localhost:8000` ↔ `http://localhost:8000` — 加一个 helper `wsBaseURL`）。Mock 模式下 stream client 直接是 no-op。

### 14.3 风格细节（避免和参考页跑偏）

- 参考 `StructureMatrixView` 与 `MarketStructureView`：背景 `colors.background`、外层 `ScrollView(.vertical, showsIndicators: false)`、内容 `VStack(spacing: PulseSpacing.xl)` + `.padding(.horizontal, PulseSpacing.xl).padding(.vertical, PulseSpacing.lg).frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)`。不要用 `PulseSpacing.lg` 当外间距，会显得拥挤。
- **不要新增 ⌘K SymbolPicker**：聚焦切换通过 Hero Strip 点击。这是和两个参考页的差异点，故意为之（避免双重入口）。
- `.staggeredAppearance(index:)` 索引 0 起，章节按 § 0 (Strip) = index 0、§ 1 = index 1 … § 8 = index 9（Masthead 占 index 0，然后 Strip = 1，依次后推）— 实际 10 个动画帧。
- `LifecycleTimeline` 是水平的（左→右 5 个阶段节点 + 连线），不是垂直列表。当前阶段节点放大 + 描边发光，已过阶段实心，未到阶段虚线轮廓。
- Disclaimer 行用 `PulseFonts.caption` + `colors.textMuted`，前缀小 `ⓘ` 图标，**不要**用警告色 — 避免误读为"系统故障"。

### 14.4 测试要求

- 后端新端点必须有 pytest：`tests/test_manipulation_router.py` 加 `test_case_detail_v2_includes_evidence_layers`、`test_strategy_impact_blocks_when_filter_enabled`、`test_strategy_impact_warns_when_filter_disabled`、`test_similar_cases_ranking`。
- `find_similar` 算法单测：`tests/test_manipulation_case_repository.py` 已存在，追加测试。
- WebSocket 走集成测试：用 `TestClient.websocket_connect("/api/v2/manipulation/stream")`，断言收到 `stage_change` 事件。
- macOS 端：`Tests/ViewModelTests.swift` 已存在 ManipulationViewModel 测试位，加 `testFocusCaseLoadsThreeEndpoints`、`testStreamFallbackToPolling`。

### 14.5 路由跳转

已确认 `AppRoute` 提供：`.strategyWorkspace`（无 id 入参）+ `.riskCenter`。无 `.strategyDetail` / `.strategyEdit` 这类带 id 路由。

§ 7 落地：
- **整段"打开风控配置"按钮** → `.riskCenter`（这是当前唯一的风控入口）。
- **每条受影响策略行的"编辑过滤器"操作** → `.strategyWorkspace`（无 id 透传，落到工作台主页让用户自己点入策略）。spec 不为此引入路由参数透传或新 AppRoute case。
- 路由跳转复用现有 `@Environment(\.openRoute)` 注入或 `AppViewModel.navigate(to:)` 同款写法 — 写 plan 时先 grep `navigate(to:` / `openRoute` 找到当前模式。

## 15. 不在本 spec 范围

- ML 模型层（v2 XGBoost / v3 Transformer）— 保持引擎设计原方案不变
- 历史回溯系统 UI — 由后续单独的 Historical Scan Studio spec 处理
- 案例库浏览页（按操纵类型/市场/年代筛选）— 后续单独 spec
- 新数据源接入（社交、链上 adapter 落地）— 引擎组工作，不在本页面 spec
- 案例库持久化（从 in-memory 迁到 DB）— 与引擎 v2 一起做
- 新增风控编辑专用路由 — 复用现有 `AppRoute`
