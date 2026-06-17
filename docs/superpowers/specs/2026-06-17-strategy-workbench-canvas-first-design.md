---
title: 策略工作台 — 画布优先重设计
status: draft
date: 2026-06-17
authors: claude (brainstorming with user)
supersedes:
  - docs/superpowers/specs/2026-06-11-strategy-workbench-launch-console-design.md
related:
  - docs/architecture/13_strategyruledsl_semantics_v2_5.md
  - docs/architecture/10_database_erd_v2_5.md
  - docs/architecture/phases/phase_03_strategy_workspace_and_canvas.md
mockup: docs/ui-references/mockups/strategy-workbench-A-final.html
---

# 策略工作台 — 画布优先重设计

## 0. 问题陈述

旧版 `StrategyWorkspaceConsoleView`（2026-06-11 设计）有以下问题：

1. **AI 味浓**：磷光辉光、心跳光环、全大写 + tracking、EDIT BAY/LAUNCH CONSOLE 词汇、6 张等大 section card、7 节点占首屏的 LifecycleRail —— 视觉装饰多于信息密度。
2. **操作不清楚**：console / canvas 双模式互斥切换；详情页平铺 10 个旧 Tab 仍残留；动作按钮散落在 HUD / 卡片 / 菜单三处；用户不知道当前该做什么。
3. **信息展示混乱**：6 张 card 各占同等视觉权重，但实际 9 个核心问题（"这是什么策略 / 数据 / 是否通过回测 / 该做什么 …"）需要从多张卡片拼读才能回答。
4. **数据非真实**：信号 / 模拟 / 风控 / 增长 4 个 Tab 不传 `strategyId`，显示账户级或全局数据；多处硬编码 mock 占位（如 "Max Drawdown 15%"）。
5. **后端缺口**：没有 `bindings` 读写 API、没有策略复制 API、没有 per-strategy readiness、没有活动流；`/strategy-runs` `/backtest` `/dryrun` 不支持按 `strategy_version_id` 过滤。

## 1. 目标

1. 把策略工作台重新定义为 **画布优先**：无限画布占满主区，6 个面板按 ⌘1~⌘6 快捷键唤出。
2. 视觉去 AI 味：保留品牌磷光绿做强调色，但删除发光 / 心跳 / 全大写 / tracking / EDIT BAY 词汇。视觉对齐 ProofAlpha 暗色 design tokens。
3. 让页面随时回答 9 个 PRD 问题（见 §7.1.5–13）。
4. 所有数据来自后端真实端点，**不允许前端 mock 假展示**。后端缺能力本次一并补齐。
5. 删除孤儿页 `DryrunMonitorView`、废弃 `StrategyDetailView` + 10 Tab、废弃 console/canvas 双模式 toggle。
6. 重构 `BacktestLabView` 接 UUID 过滤；保留 3 列布局；与工作台 design tokens 一致。

## 2. 非目标

- 不重写 React Flow 内核或 bridge 协议（仅扩展两个新消息）。
- 不实现画布编译 / cycle 检测增强（DSL 仅 schema 校验）。
- 不做 AI 辅助策略生成、不做策略模板库。
- 不做跨策略 diff（同策略版本间 diff 已有）。
- 不做移动端响应式。

## 3. 信息架构

```
sidebar
├── strategy ─────────► strategyWorkspace
│                         └── StrategyCanvasWorkspaceView (画布全屏)
│                              ├── 顶 HUD (40px, 常驻)
│                              ├── 无限画布 (React Flow, WKWebView)
│                              ├── 底状态栏 (26px, 常驻)
│                              └── 6 个唤出面板 (浮层, ⌘1~⌘6 互斥, ESC 关闭)
│                                  ⌘1 策略列表 + 筛选 + 新建草稿
│                                  ⌘2 选中节点配置 + DSL 子树预览
│                                  ⌘3 版本列表 + 最近变更
│                                  ⌘4 风控绑定 + guards + 绑定 sheet
│                                  ⌘5 当前策略 run 列表 + 失败原因
│                                  ⌘6 11 项准入门禁 + 下一步
│
└── backtestSimulation ► BacktestLabView (重构为 UUID 过滤, 3 列布局保留)
                          ├── Run Rail (240px)
                          ├── ComparisonWorkbench (中间)
                          └── RunInspector (320px)
```

| 旧 → 新 |
|---|
| `console/canvas` 双模式 toggle → 画布即唯一视图 |
| 6 张 section card → 6 个 ⌘ 浮层面板 |
| 7 节点 LifecycleRail 占首屏 → HUD 内 7 段进度（10×4px） |
| EDIT BAY topbar → 取消，画布即视图 |
| `StrategyDetailView` + 10 Tab → 全部删除 |
| 孤儿 `DryrunMonitorView` → 删除（功能并入 BacktestLab） |

## 4. 视觉系统（ProofAlpha aligned）

预览参考：`docs/ui-references/mockups/strategy-workbench-A-final.html`。

### 4.1 Tokens（镜像 `DesignTokens.swift` 暗色主题）

