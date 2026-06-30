---
title: Manipulation Radar — 九段叙事流页面重构（2026-07-01 落地版）
status: draft
date: 2026-07-01
authors: claude (product design)
supersedes:
  - docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md
related:
  - docs/superpowers/specs/2026-06-10-market-structure-causal-storyboard-design.md
  - docs/superpowers/specs/2026-06-10-structure-matrix-htf-tribunal-design.md
  - docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md (引擎层不变)
---

# Manipulation Radar — 九段叙事流页面重构（2026-07-01 落地版）

> **本 spec 取代 [2026-06-23-manipulation-radar-narrative-refactor-design.md](2026-06-23-manipulation-radar-narrative-refactor-design.md)。**
> 2026-06-23 spec 的信息架构、不确定性契约、双画像并列、风格契约全部沿用；本 spec 在其基础上：(1) 标注后端 P1 已落地、仅做查漏补缺；(2) 把当前代码现状从「九段未实现」修正为「3 块简化仪表板」；(3) 把实施分期压缩为 P2-P5 + P6 验收。
> 引擎层、案例库、生命周期状态机、EvidenceSnapshot、历史扫描、训练管线全部保持不变。

---

## 1. 背景与问题

当前 `ManipulationRadarView`（`macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift`）是「头部 + Stats Row + 双栏（案例网格 + 告警流）」的简化仪表板布局，案例详情通过 sheet 弹出。2026-06-23 spec 设计的九段叙事流尚未在 macOS 端落地。

后端 P1 工作已落地：`/cases/{id}` v2（分 Layer evidence + dual signal + completeness + max_confidence + affected_symbols + sources）、`/cases/{id}/strategy-impact`、`/cases/{id}/similar`、`/alerts`、`/radar`、WS `/api/v2/manipulation/stream`、`find_similar()`、`generate_dual_signal()`、pubsub 钩子全部就位（`backend/app/routers/manipulation.py`、`backend/app/services/manipulation/case_repository.py`）。

剩余四个问题（与 2026-06-23 spec §1 一致）：

1. **视觉风格游离** — 与同属"结构"分组的 `MarketStructureView` / `StructureMatrixView` 不是同一家族。两个参考页都是单 symbol 多章节垂直流，带 `staggeredAppearance` 入场、1200~1280 居中宽度、KryptonCard / TerminalLabel 章节卡。
2. **证据深度不足** — 13 项操纵风险信号只在 sheet 里塞一个扁平 evidence 字典，无层次、无 data quality、无策略联动可见性。
3. **语气过度确定** — sheet 用 "Detected" / "Manipulation case" 这类定罪式词汇。操纵识别本质是统计推断，不能写成确定结论。
4. **激进/保守画像被简化为顶部 toggle** — 用户切换后视觉跳变，难以对比两种立场。

## 2. 设计目标

沿用 2026-06-23 spec §2，不变：

- **A. 风格家族对齐** — 视觉骨架、章节排布、动画时序与 `MarketStructureView` / `StructureMatrixView` 一致。
- **B. 单 case 叙事流** — 主体围绕"当前聚焦的一个 case"逐章节铺开 13 项风险信号；多 case 入口收敛为顶部 Hero Strip。
- **C. 诚实表达不确定性** — 概率语言 + 可视化诚实（置信度条、data_quality 徽章、available/missing layers）+ 顶部系统级免责声明。
- **D. 双画像并列** — 取消顶部 toggle，把保守/激进两种交易建议在同章节左右并列。
- **E. 策略与风控联动可见** — 明确标注"该 case 影响当前哪些策略" / "ManipulationFilter 是否会阻断它"。

## 3. 信息架构 — 九段叙事流

按从上到下的阅读路径排布。交易场景下，证据呈现深度为「Layer score + data_quality 徽章 + 关键指标卡 + 分位条」，**不展开 feature 下钻表、不画时序曲线**——交易需要一眼读出「证据够不够强、哪个维度最危险、是否在恶化」，不需要法证级 feature 明细。

