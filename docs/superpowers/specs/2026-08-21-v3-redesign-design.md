---
status: selected
supersedes: none
date: 2026-08-21
open_decision: none — 已选定 E · VOLT 电光（dashboard-volt.html）
preview: design-previews-v3/（V3 三方案 12 页 + V3.1 三套；已淘汰 AURORA/HOLO）
---

# AlphaLoop V3 全量重设计实施规格

> 目标：app 整体 UI/UX 重设计——布局体系、动效语法、转场、字体，覆盖每一个页面。
> 不是换色、不是小修小改。预览先行（design-previews-v3），选定方案后按本规格落地。

## 0. 前置事实

- 当前 app 实际运行 **Protocol 浅色钴蓝**（DesignTokens 已锁定 `isDark=false`，CLAUDE.md 的"暗黑赛博朋克"描述过时）。
- 三端契约不变：本次重设计**不改任何 API 调用、ViewModel 数据流、L10n 键位**；只重构视觉层（DesignSystem + Views）。
- L10n 规则不变：所有用户可见文案走 `L10n.<Domain>`；重设计不得新增硬编码文案。
- 页面导航不变：`SidebarSection` 8 板块 / `AppRoute` 23 路由保持。

## 1. 方案速查（冻结于 _specs/STYLE-V3.md）

| | A · SENTINEL | B · MERIDIAN | C · GLASS OPS |
|---|---|---|---|
| 母题 | 任务指挥台（状态机优先） | 精密仪器台（度量优先） | 原生深度控制台（深度优先） |
| 明暗 | 深（石墨 `#0B0E13`） | 浅（暖纸 `#F4F3EF`） | 深（近黑 `#06080D`） |
| 主强调 | 信号青 `#2DD4BF` | 钢青 `#2450A8` + 铜 `#B4530F` | 流光青 `#67E8F9` |
| 字体 | Inter Tight + JetBrains Mono | Inter Tight + IBM Plex Mono | SF Pro + SF Mono |
| 形 | 方角 2px / hairline / 无阴影 | 方角 3px / hairline / 纸影 | 圆角 20 / 玻璃模糊 / 发光 |
| signature | 门禁链 + LED ribbon + 状态阶梯 | 刻度尺 + 公差带 + 表针量表 | 氛围层漂移 + 光晕环 + cross-dissolve |

## 2. 共享架构（三方案通用）

### 2.1 新 DesignSystem 层

```
DesignSystem/
├── Tokens.swift            ← 重写：语义 token（state/surface/ink/数据色）
├── Typography.swift        ← 重写：UI 字族 + 数据字族分离（mono 数据、tabular 数字）
├── Motion.swift            ← 新增：动效语法库（见 §2.2）
├── Surfaces.swift          ← 面板/卡片原语（方角 hairline / 玻璃）
├── Gates.swift             ← 新增：门禁链 / 状态阶梯 / 检查表组件
├── Gauges.swift            ← 新增：弧线量表 / 量程条 / 水位条
├── Status.swift            ← 新增：LED 状态点 / 状态词 / reason-code 芯片
└── Charts.swift            ← 保留：EquityCurve 等，适配新 token
```

### 2.2 动效语法库 `Motion.swift`

| 动效 | 语义 | 实现 |
|---|---|---|
| `moduleEntry(index:)` | 模块错峰入场 | opacity + translateY 4-6px，60ms 阶梯 |
| `countUp` | 数字入场 | TimelineView + easeOutCubic（替代一次性 spring） |
| `gateIgnite` | 门禁链/阶梯逐级点亮 | 220ms 级联 + 连线 draw-in |
| `needleSweep` | 表针/量表 | timingCurve(.2,.7,.2,1) 800ms |
| `crossDissolve` | 页面/区块切换 | opacity + 无位移（GLASS）或 6px 上移（SENTINEL）或 12px 横移（MERIDIAN） |
| `statusPulse` | LED/状态呼吸 | 2.4s ease-in-out 无限 |
| `atmosphereDrift` | 氛围层（仅 GLASS） | Canvas 低频绘制，≤30fps，随风险状态调色 |