| 类别 | Token | 值 |
|---|---|---|
| 背景 | `PulseColors.background` | `#0A0A0A` |
| 卡面 | `StateColors.card` / `cardBackground` | `#171B26` / `rgba(24,24,27,0.55)` |
| 表面 | `surface` / `surfaceElevated` | white α0.04 / α0.06 |
| 边框 | `border` | white α0.08 |
| 边框强调 | `borderAccent` | `#00FF9D` α0.25 |
| 强调 | `accent` | `#00FF9D` (品牌磷光绿) |
| 警告 | `warning` / `amber` | `#FFB800` |
| 危险 | `danger` | `#FF3B3B` |
| 信息 | `cyan` / `info` | `#00C2FF` |
| 控制 | `purple` | `#A855F7` |
| 文字 | `textPrimary / Secondary / Muted` | `#E0E0E0 / #888 / #555` |

### 4.2 反 AI 味规则

- **不允许**：发光 (`shadow color: accent`)、心跳脉冲、全大写 + letter-spacing、EDIT BAY / LAUNCH CONSOLE / MISSION CONTROL 词汇、等大 section card 网格、装饰性图标动画。
- **允许**：sentence case 标签、色点 + 文字组合状态、SF Mono 用于数字/hash/DSL（其他场合用 SF Pro）、表格化布局、紧凑数据密度。

### 4.3 节点视觉系统（9 类统一骨架）

- 紧凑表格卡：宽 188px，头部色点 + 类型 + 标题，body grid `auto 1fr` 列出最多 4 行参数。
- 头部色点：信号/条件 cyan、过滤 amber、执行 accent、控制平面 purple、风控 amber、其他按现有约定。
- 选中：1px accent 描边 + 1px outer ring。
- 校验失败：左侧 2px err 色条 + 节点边框 err 色 + 节点底部内联 error_code 一行。
- 端口：8px 圆点，背景 card 色，边框 white α0.16。
- emoji 图标移除（HTML 预览里有，实际 React 实现去掉）。

### 4.4 边/连线

- 默认 edge：`smoothstep`，1.5px，无标签。颜色 `rgba(255,255,255,0.18)`，"hot"（属于当前策略主链路）用 `accent`。
- MTFGuard edge：dashed `4 3`，purple 色。

## 5. 顶 HUD / 底状态栏 / 6 面板内容契约

### 5.1 顶 HUD（40px，常驻）

```
左：策略名 · v3 draft · 4f7a..b209 · 2h ago
右：Stage 进度 5/7  ·  准入 8/11  ·  下一步: 运行模拟 →
    [验证] [复制] [归档] [绑定实盘] [▶ 运行模拟] [⋯]
```

| 元素 | 数据源 |
|---|---|
| 策略名 | `strategy.name` |
| 版本号/状态 | `latestVersion.versionNo` + `.status` |
| dsl hash 短码 | `latestVersion.dslHash[:8]` |
| 时间 | `now − latestVersion.createdAt`（"2h ago"） |
| Stage 进度 7 段 | `LifecycleStage.from(strategy.status)` 映射 |
| 准入 X/11 | `workspace.readiness.passed_count / 11` |
| 下一步 | `workspace.readiness.next_action` |

**动作按钮契约：**

| 按钮 | enable 条件 | 调用 | 完成后 |
|---|---|---|---|
| 验证 | 始终 | `POST /api/v2/strategies/validate-dsl` | 刷新 HUD `validation` 状态 |
| 复制 | 始终 | `POST /api/v2/strategies/{id}/duplicate` | 跳转新 strategyId |
| 归档 | `status ≠ archived` | `PATCH /api/v2/strategies/{id}/archive` | 刷新 HUD，画布转只读 |
| 绑定实盘 | `status == paper_passed` 时高亮 | 唤出 ⌘4 进入 binding sheet | — |
| 运行模拟 | `status ∈ {validated, backtested, paper_passed}` | `POST /api/v2/dryrun` 然后跳回测/模拟页 | 跳转 |
| ⋯ 菜单 | 含 lifecycle transition | `PATCH /strategies/{id}/versions/{vid}/status` | 刷新 |

按钮 disable 时显示 tooltip 解释为什么不可点。

### 5.2 底状态栏（26px，常驻）

```
● 验证通过 · v3 4f7a..b209 · 2h ago · 12 节点 · 11 连线        ⌘1~⌘6 提示
```

| 元素 | 数据源 |
|---|---|
| 验证状态 ●/⚠/✗ | canvas-web `validation.valid` (live) |
| 版本/hash | latest version |
| 节点/连线计数 | canvas-web `graphStats` 桥接消息 |
| 快捷键提示 | 静态 |

### 5.3 6 个浮层面板