```
┌─────────────────────────────────────────────────────────────────────┐
│ Masthead   ALPHALOOP · MANIPULATION RADAR · STATISTICAL INFERENCE   │
│            "evidence-based suspicion, not a verdict"                │
│            ⓘ 不确定性免责声明                                        │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 0  Active Cases Strip  (horizontal scroll)                        │
│      [PEPE/USDT M3 ▍distrib 85%]  [SOL/USDT M5 ▎markup 78%]  …      │
│      点击任一卡片 → 切换下方所有章节的聚焦 case                       │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 1  Verdict Panel  (focused case)                                  │
│      M-type 标签 + 风险等级 + 阶段进度 + 置信度环(上限=max_confidence)│
│      + 数据完整度 N/5 + 概率前缀文案                                  │
│      "Likely Cross-Market Squeeze · markup stage · confidence 78%"  │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 2  Lifecycle Timeline  (水平 5 节点)                               │
│      SUSPECTED → ACCUMULATE → MARKUP →[ DISTRIBUTE ]→ COLLAPSE       │
│      每节点：进入时间 + 当时置信度；当前节点放大发光                   │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 3  Evidence Matrix  (5 Layers × score 条)                         │
│      Layer A 价格量能   ▮▮▮▮▯ 0.78  quality 0.95                     │
│      Layer B 盘口流动性 ▮▮▯▯▯ 0.42  quality 0.60                     │
│      Layer C 链上集中度 ▮▮▮▯▯ 0.65  quality 0.55                     │
│      Layer D 社交加速   —    quality 0.10  ⚠ Data unavailable        │
│      Layer E 跨市场     ▮▮▮▮▮ 0.89  quality 0.85                     │
│      不展开 feature 表（交易场景不需要）                              │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 4  Whale & Concentration  (Layer C 关键指标)                       │
│      Top-10 集中度指标卡 + 分位条 + 大额转账 + 交易所充值净流入       │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 5  Cross-Market Pressure  (Layer E 关键指标)                       │
│      资金费率 z-score + OI 变化 + 多空比 + 现货-永续基差 指标卡        │
│      + 资金费率 z-score 分位条                                        │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 6  Social Acceleration  (Layer D 关键指标，可缺失)                  │
│      提及增速 + 情绪极端度 指标卡 + 提及速率分位条                     │
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
│      → 跳转 .riskCenter / .strategyWorkspace                          │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ § 8  Alert Feed  +  Similar Historical Cases                        │
│      左半：该 case 的实时告警时间线（WS 推送 + 30s polling 兜底）       │
│      右半：相似历史案例（evidence 向量余弦相似度），含 outcome 结局     │
└─────────────────────────────────────────────────────────────────────┘
```

宽度：与 `StructureMatrixView` 对齐为 `frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)`。

每段使用 `.staggeredAppearance(index: N)` 依序入场，间距 `PulseSpacing.xl`。索引：Masthead=0, Strip=1, Verdict=2, Lifecycle=3, Evidence=4, Whale=5, CrossMarket=6, Social=7, Defense=8, Alerts+Similar=9。

## 4. 视觉风格契约（与参考页对齐）

沿用 2026-06-23 spec §4，复用项不引入新原语；新增 9 个组件。

| 元素 | 复用自 |
|------|--------|
| 章节卡片 | `KryptonCard(emphasis: .subtle/.standard)` |
| 章节小标题 | `TerminalLabel(text:)` |
| 入场动画 | `.staggeredAppearance(index:)` |
| 颜色 | `PulseColors.*` — 阶段颜色映射沿用现有 LifecycleIndicator 色板 |
| 字体 | `PulseFonts.displayHeading/displaySubheading/tabular/micro` |
| 弹层 | 抽屉式 `StructureDetailDrawer` 同款模式（保留，Evidence 矩阵不展开 feature 故暂不用） |

**新增 9 个组件**（全部放在 `Views/Manipulation/Components/`）：