全部动效必须：`accessibilityReduceMotion` 下禁用/直给终态。

### 2.3 页面壳层改造

- `AppShellView`：导航容器重构——
  - SENTINEL：72px 图标 rail（每图标嵌 3px 状态 LED）+ 36px 状态 ribbon（sticky）
  - MERIDIAN：顶部测量带 masthead（刻度尺 + 系统读数行），侧栏简化为章节目录
  - GLASS OPS：悬浮玻璃 HUD 顶条 + 氛围层全局背景（风险状态联动调色）
- `GlobalStatusBar` 三方案各自演绎（ribbon / 测量带 / 玻璃 HUD），数据源不变。

## 3. 逐页迁移清单（24 页，按页型分组）

| 页型 | 页面 | 重构要点 |
|---|---|---|
| 监控态 | Dashboard | hero 读数 + 门禁状态 + 决策流；错峰入场 |
| 门禁态 | Live Readiness | 门禁链/量表/校验表 + 三重确认（保留现有交互逻辑） |
| 工作态 | 策略工作台 / 策略画布 / 回测模拟 | 目录+详情分栏；画布页画布区不变，外壳与控件改 |
| 结构态 | 市场结构 / 结构矩阵 / 操纵雷达 | 图表外壳改 token；K线/热力图保持，包装层重构 |
| 执行态 | 执行中心 / 订单持仓 / 对账总线 | 表格 hairline/mono；批量操作条；对账总线时间线 |
| 警示态 | 风控中心 / 止损保护 / 熔断记录 | 水位/护栏量程/熔断台账；急停按钮最醒目 |
| 研究态 | AI 投研室 / Agent 平台 / 信号中心 / 市场情绪 | 卡片流 → 各自方案的 feed/读数化 |
| 成长态 | 复盘成长 / 失败聚类 / 策略优化 | 报告式排版；归因矩阵表格化 |
| 系统态 | 服务管理 / 数据源管理 / 系统设置 | 设置表单体系（标签左、控件右、状态 LED） |

## 4. 实施顺序与验收

每页一次提交；每页验收 = `swift build` 0 error + 页面截图对照预览稿 + reduced-motion 检查 + L10n 抽查。

1. **Phase D0**：DesignSystem 重写（Tokens/Typography/Motion/Surfaces/Gates/Gauges/Status）+ AppShell 壳层
2. **Phase D1**：Dashboard → Live Readiness（两页是语言样板，先在真实数据下验收）
3. **Phase D2**：风控三页 + 执行三页
4. **Phase D3**：策略三页（含画布外壳）+ 结构三页
5. **Phase D4**：研究四页 + 成长三页 + 系统三页
6. **Phase D5**：Landing / Setup / 命令面板 / 通知中心 / 抽屉与弹窗（KryptonConfirmDialog → 方案化）

## 5. 明确不做

- 不改 API 路径 / ViewModel 结构 / L10n 键位（仅视觉层）
- 不引入第三方 SPM 依赖（纯 SwiftUI + Foundation）
- canvas-web 内部画布渲染不改（外壳与桥接层适配）
- 不做双主题切换（每方案单主题；深浅即方案差异）

## 6. 选定方案

**E · VOLT 电光**（design-previews-v3/dashboard-volt.html）：
- 近黑底 `#0A0A0C` + 卡片 `#121216` + 边框 `#26262C`
- 主强调=电光柠檬黄 `#D8FF3D`；辅助紫 `#8B7CFF`；涨 `#3DF584` 跌 `#FF4D6D`；警示 `#FFB84D`
- 字体：Archivo（展示 800/700）+ Space Grotesk（UI）+ JetBrains Mono（数据）
- 动效：slam 入场（translateY+scale 回弹）、报价跑马灯、发光状态点、CountUp
- 招牌：顶部 ticker tape 跑马灯 + volt 按钮 + 电路纹理 + 粗字重数字