| 面板 | 内容 | 数据源 |
|---|---|---|
| **⌘1 策略列表** | 搜索 + 4 桶筛选（all/draft/paper/live）+ 列表 + 新建草稿入口 | `workspace.strategies` |
| **⌘2 节点配置** | 节点参数 form（Swift native 渲染，9 类节点各一套）+ 校验内联错误 + DSL 子树预览（mono） | canvas-web 通过 bridge 推送 `selectedNode.data`；编辑后 bridge 调 `updateNodeData(id, data)` 写回 |
| **⌘3 版本** | 顶部最近变更 3 行 + 版本列表（v#/status/hash/time，当前高亮）+ 行内 diff/rollback | `GET /strategies/{id}/activity` + `versions[]` |
| **⌘4 风控绑定** | 当前 binding（mode/policy.name/pool.name/余量）+ guards 4 gauge + 绑定 sheet | `GET /strategies/{id}/bindings` + `GET /risk/overview?strategy_id=` |
| **⌘5 回测/模拟** | 顶部最近回测+最近模拟摘要 + 全部 run 列表 + 失败 run 行内"查看失败原因" + [查看全部 →] | `workspace.recent_backtests` + `workspace.recent_dryruns` |
| **⌘6 实盘准入** | 总状态徽章 + 6 项策略门禁 + 5 项系统门禁 + 失败可点跳修复 + 下一步 | `workspace.readiness` |

### 5.4 PRD 信息块映射

| PRD 列出的信息块 | 落位 |
|---|---|
| 信号逻辑摘要 | 画布本体 + ⌘2 DSL 子树预览 |
| 数据依赖 | ⌘2 选中 SignalInput 节点 |
| 最近表现 | ⌘5 顶部摘要 + HUD 第二行 trailing |
| 最近变更 | ⌘3 顶部 |
| 策略验证 | HUD 验证按钮 + 状态栏 ●/⚠/✗ + ⌘2 错误内联 |
| 查看失败原因 | ⌘5（dryrun）+ ⌘6（准入）+ ⌘2（DSL）三处可展开 |

## 6. 后端补齐

### 6.1 新增端点（7 个）

#### A. `GET /api/v2/strategies/{id}/workspace` — BFF 聚合

```
Response: WorkspaceSnapshotResponse
{
  strategy: StrategyV2Response,
  versions: [StrategyVersionResponse],          // 最多 10 条 desc by version_no
  latest_version_id: UUID,
  bindings: [StrategyBindingResponse],          // latest version 的全部 bindings
  recent_backtests: [BacktestRunSummary],       // 最多 5 条
  recent_dryruns: [StrategyRunSummary],         // mode in (dry_run, paper)，最多 5 条
  readiness: PerStrategyReadinessResponse,      // 见 §6.4
  activity: [ActivityEntry],                    // 最多 10 条
  signal_logic_summary: { entry_text, exit_text, filter_count },
  data_dependencies: { symbols, timeframes, indicators, signal_sources }
}
```

实现：`app/services/strategy_workspace_aggregator.py` 并行查询 + 调 `LiveReadinessService.compute_for_strategy`。Redis 缓存 5s（key: `pulsedesk:workspace:{strategy_id}`）。

#### B. `POST /api/v2/strategies/{id}/duplicate`

```
Body: { name?: string }      // 默认 "{原名} copy"
Response: StrategyV2Response  // 新 strategy
```

事务：新 `Strategy(status=draft)` + 克隆 latest version 为 `StrategyVersion(version_no=1, status=draft, rule_dsl 深拷贝, dsl_hash 重算, created_by)`。**不复制 bindings、runs、backtests**。

#### C. `GET /api/v2/strategies/{id}/bindings`

```
Response: [StrategyBindingResponse]
{
  id, strategy_version_id, version_no,
  risk_policy: { id, name, version_no, policy_json_summary },
  capital_pool: { id, name, pool_type, total_budget, currency, remaining_budget },
  mode,           // backtest | dry_run | shadow | live_small
  created_at
}
```

#### D. `POST /api/v2/strategies/{id}/bindings`

```
Body: {
  strategy_version_id: UUID,         // 默认 latest
  risk_policy_version_id: UUID,
  capital_pool_id: UUID,
  mode: "live_small" | "backtest" | "dry_run" | "shadow"
}
Response: StrategyBindingResponse
Errors:
  409 BINDING_DUPLICATE       (strategy_version_id, mode) 已存在
  422 BINDING_POOL_MISMATCH   pool_type 与 mode 不匹配
  422 BINDING_POLICY_ARCHIVED RiskPolicyVersion.status == archived
```

事务：写 `strategy_risk_policy_bindings` + 写 activity log。校验 mode/pool_type 一致性（live_small mode 必须用 live_small pool）。

#### E. `DELETE /api/v2/strategies/{id}/bindings/{binding_id}`

```
Response: 204
Errors:
  409 BINDING_IN_USE   该 binding 当前有 active StrategyRun
```

#### F. `PATCH /api/v2/strategies/{id}/archive`

```
Body: { reason?: string }
Response: StrategyV2Response
```

事务：所有 non-archived versions 转 archived（复用 `strategy_transition.validate_transition`）+ `strategy.status='archived'` + 写 activity log。

#### G. `GET /api/v2/strategies/{id}/activity`

