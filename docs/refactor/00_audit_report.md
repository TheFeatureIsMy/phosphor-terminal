# Krypton UI 架构重构 — Phase 0 基线审查报告

> 日期：2026-06-07
> 范围：性能瓶颈、文件边界、风险点

---

## 1. 当前 UI 架构问题总结

| # | 问题 | 严重度 | 位置 |
|---|------|--------|------|
| 1 | 10 Environment Objects 全局注入 | 高 | PulseDeskApp.swift:57-66 |
| 2 | `.id(selectedRoute)` 强制销毁重建 | 高 | AppShellView.swift:24 |
| 3 | DashboardView 1044 行单文件 | 高 | DashboardView.swift |
| 4 | 3 层 RadialGradient + Canvas scanline + Canvas dotGrid 常驻渲染 | 中 | BackgroundLayersView.swift |
| 5 | 3 个 Timer.publish 每秒/每15秒全局刷新 | 中 | GlobalStatusBar + AppShellView |
| 6 | 24 路由平铺于 8 侧边栏分组 | 中 | Enums.swift + SidebarView.swift |
| 7 | ConsoleToolbar 计时器触发 body 重算 | 低 | AppShellView.swift:182 |

---

## 2. Environment 注入完整清单

### 2.1 根部注入 (PulseDeskApp.swift:57-66)

```swift
.environment(appState)           // @State AppState — 全局状态
.environment(authState)          // @State AuthState — 认证
.environment(settingsState)      // @State SettingsState — 设置
.environment(themeManager)       // ThemeManager — 主题
.environment(pulseColors)        // PulseColors — 色彩
.environment(\.networkClient, nc)// NetworkClient — API
.environment(errorHandler)       // ErrorHandler — 错误
.environment(wsManager)          // WebSocketManager — WS
.environment(toastManager)       // ToastManager — Toast
.environment(dependencyState)    // DependencyState? — 依赖
```

### 2.2 非根部注入

| 文件 | 注入 |
|------|------|
| StrategyCanvasPageView.swift:473-474 | colors, appState (局部重复) |
| StrategyCanvasPageView.swift:536 | colors |

### 2.3 更新频率分类

| 频率 | 对象 |
|------|------|
| **高频** (>1次/秒) | wsManager, toastManager |
| **中频** (1-15秒) | appState (时钟/状态), dependencyState (15s 轮询) |
| **低频** (按事件) | authState, settingsState, errorHandler |
| **稳定** | themeManager, pulseColors, networkClient |

---

## 3. Timer 完整清单

| # | 类型 | 间隔 | 文件:行 |
|---|------|------|---------|
| 1 | Timer.publish | 1s | GlobalStatusBar.swift:15 |
| 2 | Timer.publish | 15s | GlobalStatusBar.swift:16 |
| 3 | Timer.publish | 1s | AppShellView.swift:182 (ConsoleToolbar) |
| 4 | Timer.scheduledTimer | 2s | StrategyDetailViewModel.swift:196 (策略轮询) |
| 5 | Timer.scheduledTimer | 15s | DependencyState.swift:37 (依赖刷新) |
| 6 | Timer.scheduledTimer | 30s | WebSocketManager.swift:190 (heartbeat) |
| 7 | Timer.scheduledTimer | 5s | WebSocketManager.swift:181 (reconnect) |

**说明**: Timer 4/5/6/7 是功能必需的（策略轮询、依赖刷新、WS 心跳），不应移除。Timer 1/2/3 是 UI 层展示用，需要改为事件驱动。

---

## 4. `.id(selectedRoute)` 强制重建

**唯一位置**: `AppShellView.swift:24`

```swift
detailContent
    .id(appState.selectedRoute)   // ← 每次切路由，整个内容区 tear down + rebuild
    .contentTransition(.opacity)
```

影响：DashboardView(1044行)、StrategyCanvasPageView(WebView)、所有其他页面在路由切换时全部销毁重建。