| 组件 | 职责 | 行数预算 |
|------|------|---------|
| `ActiveCasesStrip` | § 0 — 横向滚动的活跃 case 缩略卡 | ~120 行 |
| `VerdictPanel` | § 1 — M-type + 风险等级 + 阶段进度 + 置信度环 + 数据完整度 | ~180 行 |
| `LifecycleTimeline` | § 2 — 水平 5 节点时间线（重写 LifecycleIndicator 视图部分） | ~150 行 |
| `EvidenceLayerMatrix` | § 3 — 5 Layer × score 条 + data_quality 徽章（不展开 feature） | ~180 行 |
| `WhaleConcentrationPanel` | § 4 — Top-10 集中度指标卡 + 分位条 + 转账/充值 | ~120 行 |
| `CrossMarketPressurePanel` | § 5 — 资金费率 z-score / OI / 多空比 / 基差 指标卡 + 分位条 | ~120 行 |
| `SocialAccelerationPanel` | § 6 — 提及增速 + 情绪 指标卡 + 分位条；缺失整段占位 | ~100 行 |
| `DualProfileSignalPanel` | § 7 — 保守/激进双栏 + 影响交易对 + 策略联动列表 + 跳转 | ~180 行 |
| `SimilarCasesPanel` | § 8 右半 — 相似历史案例 + outcome | ~100 行 |

§ 4/§ 5/§ 6 的"分位条"：一条横条标记当前值在历史分位的位置（如 z-score=2.4 → 92 分位），用 `PulseColors.accent/danger` 渐变。**不画时序曲线**（后端 features 无 history 数组，且交易场景分位比曲线更直观）。

## 5. 不确定性表达契约

沿用 2026-06-23 spec §5，不变。

### 5.1 文案前缀

所有判定文案在 L10n 层统一改成概率前缀：

| ❌ 旧（定罪式） | ✅ 新（统计推断） |
|----------------|------------------|
| "Manipulation detected" | "Likely manipulation pattern" / "疑似操纵迹象" |
| "Confirmed M5" | "Evidence consistent with M5" / "证据指向 M5" |
| "Distribution phase" | "Likely in distribution phase" / "疑似处于派发期" |

### 5.2 可视化诚实

- 每个 evidence Layer 旁显示 `quality 0.55` 徽章，`<0.3` 整段标 "Data unavailable"
- Verdict Panel 显示 "Data completeness 3/5 layers" — 仅基于可用 Layer 计算
- 置信度环显示置信度上限 = `max_confidence`（后端已返回，= `min(completeness × 1.2, 1.0)`）

### 5.3 系统级免责声明

Masthead 下方一行：

> ⓘ AlphaLoop's manipulation radar is a statistical inference system. It surfaces evidence-based suspicions, not verdicts. Use it as one input among many.

L10n 键：`L10n.Manipulation.disclaimer`。样式：`PulseFonts.caption` + `colors.textMuted` + `ⓘ` 前缀，**不用警告色**（避免误读为"系统故障"）。

## 6. 双画像并列展示

沿用 2026-06-23 spec §6，不变。

§ 7 章节用一个 `HStack` 左右两栏 KryptonCard：

- 左：CONSERVATIVE（PulseColors.info 色调） — 显示 `trading_signal.conservative.{action, rationale, sizing, risk_level}`
- 右：AGGRESSIVE（PulseColors.amber 色调） — 显示 `trading_signal.aggressive.{action, rationale, sizing, stop_loss, risk_level}`

两栏下方共享：
- 影响交易对 chip 列表（数据源：`/cases/{id}.affected_symbols`，后端扩展为同基币多对）
- 当前策略联动列表（数据源：`/cases/{id}/strategy-impact`）
- 跳转按钮 → `.riskCenter`（整段"打开风控配置"）+ `.strategyWorkspace`（每条策略行"编辑过滤器"，无 id 透传）

顶部 `userProfile` toggle 删除。`ManipulationViewModel.userProfile` 属性保留（仍传给 `/signals`），`toggleUserProfile()` 方法删除。