```
Query: limit (default 20)
Response: [ActivityEntry]
{
  id, kind,        // version_created | version_status_changed | binding_added |
                   // binding_removed | run_started | backtest_completed | archived
  occurred_at, actor,
  summary: string,           // "v3 created from canvas"
  delta: { node_count_change, edge_count_change, fields_changed[], ... },
  ref: { kind: "version|binding|run|backtest", id: UUID }
}
```

实现：写入钩子 — `create_version` / `transition_version_status` / `create_binding` / `delete_binding` / `start_run` / `complete_backtest` / `archive_strategy` 七个点。

### 6.2 现有端点改造（4 个）

| 端点 | 改造 |
|---|---|
| `GET /api/v2/strategy-runs` | 新增 `strategy_version_id?: UUID` 和 `strategy_id?: UUID` query |
| `GET /api/v2/backtest` | 现 `strategy_id: int` 标 deprecated；新增 `strategy_id: UUID` 和 `strategy_version_id: UUID`。底层 `BacktestRun` 加 UUID 列（见 §6.3） |
| `GET /api/v2/dryrun` | 加 `strategy_version_id?: UUID` |
| `GET /api/risk/overview` | 加 `strategy_id?: UUID`，不传时维持账户级行为（向后兼容） |

### 6.3 数据库迁移（1 个 alembic 脚本）

```sql
-- 1. activity log
CREATE TABLE strategy_activity_log (
  id UUID PRIMARY KEY,
  strategy_id UUID NOT NULL REFERENCES strategies_v2(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor TEXT,
  summary TEXT NOT NULL,
  delta JSONB,
  ref_kind TEXT,
  ref_id UUID
);
CREATE INDEX idx_activity_strategy_time ON strategy_activity_log(strategy_id, occurred_at DESC);

-- 2. backtest_runs UUID 兼容
ALTER TABLE backtest_runs ADD COLUMN strategy_uuid UUID REFERENCES strategies_v2(id);
ALTER TABLE backtest_runs ADD COLUMN strategy_version_id UUID REFERENCES strategy_versions(id);
CREATE INDEX idx_backtest_runs_strategy_uuid ON backtest_runs(strategy_uuid, completed_at DESC);
-- 旧 int strategy_id 列保留, 标 deprecated, 新写入只填 UUID 列。

-- 3. strategy_runs 已有 strategy_version_id（ERD §7），不动。
```

`downgrade` 反向。dev 环境不保留旧 int 列数据迁移路径（dev 环境可重置）。

### 6.4 PerStrategyReadinessResponse

```python
{
  passed_count: int,        # 0..11
  total: 11,
  grand_status: "not_live" | "needs_config" | "needs_validation" | "paper_passed" | "ready_for_live",
  next_action: { code: str, label: str, target_panel?: "risk"|"backtest"|"readiness" },
  strategy_gates: [          # 6 项 per-strategy
    { key: "validation",   status, value, threshold, detail, reason_codes },
    { key: "backtest",     ... },
    { key: "dryrun",       ... },
    { key: "risk_config",  ... },
    { key: "capital",      ... },
    { key: "strategy",     ... }
  ],
  system_gates: [            # 5 项账户级（复用现有 LiveReadinessService）
    { key: "exchange", ... },
    { key: "data_source", ... },
    { key: "notification", ... },
    { key: "emergency_stop", ... },
    { key: "mode", ... }
  ]
}
```

`LiveReadinessService.compute_for_strategy(strategy_id, db)`：6 项策略门禁查 strategy 自己的 versions/bindings/recent runs；5 项系统门禁直接复用账户级结果。`next_action` 推断：第一个失败的策略门禁决定，全过则用 grand_status 推断。

### 6.5 文件落位（backend）

```
backend/app/
├── routers/
│   ├── strategy_workspace.py   (NEW: 7 端点)
│   ├── strategies_v2.py        (改: 加 archive 入口, 委派到 service)
│   ├── strategy_runs.py        (改: 加 strategy_version_id query)
│   ├── backtest.py             (改: 加 UUID 参数)
│   ├── dryrun.py               (改: 加 strategy_version_id query)
│   └── risk_bff.py             (改: overview 加 strategy_id query)
├── services/
│   ├── strategy_workspace_aggregator.py   (NEW)
│   ├── strategy_duplicate_service.py       (NEW)
│   ├── strategy_archive_service.py         (NEW)
│   ├── strategy_activity_service.py        (NEW)
│   ├── strategy_binding_service.py         (NEW)
│   └── live_readiness_service.py           (改: 加 compute_for_strategy)
├── schemas/
│   └── strategy_workspace.py    (NEW: 7 个新 schema)
├── repositories/
│   └── strategy_repository.py   (改: 加 list_bindings / list_activity / clone_version)
├── domain/
│   └── activity_log.py          (NEW: StrategyActivityLog 模型)
└── alembic/versions/
    └── 2026_06_17_xxxx_strategy_workspace.py   (NEW)
```

### 6.6 测试要求（pytest）