---

## 5. DashboardView 结构分析

### 5.1 文件规模
- 文件：`DashboardView.swift` — **1044 行**
- 包含 **10 个 struct/组件**

### 5.2 组件列表

| 行号 | 组件 | 行数 |
|------|------|------|
| 8 | TickerTapeView | ~88 行 |
| 99 | UnifiedToolbar | ~128 行 |
| 230 | AIMarketJudgmentCard | ~152 行 |
| 385 | PendingConfirmationsCard | ~140 行 |
| 530 | BentoEquityCard | ~56 行 |
| 589 | AgentSignalDistributionView | ~71 行 |
| 663 | RiskInterceptionStatsCard | ~92 行 |
| 758 | PositionsRiskCard | ~180 行 |
| 835 | PositionRow | ~103 行 |
| 941 | DashboardView (主视图) | ~100 行 |

### 5.3 建议拆分
每个子组件独立文件，DashboardView 只做布局编排。

---

## 6. 背景层渲染清单

**文件**: `BackgroundLayersView.swift` (75行)

```
Layer 1: ambientGlow — 3x RadialGradient (amber + green + red)
Layer 2: dotGridOverlay — Canvas dot grid (24dp spacing, 0.45dp radius)
Layer 3: scanlineOverlay — Canvas scanlines (4dp spacing)
```

三个层都是 `.ignoresSafeArea()` + 常驻渲染。Canvas 重绘在窗口 resize 和主题切换时触发整屏重算。

**使用位置**:
- AppShellView.swift (主布局背景)
- LandingView.swift (登录页)
- StopProtectionView.swift (风控页)

---

## 7. 路由清单

### 7.1 完整路由表 (24 个)

| Section | Route | 中文名 |
|---------|-------|--------|
| OVERVIEW | dashboard | 总览控制台 |
| OVERVIEW | liveReadiness | 实盘准入 |
| STRATEGY | strategyWorkspace | 策略工作台 |
| STRATEGY | strategyCanvas | 策略画布 |
| STRATEGY | backtestSimulation | 回测 / 模拟 |
| STRUCTURE | marketStructure | 市场结构 |
| STRUCTURE | structureMatrix | 结构矩阵 |
| STRUCTURE | manipulationRadar | 操纵雷达 |
| EXECUTION | executionCenter | 执行中心 |
| EXECUTION | ordersPositions | 订单 / 持仓 |
| EXECUTION | reconciliationBus | 对账总线 |
| RISK | riskCenter | 风控中心 |
| RISK | stopProtection | 止损保护 |
| RISK | circuitBreakers | 熔断记录 |
| AI RESEARCH | aiResearchRoom | AI 投研室 |
| AI RESEARCH | agentPlatform | Agent 平台 |
| AI RESEARCH | signalCenter | 信号中心 |
| AI RESEARCH | marketSentiment | 市场情绪 |
| GROWTH | growthReview | 复盘成长 |
| GROWTH | failureClustering | 失败聚类 |
| GROWTH | strategyOptimization | 策略优化 |
| SYSTEM | serviceManagement | 服务管理 |
| SYSTEM | dataSourceManagement | 数据源管理 |
| SYSTEM | systemSettings | 系统设置 |
| (Internal) | strategyDetail | 策略详情 |

### 7.2 Section 分组 (8 个)
overview, strategy, structure, execution, risk, aiResearch, growth, system

---

## 8. WebView / React Flow 通信边界

### 8.1 通信协议文件 (禁止修改)

| 文件 | 行数 | 说明 |
|------|------|------|
| CanvasBridge.swift | 50 | WKScriptMessageHandler — React ↔ Swift 消息桥 |
| CanvasWebView.swift | 38 | WKWebView 封装 |
| CanvasWebViewModel.swift | 142 | WebView 状态管理 + validateAndSendResult + saveVersion |

### 8.2 通信协议 (4 种消息)