## 7. 后端查漏补缺（P1 已落地，仅补交易场景必需项）

后端 P1 工作已就位（`/cases/{id}` v2、`/strategy-impact`、`/similar`、`/alerts`、`/radar`、WS `/stream`、`find_similar`、`generate_dual_signal`、pubsub 钩子）。本次仅补：

### 7.1 `affected_symbols` 扩展

`backend/app/routers/manipulation.py:68` 当前硬编码 `"affected_symbols": [case["symbol"]]`。补：若 case symbol 是合约基币（如 `SOL/USDT` → 基币 `SOL`），扩展为同基币的 USDT/USDC/FDUSD 三对。逻辑放 `_build_case_detail_v2`，纯字符串推导，不依赖外部数据。示例：`SOL/USDT` → `["SOL/USDT", "SOL/USDC", "SOL/FDUSD"]`；无 `/` 的 symbol 保持原样。

### 7.2 `generate_dual_signal` 核实

已确认 `backend/app/services/manipulation/lifecycle.py:121` 导出 `generate_dual_signal(self, stage)`，返回 `{conservative, aggressive}`，复用现有 `AGGRESSIVE_SIGNALS` / `CONSERVATIVE_SIGNALS` 字典。**无需新增。**

### 7.3 pytest 覆盖

补 5 个测试（若缺）到 `backend/tests/test_manipulation_*.py`：

- `test_case_detail_v2_includes_evidence_layers` — `/cases/{id}` 返回 `evidence_layers` / `completeness` / `max_confidence` / `trading_signal.conservative+aggressive`
- `test_strategy_impact_blocks_when_filter_enabled` — 启用 `manipulation_score_filter` 的策略 `would_block=true`
- `test_strategy_impact_warns_when_filter_disabled` — 未启用 filter 的策略 `reason_codes=["filter_disabled"]`
- `test_similar_cases_ranking` — `find_similar` 按 cosine 降序
- `test_stream_pushes_stage_change` — `TestClient.websocket_connect("/api/v2/manipulation/stream")` 收到 `stage_change` 事件

WS 已有 router（`manipulation_ws.py`）+ pubsub 钩子（`case_repository.update_stage` / `create_case` 已 publish），无服务层改动。

## 8. 数据流与状态机