| 文件 | 测试 |
|---|---|
| `test_strategy_workspace_aggregator.py` | BFF 聚合 happy / 无 version / 无 bindings / 无 runs / Redis miss / cache hit |
| `test_strategy_duplicate.py` | 克隆 happy / version_no=1 / dsl 深拷贝独立 / bindings 不复制 / runs 不复制 |
| `test_strategy_binding.py` | 创建 / 重复 409 / mode-pool 不匹配 422 / in-use 删除 409 / 正常删除 |
| `test_strategy_archive.py` | non-archived 全转 / 已 archived idempotent |
| `test_strategy_activity_log.py` | 7 个钩子点都写入 / 列表分页 |
| `test_live_readiness_per_strategy.py` | 6 个策略门禁 × 状态组合 / grand_status 5 级映射 / next_action 推断 |
| `test_strategies_v2_uuid_filter.py` (扩展) | runs/backtest/dryrun 都按 strategy_version_id 过滤 |

CI 覆盖率门槛仍 30%。

## 7. 前端文件分解

### 7.1 macOS app

```
macos-app/AlphaLoop/
├── Models/
│   ├── Types.swift                    (改: 加 WorkspaceSnapshot, StrategyBinding, ActivityEntry,
│   │                                       PerStrategyReadiness, RiskPolicySummary, CapitalPoolSummary)
│   └── Enums.swift                    (改: WorkbenchPanel = list|node|version|risk|backtest|readiness;
│                                          删 WorkspaceMode, InspectorTab, strategyDetail/Canvas case)
│
├── Services/
│   ├── APIStrategyWorkspace.swift     (NEW: 7 个新端点)
│   ├── APIStrategiesV2.swift          (改: listBacktests UUID 参数)
│   ├── APIBacktest.swift              (改)
│   ├── APIDryrunV2.swift              (改)
│   ├── APIStrategyRuns.swift          (改)
│   └── APIRiskBFF.swift               (改)
│
├── ViewModels/
│   ├── StrategyWorkspaceViewModel.swift   (重写)
│   ├── BacktestLabViewModel.swift          (改: UUID 过滤, 合并 dryruns)
│   ├── DryrunMonitorViewModel.swift        (删除)
│   └── StrategyDetailViewModel.swift       (删除)
│
├── Views/
│   ├── Strategies/
│   │   ├── Workbench/
│   │   │   ├── StrategyCanvasWorkspaceView.swift   (重写, 替换原 ConsoleView)
│   │   │   ├── WorkbenchHUD.swift                  (NEW)
│   │   │   ├── WorkbenchStatusBar.swift            (NEW)
│   │   │   ├── StagePill.swift                     (NEW)
│   │   │   ├── ReadinessPill.swift                 (NEW)
│   │   │   └── Panels/
│   │   │       ├── PanelChrome.swift               (NEW: 浮层壳)
│   │   │       ├── StrategyListPanel.swift         (NEW: ⌘1)
│   │   │       ├── NodeConfigPanel.swift           (NEW: ⌘2 壳, 内嵌 9 类 form)
│   │   │       ├── NodeConfigForms/                (NEW: 9 类节点 native form)
│   │   │       │   ├── SignalInputForm.swift
│   │   │       │   ├── IndicatorConditionForm.swift
│   │   │       │   ├── FilterForm.swift
│   │   │       │   ├── PositionSizingForm.swift
│   │   │       │   ├── RiskPolicyForm.swift
│   │   │       │   ├── ExecutionOutputForm.swift
│   │   │       │   ├── StructureDefenseForm.swift
│   │   │       │   ├── AccountRiskForm.swift
│   │   │       │   └── MTFGuardForm.swift
│   │   │       ├── VersionsPanel.swift             (NEW: ⌘3)
│   │   │       ├── RiskBindingPanel.swift          (NEW: ⌘4)
│   │   │       ├── BacktestDryrunPanel.swift       (NEW: ⌘5)
│   │   │       └── ReadinessPanel.swift            (NEW: ⌘6)
│   │   ├── (删除) ConsoleCenterStack.swift / SectionCards.swift / WorkspaceChrome.swift /
│   │   │          StrategyWorkspaceConsoleView.swift
│   │   ├── (删除) StrategyDetailView.swift + Strategy{Overview,DSL,Backtest,Dryrun,Risk,Runs,
│   │   │          Signals,Versions,Growth,CanvasWeb}Tab.swift + StrategyLifecycleRailView.swift
│   │   ├── (删除) StrategiesListView.swift / StrategyCardView.swift / StrategyCreatePanel.swift
│   │   └── (保留) AIChatView.swift / DSLValidationReportView.swift / MTFGuardSummaryCard.swift /
│   │              BacktestResultCardView.swift / StrategyUpgradeRequestView.swift
│   │
│   ├── Canvas/
│   │   ├── CanvasWebView.swift            (保留)
│   │   ├── CanvasBridge.swift             (改: 新增 selectionChanged / graphStats 消息)
│   │   ├── CanvasTopActionBar.swift       (删除, 并入 WorkbenchHUD)
│   │   └── (删除) StrategyCanvasPageView.swift / CanvasBackground.swift /
│   │              CanvasSearchOverlay.swift / CanvasEdges.swift / CanvasSelectionRect.swift /
│   │              CanvasDSLPreviewPanel.swift
│   │
│   ├── BacktestAndDryrun/
│   │   ├── BacktestLabView.swift           (改: UUID 过滤, 合并 dryrun)
│   │   └── NewRunSheet.swift               (改: 用 latest_version_id)
│   │
│   └── DryrunMonitor/  (整目录删除)
│
├── Localization/
│   ├── L10n+Workbench.swift               (重写)
│   ├── L10n+BacktestLab.swift              (改: 加 dryrun 段)
│   └── L10n+Dryrun.swift                   (删除)
│
└── App/AppShellView.swift                  (改: .strategyWorkspace → StrategyCanvasWorkspaceView)
```