```
React → Swift:
  canvasReady       → viewModel.onCanvasReady()
  graphChanged      → viewModel.onGraphChanged(payload)
  requestValidation → viewModel.validateAndSendResult(dsl)
  requestSaveVersion → viewModel.saveVersion(dsl)
```

### 8.3 宿主 UI 文件 (可以修改)

```
StrategyCanvasPageView.swift  — 画布页面宿主布局
CanvasBackground.swift        — 画布背景
CanvasEdges.swift             — 边渲染
CanvasSearchOverlay.swift     — 搜索覆盖层
CanvasSelectionRect.swift     — 选择矩形
CodePreviewSheet.swift        — 代码预览
GroupBoxView.swift            — 分组框
MiniMapView.swift             — 小地图
NodeConfigPanel.swift         — 节点配置面板
NodePalette.swift             — 节点面板
NodeView.swift                — 节点视图
SnapGuidesView.swift          — 吸附引导线
ViewportCuller.swift          — 视口裁剪
```

---

## 9. 不可修改文件清单 (业务/通信层)

### 9.1 Services 层
```
Services/NetworkClient.swift           — 网络客户端
Services/WebSocketManager.swift        — WebSocket 管理
Services/AIStrategyGenerator.swift     — AI 策略生成
Services/CanvasErrorNotifier.swift     — 画布错误通知
Services/ClipboardManager.swift        — 剪贴板
Services/EdgeRouter.swift              — 边路由
Services/EdgeValidator.swift           — 边校验
Services/GraphSerializer.swift         — 图序列化
Services/NodeRegistry.swift            — 节点注册
Services/SnapEngine.swift              — 吸附引擎
Services/API*.swift (全部 30 个)       — API 客户端
```

### 9.2 ViewModel 层 (业务逻辑不可改，可加只读 UI 派生字段)
```
ViewModels/ 全部 (20 个)               — ViewModel 核心逻辑保留
```

### 9.3 通信协议层
```
Views/Canvas/CanvasBridge.swift        — React ↔ Swift 消息协议
Views/Canvas/CanvasWebView.swift       — WKWebView 封装
ViewModels/CanvasWebViewModel.swift    — WebView 状态管理
```

---

## 10. 可安全修改文件清单

### 10.1 App Shell (核心改造目标)
```
PulseDeskApp.swift                      — 入口 + Environment 重组
Views/AppShell/AppShellView.swift       — 路由系统 + 保活
Views/AppShell/SidebarView.swift        — 侧边栏 3 入口改造
Views/AppShell/GlobalStatusBar.swift    — Timer 移除 + 事件驱动
Views/AppShell/CommandPaletteView.swift — Command Palette 升级
```

### 10.2 Design System (视觉统一)
```
DesignSystem/DesignTokens.swift         — 品牌色
DesignSystem/FontExtensions.swift       — 字体
DesignSystem/ViewModifiers.swift        — 视图修饰
DesignSystem/AnimatedEffects.swift      — 动画效果
```

### 10.3 Shared Views (状态体系补齐)
```
Views/Shared/BackgroundLayersView.swift  — 背景降级
Views/Shared/ProofAlphaComponents.swift  — 组件库
Views/Shared/EmptyStateView.swift        — 空状态
Views/Shared/LoadingView.swift           — 加载态
Views/Shared/ToastOverlayView.swift      — Toast
Views/Shared/FormControls.swift          — 表单控件
```

### 10.4 Feature Views (所有页面可改布局/样式)
```
Views/Dashboard/DashboardView.swift      — 拆分 + Bento Console
Views/LiveReadiness/                     — 样式迁移
Views/Execution/                         — 样式迁移
Views/Risk/                              — 样式迁移
Views/Structure/                         — 样式迁移
Views/Strategies/                        — 样式迁移
Views/SignalCenter/                      — 样式迁移
Views/Sentiment/                         — 样式迁移
Views/Growth/                            — 样式迁移
Views/AIStudio/                          — 样式迁移
Views/AgentPlatform/                     — 样式迁移
Views/AIProviders/                       — 样式迁移
Views/DataSources/                       — 样式迁移
Views/BacktestAndDryrun/                 — 样式迁移
Views/Settings/                          — 样式迁移
Views/Manipulation/                      — 样式迁移
```