```
┌──────────────────────┐
│ ManipulationViewModel│
│  - activeCases       │ ← polling /radar 每 30s（兜底）
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

聚焦切换约束：`focusedCaseId == nil` 时，自动选 `activeCases[0]`。点 Hero Strip 卡片 → `focusedCaseId = card.id` → 并行触发 detail / strategyImpact / similar 三个请求（`async let`，互相独立，任一失败不影响其他章节渲染，每个状态独立 `nil` / `error`）。

WS 生命周期：`startLiveUpdates()` 同时启动 30s polling（兜底）和 WS 监听。WS 断线 → 退化为纯 polling，不阻塞 UI。`stopLiveUpdates()` 同步关闭两者。`onDisappear` 调用点已有。

## 9. L10n 新增键

`Localization/L10n+Manipulation.swift` 在现有键基础上新增（沿用 2026-06-23 spec §9 清单）：

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
| `Views/Manipulation/CaseCardView.swift` | 重写为 `ActiveCasesStripCard`，移到 `Components/ActiveCasesStrip.swift` 内 |
| `Views/Manipulation/CaseDetailView.swift` | **删除**（sheet 模式废弃；详情就是主页面） |
| `Views/Manipulation/LifecycleIndicator.swift` | 保留色板与图标映射 helper；视图重写为水平 `LifecycleTimeline` 移到 `Components/` |
| `Views/Manipulation/ManipulationAlertFeed.swift` | 保留并作为 § 8 左半子视图 |
| `Views/Manipulation/Components/ActiveCasesStrip.swift` | **新增** |
| `Views/Manipulation/Components/VerdictPanel.swift` | **新增** |
| `Views/Manipulation/Components/LifecycleTimeline.swift` | **新增** |
| `Views/Manipulation/Components/EvidenceLayerMatrix.swift` | **新增** |
| `Views/Manipulation/Components/WhaleConcentrationPanel.swift` | **新增** |
| `Views/Manipulation/Components/CrossMarketPressurePanel.swift` | **新增** |
| `Views/Manipulation/Components/SocialAccelerationPanel.swift` | **新增** |
| `Views/Manipulation/Components/DualProfileSignalPanel.swift` | **新增** |
| `Views/Manipulation/Components/SimilarCasesPanel.swift` | **新增** |
| `ViewModels/ManipulationViewModel.swift` | 加 `focusedCaseId / focusedDetail / strategyImpact / similar` 状态 + `focusCase(_:)` 三并发 + WS 接入；`startPolling`→`startLiveUpdates`，`stopPolling`→`stopLiveUpdates`；删 `toggleUserProfile()` |
| `Services/APIManipulation.swift` | 升级 `ManipulationCaseDetail` 为分 Layer 模型（`evidenceLayers: [String: EvidenceLayerPayload]?` 可选，保留旧 `evidence`）；加 `getStrategyImpact / getSimilar` 方法 + mock；加 `ManipulationStreamClient` actor（WS → `AsyncStream<ManipulationEvent>`） |
| `Localization/L10n+Manipulation.swift` | 追加 § 9 所列键 |
| `backend/app/routers/manipulation.py` | `affected_symbols` 扩展（§7.1） |
| `backend/app/services/manipulation/lifecycle.py` | 核实/补 `generate_dual_signal`（§7.2） |
| `backend/tests/test_manipulation_*.py` | 补 4+1 个测试（§7.3） |
| `CLAUDE.md` | `Views/Manipulation/ManipulationRadarView` 描述改为"九段叙事流，按 Masthead + § 0-§ 8 顺序展示" |
| `docs/user-guide/content/{zh,en}/pages/structure/manipulation-radar.html` | 重写（章节顺序、不确定性声明、双画像对比、策略联动入口） |
| `docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md` | frontmatter 加 `superseded-by: 2026-07-01-...` |

## 11. 实施分期

| Phase | 内容 | 末尾校验 |
|-------|------|---------|
| **P2 — macOS 模型 + ViewModel** | `ManipulationCaseDetailV2` 与所有 Codable 子结构（`EvidenceLayerPayload` / `FeaturePayload` / `DualTradingSignal` / `StrategyImpactResponse` / `SimilarCasesResponse` / `ManipulationEvent`）；ViewModel 增加状态 + `focusCase(_:)` 三并发；`getStrategyImpact / getSimilar` + mock；`ManipulationStreamClient` actor（WS → AsyncStream） | `swift build` |
| **P3 — UI 九段** | 重写 `ManipulationRadarView`；新增 9 个 Components；删 `CaseDetailView`；`LifecycleIndicator` 色板 helper 保留、视图部分迁入 `LifecycleTimeline` | `swift build` |
| **P4 — WebSocket 实时推送** | `startLiveUpdates` 同时跑 polling+WS；WS 断线退化为 polling；AlertFeed 改实时；阶段切换自动刷新聚焦 case | `swift build` + `swift test` |
| **P5 — 后端补丁 + L10n + 文档** | `affected_symbols` 扩展；核实/补 `generate_dual_signal`；5 个 pytest；L10n 键；CLAUDE.md；user-guide；旧 spec frontmatter | `pytest` + `swift build` |
| **P6 — 验收** | 跑全栈：mock 模式 + live 模式各看一遍 9 段；WS 推 stage_change；双画像对比；策略联动跳转 | 手测清单 |

## 12. 验收清单

- [ ] 页面骨架 — 1280 居中、九段 + Masthead `staggeredAppearance(index: 0-9)`、`KryptonCard` 与 `TerminalLabel` 全部复用
- [ ] 文案 — 所有判定文案使用概率前缀；Masthead 下方有 disclaimer（非警告色）
- [ ] 数据完整度 — Verdict 显示 N/5 layers + max_confidence；每 Layer 显示 data_quality；缺失 Layer 标 Data unavailable
- [ ] 双画像 — § 7 同时呈现 conservative 与 aggressive，删除顶部 toggle
- [ ] 策略联动 — § 7 列出受影响策略 + filter 状态 + 跳转 `.riskCenter` / `.strategyWorkspace` 入口
- [ ] 相似案例 — § 8 右半呈现 top-N 相似历史 case 含 outcome
- [ ] 实时性 — WS 推送阶段切换后，自动刷新聚焦 case 与 alerts；WS 断线退化为 polling 不阻塞 UI
- [ ] § 4/§ 5/§ 6 — 关键指标卡 + 分位条；Layer D `data_quality<0.3` 整段 Data unavailable
- [ ] L10n — 所有新文案 zh/en 双语
- [ ] 后端测试 — `/cases/{id}` v2、`/strategy-impact`、`/similar`、`/stream` 都有 pytest 覆盖
- [ ] 旧 spec frontmatter 标注 superseded-by
- [ ] CLAUDE.md `Views/Manipulation/` 描述更新
- [ ] user-guide 重写

## 13. 实现注意（避免下一个模型踩坑）

### 13.1 后端

- **案例库是 in-memory（`case_repository.py` v1）**。`find_similar()` 已在内存里实现，不依赖数据库。pub/sub 同样在进程内，进程重启所有 case 与 WS 订阅都会丢，这是 v1 既有约束，不在本 spec 修复范围。
- **`/cases/{id}` 已向后兼容**：保留扁平 `evidence` 字段，同时有 `evidence_layers`。其他客户端（Dashboard 的 manipulation 卡、Structure Matrix 的 manipulationScore 列）仍读旧字段，不要破坏。
- **DSL 规则名是 `manipulation_score_filter`**（不是 `ManipulationFilterRule`）。`/strategy-impact` 已实现于 `services/manipulation/strategy_impact.py`，扫描策略 DSL 的 `rules` 数组找 `type == "manipulation_score_filter"`。
- **WebSocket 已有先例**：`backend/app/routers/manipulation_ws.py` 已存在，pubsub 用模块级 `_subscribers: list[asyncio.Queue]`，`case_repository.update_stage` / `create_case` 已 publish `stage_change` / `new_case` 事件。无需改动服务层。
- **`generate_dual_signal`**：现有 `lifecycle.py` 已有 `AGGRESSIVE_SIGNALS / CONSERVATIVE_SIGNALS` 字典，只需一个返回 `{conservative, aggressive}` 的便捷方法。**不要**重复定义信号字典。

### 13.2 macOS 端

- **`ManipulationCaseDetail` 模型升级**：当前是 `evidence: [String: Double]` 扁平字典。新增 `evidenceLayers: [String: EvidenceLayerPayload]?`（可选，向后兼容 mock 与旧响应）。**保留旧 evidence 字段**。
- **`CaseDetailView.swift` 删除前**，确认没有其他地方引用（搜 `CaseDetailView(`）。当前调用点只有 `ManipulationRadarView.swift:57` 的 sheet。
- **`@Environment(\.networkClient)`** 是协议注入。新增的 `getStrategyImpact / getSimilar / connectStream` 方法加到 `APIManipulation`（不是 `NetworkClientProtocol`）— 参考现有 `getCaseDetail` 的模式。
- **`ManipulationViewModel.userProfile` 属性保留**（不删），用于 `getSignals(userProfile:)` 调用；只是 UI 不再暴露切换按钮。`toggleUserProfile()` 方法可删。
- **WS 连接生命周期**：`startPolling()` 改为 `startLiveUpdates()`，里面同时启动 30s polling（兜底）和 WS 监听。WS 断线 → 退化为纯 polling，不阻塞 UI。`stopPolling()` 改名 `stopLiveUpdates()` 同步关闭两者。`onDisappear` 调用点已有，名字变了要一起改。
- **WebSocket 在 SwiftUI 里**：用 `URLSessionWebSocketTask`，包一层 `actor ManipulationStreamClient`，把 `URLSessionWebSocketTask.receive()` 包成 `AsyncStream<ManipulationEvent>`。基础 URL 从 `LiveNetworkClient` 拿（约定 `ws://localhost:8000` ↔ `http://localhost:8000` — 加一个 helper `wsBaseURL`）。Mock 模式下 stream client 直接是 no-op。
- **聚焦切换的并发**：点 Hero Strip 时启动三个 `async let`（detail / strategyImpact / similar），用一个新方法 `focusCase(_ caseId: String) async` 统一处理。三个请求互相独立，任一失败不影响其他章节渲染（每个状态独立 `nil` / `error`）。
- **`StrategyWorkspaceRootView` 共享根**：操纵雷达不属于 Strategy/AIResearch/Growth 三视图共享根，不需要担心保活。

### 13.3 风格细节

- 参考 `StructureMatrixView` 与 `MarketStructureView`：背景 `colors.background`、外层 `ScrollView(.vertical, showsIndicators: false)`、内容 `VStack(spacing: PulseSpacing.xl)` + `.padding(.horizontal, PulseSpacing.xl).padding(.vertical, PulseSpacing.lg).frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)`。不要用 `PulseSpacing.lg` 当外间距，会显得拥挤。
- **不要新增 ⌘K SymbolPicker**：聚焦切换通过 Hero Strip 点击。这是和两个参考页的差异点，故意为之（避免双重入口）。
- `.staggeredAppearance(index:)` 索引：Masthead=0, Strip=1, Verdict=2, … Alerts+Similar=9（10 个动画帧）。
- `LifecycleTimeline` 是水平的（左→右 5 个阶段节点 + 连线），不是垂直列表。当前阶段节点放大 + 描边发光，已过阶段实心，未到阶段虚线轮廓。
- Disclaimer 行用 `PulseFonts.caption` + `colors.textMuted`，前缀小 `ⓘ` 图标，**不要**用警告色。
- § 4/§ 5/§ 6 分位条：一条横条，左端 0% 右端 100%，当前位置标记一个点 + 数值。用 `PulseColors.accent`（正常）→ `PulseColors.danger`（>90 分位）渐变。不画时序曲线。

### 13.4 路由跳转

已确认 `AppRoute` 提供：`.strategyWorkspace`（无 id 入参）+ `.riskCenter`。无 `.strategyDetail` / `.strategyEdit` 这类带 id 路由。

§ 7 落地：
- **整段"打开风控配置"按钮** → `.riskCenter`。
- **每条受影响策略行的"编辑过滤器"操作** → `.strategyWorkspace`（无 id 透传，落到工作台主页让用户自己点入策略）。
- 路由跳转复用现有 `@Environment(\.openRoute)` 注入或 `AppViewModel.navigate(to:)` 同款写法 — 写 plan 时先 grep `navigate(to:` / `openRoute` 找到当前模式。

### 13.5 测试要求

- 后端新端点必须有 pytest（§7.3 列的 4+1 个）。
- macOS 端：`Tests/ViewModelTests.swift` 已存在 ManipulationViewModel 测试位，加 `testFocusCaseLoadsThreeEndpoints`、`testStreamFallbackToPolling`。

## 14. 不在本 spec 范围

- ML 模型层（v2 XGBoost / v3 Transformer）— 保持引擎设计原方案不变
- 历史回溯系统 UI — 由后续单独的 Historical Scan Studio spec 处理
- 案例库浏览页（按操纵类型/市场/年代筛选）— 后续单独 spec
- 新数据源接入（社交、链上 adapter 落地）— 引擎组工作，不在本页面 spec
- 案例库持久化（从 in-memory 迁到 DB）— 与引擎 v2 一起做
- 新增风控编辑专用路由 — 复用现有 `AppRoute`
- § 4/§ 5/§ 6 时序曲线可视化 — 后端 features 无 history 数组，分位条已满足交易场景
- Evidence 矩阵 feature 下钻表 — 交易场景不需要法证级明细