**净变化：删除 21 个文件（含 React `NodeConfigPanel.tsx`），新增 23 个 Swift 文件（14 个面板/HUD + 9 个 native node form）。**

### 7.2 `StrategyWorkspaceViewModel`（重写）

```swift
@Observable @MainActor
final class StrategyWorkspaceViewModel {
    // 数据
    var strategies: [StrategyV2]
    var selectedStrategyId: String?
    var snapshot: WorkspaceSnapshot?
    var isLoadingList, isLoadingSnapshot: Bool
    var listError, snapshotError: String?

    // UI 状态
    var activePanel: WorkbenchPanel?         // nil = 画布全屏无浮层
    var search: String
    var filter: TrackFilter
    var selectedCanvasNodeId: String?        // 由 CanvasBridge 同步, 驱动 ⌘2
    var canvasNodeCount, canvasEdgeCount: Int
    var canvasValidationValid: Bool?

    // 派生
    var selectedStrategy: StrategyV2?
    var filteredStrategies: [StrategyV2]
    var nextActionCode: String?

    // 加载
    func loadList() async
    func select(strategyId: String) async
    func reloadSnapshot() async              // 调 GET /workspace
    func bindingsRefresh() async

    // 动作
    func validate() async -> DSLValidationReport
    func duplicate() async -> StrategyV2?
    func archive(reason: String?) async
    func transitionStatus(_ t: LifecycleTransition) async
    func startDryrun() async -> String?
    func startBacktest(versionId: String, timerange: String, symbols: [String], capital: Double) async
    func createBinding(versionId: String, policyVersionId: String, poolId: String, mode: String) async
    func deleteBinding(_ bindingId: String) async

    // 面板
    func openPanel(_ p: WorkbenchPanel)
    func togglePanel(_ p: WorkbenchPanel)
    func closePanel()
}
```

`WorkspaceSnapshot` 直接对应后端 `WorkspaceSnapshotResponse`，前端不再做任何字段拼装。

### 7.3 canvas-web 改动

| 改动 | 文件 | 说明 |
|---|---|---|
| 新增 bridge 消息 `selectionChanged` | `bridge.ts`, `types.ts`, `App.tsx` | 节点选中/取消选中时 → Swift |
| 新增 bridge 消息 `graphStats` | 同上 | nodes/edges count 或 validation 状态变化时 → Swift |
| 节点视觉重绘 | 9 个节点 + `nodes/NodeShell.tsx` | 紧凑表格卡 + 头部色点 + sentence case + emoji 移除 |
| Edge 样式 | `App.tsx` | `smoothstep` 1.5px；MTFGuard 保留 dashed |
| 删除内置 toolbar / status-bar / palette title / NodeConfigPanel | `App.tsx`, `panels/NodeConfigPanel.tsx` (删) | 由 Swift HUD/状态栏/⌘2 接管。**保留 palette**（左侧 9 类节点拖拽源）。删除 React 内的 `NodeConfigPanel.tsx` —— 节点参数 form 改 Swift native（⌘2 内）|
| 配色 token | `styles/*.css` | 镜像 ProofAlpha tokens |
| MiniMap nodeColor | `App.tsx` | 沿用 9 类色映射，色值换 ProofAlpha |
| Background dots | `App.tsx` | gap 24, color rgba(255,255,255,0.030) |

**节点参数 form 改 Swift native 渲染**：⌘2 与其他 5 面板视觉一致（玻璃浮层）；canvas-web 不再渲染 NodeConfigPanel；bridge 协议扩展 `selectionChanged`（推 `selectedNode.data`）和 `updateNodeData(id, data)`（Swift → React 写回）。9 类节点的 form schema 在 `Views/Strategies/Workbench/Panels/NodeConfigForms/<NodeType>Form.swift` 各一套。

### 7.4 `BacktestLabViewModel`（改）

```swift
async let backtests = backtestAPI.list(strategyId: uuid, limit: 25)
async let dryruns   = dryrunAPI.listRuns(strategyVersionId: latestVid, limit: 25)
// 合并为 RunRow (kind: backtest|dryrun) 排序展示
// comparedRunIds: Set<String>
// championRun 仅从 backtest 中选 Sharpe 最高
```

`BacktestLabView` 视觉跟工作台对齐（同 design tokens），3 列布局结构不变。