### 10.5 ViewModel (只读派生字段可加)
```
ViewModels/DashboardViewModel.swift     — UI 适配字段
ViewModels/GlobalStatusViewModel.swift  — UI 适配字段
```

### 10.6 State
```
State/AppState.swift                     — 新工作区状态 + Command Palette 状态
```

### 10.7 Models
```
Models/Enums.swift                       — 新路由模型 (PrimaryWorkspace, WorkspaceRoute)
Models/Types.swift                       — UI 层快照模型 (DashboardSnapshot)
```

---

## 11. Krypton 新信息架构映射

```
┌─────────────────────────────────────────────────────────┐
│ 一级工作区 (3)           │ 原 Section (8) → 二级页面     │
├─────────────────────────────────────────────────────────┤
│ Trading Console          │ OVERVIEW → Dashboard          │
│                          │           → Live Readiness    │
│                          │ STRUCTURE → Market Structure  │
│                          │           → Structure Matrix  │
│                          │           → Manipulation Radar│
│                          │ EXECUTION → Execution Center  │
│                          │           → Orders/Positions  │
│                          │           → Reconciliation Bus│
│                          │ RISK      → Risk Center       │
│                          │           → Stop Protection   │
│                          │           → Circuit Breakers  │
├─────────────────────────────────────────────────────────┤
│ Strategy Lab             │ STRATEGY   → Strategy Workspace│
│                          │            → Strategy Canvas  │
│                          │            → Backtest/Sim     │
│                          │ AI RESEARCH→ AI Research      │
│                          │            → Signal Center    │
│                          │            → Market Sentiment │
│                          │ GROWTH     → Review Growth    │
│                          │            → Failure Clustering│
│                          │            → Strategy Opt     │
├─────────────────────────────────────────────────────────┤
│ Operations               │ AI RESEARCH→ Agent Platform   │
│                          │ SYSTEM     → Service Mgmt    │
│                          │            → Data Source Mgmt │
│                          │            → System Settings  │
└─────────────────────────────────────────────────────────┘
```

---

## 12. 风险评估

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| 路由重组织导致入口丢失 | 功能不可访问 | 低 | 保留旧 AppRoute 枚举 + Command Palette 全覆盖 |
| Environment 移动导致状态不可见 | 页面崩溃 | 中 | 逐个迁移 + 编译验证 |
| 背景降级视觉效果不达预期 | 品牌感减弱 | 低 | 保留 Amber Glow + Bento Card 高光线 |
| Canvas WebView 保活内存增长 | 内存压力 | 低 | 仅 3 个工作区根视图保活，二级页面不保活 |
| Command Palette 危险动作误触 | 交易事故 | 低 | 初期只做导航，不做动作执行 |

---

## 13. 分阶段改造计划（与原始计划对齐）

| Phase | 内容 | 预计改动文件 | 风险 |
|-------|------|-------------|------|
| 0 | 本审查报告 | 0 | 无 |
| 1 | 性能止血 | ~15 | 中 |
| 2 | 信息架构收敛 | ~10 | 中 |
| 3 | Krypton Design System | ~15 | 低 |
| 4 | Dashboard Bento Console | ~12 | 低 |
| 5 | Command Palette 升级 | ~3 | 低 |
| 6 | Canvas 宿主 UI | ~10 | 中 |
| 7 | 模块页面迁移 | ~40 | 低 |
| 8 | 状态/错误/安全补齐 | ~8 | 低 |
| 9 | 最终验收 | 0 | 无 |