### 7.5 路由

```swift
// AppRoute 保留 strategyWorkspace, backtestSimulation
// AppShellView .strategyWorkspace → StrategyCanvasWorkspaceView
// 删除：strategyDetail, strategyCanvas case
```

### 7.6 跨页协调（AppState）

`AppState.selectedStrategyV2Id` 保留：工作台选中策略 → 写 AppState；BacktestLabView bootstrap 读 AppState；⌘5 [查看全部 →] 跳 `.backtestSimulation` 自动同步选中。

## 8. 关键动作时序

### 8.1 验证

```
HUD [验证] → VM.validate()
            ├ canvas-web bridge.requestValidation()
            │  └ graphToDsl + POST /strategies/validate-dsl
            │     └ canvas-web 写 validation 状态 + 节点 inline 错误高亮
            └ bridge 回传 → VM.canvasValidationValid → 状态栏 ●/⚠/✗
              失败：自动唤出 ⌘2，定位到第一个错误节点
```

### 8.2 复制

```
HUD [复制] → VM.duplicate()
            ├ POST /strategies/{id}/duplicate (后端事务克隆)
            ├ VM.strategies.insert(new, at:0) → VM.select(new.id) → reloadSnapshot
            │  └ canvas-web bridge.loadDSL(new.latestVersion.ruleDsl)
            └ toast "已复制为 {新名称}"
```

### 8.3 归档

```
HUD [归档] → 二次确认 sheet (原因可选)
            └ VM.archive(reason)
              ├ PATCH /strategies/{id}/archive (事务转所有 version 为 archived)
              ├ VM.reloadList → 列表移到 archived bucket
              └ VM.snapshot 更新
                画布只读模式：bridge.setReadOnly(true) 禁用 palette 拖拽 + 节点编辑
```

### 8.4 绑定实盘

```
HUD [绑定实盘] → 唤出 ⌘4 RiskBindingPanel
                └ 用户点 [绑定 live_small]
                  └ binding sheet
                    ├ 选 RiskPolicyVersion (拉 GET /risk-policies/versions?status=active)
                    ├ 选 CapitalPool (拉 GET /capital-pools?pool_type=live_small)
                    └ 提交 → VM.createBinding(latestVid, policyVid, poolId, "live_small")
                            ├ POST /strategies/{id}/bindings
                            ├ VM.reloadSnapshot → HUD readiness X→X+1
                            └ ⌘6 准入面板自动刷新
```

### 8.5 运行模拟

```
HUD [运行模拟] → 前置校验：
                - validation.valid? 否 → 唤出 ⌘2 + toast
                - status ∈ {validated, backtested, paper_passed}? 否 → toast
                - latest version 有 dry_run binding? 否 → 唤出 ⌘4 提示
                通过 → dryrun 配置 sheet (symbols, timerange, initial_capital)
                  └ VM.startDryrun()
                    ├ POST /api/v2/dryrun (Command Bus 入队)
                    ├ 跳转 .backtestSimulation (写 AppState.lastStartedCommandId)
                    └ (回到工作台时) ⌘5 自动显示新 run
```

## 9. 错误处理矩阵

| 错误源 | 触发场景 | UI 表现 |
|---|---|---|
| 后端 4xx | 409 BINDING_DUPLICATE / 422 invalid lifecycle transition | 浮层内 banner 红条 + reason_codes，不退出当前面板 |
| 后端 5xx | BFF 聚合超时 / 部分子查询失败 | snapshot 部分字段缺失时降级渲染：缺失项 "—" + 状态栏左侧 retry 按钮 |
| DSL 校验失败 | canvas-web `requestValidation` 失败 | 节点级红边 + 内联 error_code；状态栏 ●→✗；自动唤出 ⌘2 滚动到首错 |
| 网络断连 | 任意 API 调用 | toast + AppState.networkOnline=false，HUD 动作按钮全 disable |
| WebView 加载失败 | canvas-web bundle 缺失 | 占位 + "重新加载画布" 按钮 + 一行错误日志 |
| Bindings in use | 409 BINDING_IN_USE | 二次确认 sheet 列出 active run + "停止 run 后再删除" |
| 状态过期 | 用户在状态变更后才点动作 | toast "状态已变更"，自动 reloadSnapshot |
| canvas-web bridge 崩溃 | postMessage 失败 | 状态栏右侧 "桥接断开" + [重连] 按钮 reload WKWebView |

错误码命名：`DSL_*` / `STRATEGY_*` / `BINDING_*` / `READINESS_*`。

## 10. L10n keys

新增 `Localization/L10n+Workbench.swift`（重写），所有用户可见字符串走 `L10n.Workbench.*` —— 零硬编码。

### `L10n.Workbench` 命名空间分组

| 分组 | 内容 |
|---|---|
| `identity` | 策略名 / 版本号 / 时间表达 / 状态徽章 |
| `hud` | 阶段标签 / 准入标签 / 下一步标签 / 6 个动作按钮 |
| `status` | 验证通过 / 验证失败 / 警告 / 桥接断开 / 网络离线 |
| `panels` | 6 个面板的标题 + 子标题 + 空状态 |
| `node` | 9 类节点的 type 标签 + parameter key 名 |
| `versions` | 最近变更 / 版本列表 / diff / rollback / hash 短码 |
| `risk` | 当前 binding / 未绑定 / guards 各项 |
| `backtest` | 最近回测 / 最近模拟 / 失败原因 / 查看全部 / 冠军 |
| `readiness` | 11 项 check key + reason_codes 翻译表 + grand_status 5 级 |
| `binding_sheet` | 选 RiskPolicy / 选 CapitalPool / 模式 / 提交 / 错误 |
| `duplicate` | 复制为... / 默认名后缀 |
| `archive` | 归档原因 / 已归档警告 / 只读模式提示 |
| `transitions` | 9 个 lifecycle transition 标签 |
| `errors` | 错误码 → 中英人话翻译表 |
| `shortcuts` | ⌘1~⌘6 标签 |

### `L10n.BacktestLab` 增量

```
mode_filter  · 全部 / 回测 / 模拟
run_kind     · backtest / dryrun
inspector    · 失败原因 / 错误码 / 重试
```

### 删除

- 整文件：`L10n+Dryrun.swift`
- `L10n.Workbench` 旧 keys：`modeConsole / modeCanvas / canvasEditBay / canvasReturnConsole / cardRuntime / cardSignals / drawerDecision / drawerReason / drawerLogs`，`railSearch` 改名 `panelSearch`

## 11. 验收标准

### 视觉/IA
1. 进入 `.strategyWorkspace`：画布占满主区，顶 HUD 40px / 底状态栏 26px / 无 Tab 栏 / 无 console-canvas toggle
2. 1280–1920 宽响应；浮层右上不遮挡 zoom 控件
3. 全局只用 `PulseColors.*`，零硬编码颜色（grep `Color(red:` / `Color(hex:` 限 `DesignTokens.swift` 内）
4. 全局零全大写 + 零 letter-spacing 装饰 + 零发光/心跳动画

### 9 个 PRD 问题全部能从 UI 上回答
5. 「这是什么策略？」HUD 显示名+类型+源
6. 「使用什么数据？」⌘2 选中 SignalInput 节点显示 symbols/timeframe/source
7. 「是否有效？」状态栏 ●/⚠/✗ + ⌘6 总状态徽章
8. 「是否通过回测？」⌘5 顶部 + ⌘6 backtest 门禁
9. 「是否通过模拟？」⌘5 顶部 + ⌘6 dryrun 门禁
10. 「是否可以实盘？」⌘6 grand_status + 11 项门禁
11. 「绑定了什么风控？」⌘4 当前 binding 区
12. 「最近改了什么？」⌘3 顶部 + ⌘5 顶部
13. 「现在该做什么？」HUD 第二行「下一步：xxx →」+ ⌘6 next_action

### 19 个能力
14. 列表/状态/版本/说明/数据依赖/信号逻辑摘要/风控绑定/回测状态/模拟状态/实盘准入/最近表现/最近变更全部 per-strategy 来自后端
15. 6 个动作（验证/复制/编辑/归档/绑定实盘/运行模拟/查看失败原因）全部 wired 到真实端点
16. 「查看失败原因」覆盖 DSL 失败 / dryrun 失败 / 准入失败三场景

### 数据真实性
17. 完全没有 mock 占位字符串展示给用户（`MockX.*` 仅在 `MockNetworkClient` 路径出现）
18. 所有 per-strategy 显示数据按 strategy_version_id 过滤

### 后端
19. 7 个新端点都有 pytest 覆盖（§6.6）
20. CI 覆盖率 ≥ 30%
21. alembic migration up + down 双向可执行

### 回测/模拟页
22. BacktestLabView 显示当前选中策略的 backtests + dryruns 合并视图，按 strategy_version_id 过滤
23. 跨策略对比保留：切换 strategy 后 runs 列表换；comparedRuns 跨切换重置

### i18n
24. 中英文双语切换无硬编码字符串遗漏

### 画布
25. 9 类节点视觉统一，节点选中/失败状态可视化清晰
26. 选中节点 → ⌘2 自动唤出且参数 form 可编辑保存
27. 画布支持无限平移缩放、minimap、空格 + 拖拽 pan、滚轮 zoom

## 12. Out-of-scope（future）

- 画布节点编译/cycle 检测增强（DSL 当前仅 schema 校验）
- 跨策略 diff（仅同策略不同版本 diff）
- AI 辅助生成 StrategyDraft（旧链路保留，UI 不动）
- 画布模板库
- Bindings 多 mode 同时编辑（一次只 1 mode = live_small）
- Activity log 更细粒度事件（如每次 ledger event）
- canvas-web 内部国际化（节点 type 标签和 parameter key 暂仅中文，Swift 壳层 i18n）
- 回测/模拟页移动端响应式（仅 1280+ 桌面）
- 快捷键深度自定义（⌘1~⌘6 写死）
