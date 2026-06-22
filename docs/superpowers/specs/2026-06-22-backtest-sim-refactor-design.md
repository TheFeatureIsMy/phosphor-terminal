---
title: 回测 / 模拟页面深度重构
status: draft
date: 2026-06-22
authors: claude (brainstorming with user)
supersedes_partial:
  - docs/superpowers/specs/2026-06-17-strategy-workbench-canvas-first-design.md  # 仅 backtest/dryrun 段落
related:
  - docs/architecture/16_freqtrade_runtime_contract_v2_5.md
  - docs/architecture/14_command_bus_worker_contract_v2_5.md
  - docs/architecture/10_database_erd_v2_5.md
  - docs/superpowers/specs/2026-06-15-live-readiness-industrial-control-design.md
---

# 回测 / 模拟页面深度重构

## 0. 问题陈述

现有 `BacktestLabView`（`macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift`，770 行）存在以下严重问题：

1. **伪造数据**：equity curve 在客户端用 `SeededRandom` PRNG 合成（line 595 注释承认 "backend did not return equity_curve"），图看起来真实但是噪声。
2. **AI 味儿浓**：4-6 列 KPI metric grid + emoji-like SF Symbol + 条件着色，典型模板化仪表盘。
3. **三列布局混乱**：Run Rail | Comparison | Inspector 三列常驻，信息同时涌入，无叙事链路。
4. **mock 数据不透明**：所有 API client 用 inline mock factory 作为 fallback，用户无法区分真实数据与假数据。
5. **`AnyCodable` 滥用**：`BacktestRunV2.config` / `.result` 用 `[String: AnyCodable]`，schema 全靠字符串 key 运行时访问。
6. **NewRunSheet 输入原始**：日期/资金/交易对全是纯文本框，无 DatePicker、无校验、无 autocomplete。
7. **链路断裂**：「运行参数 → 结果 → 风险 → 晋级实盘」没有串成一条线，晋级按钮只是装饰。

本次重构目标是把页面重做为**单页纵向叙事流**，所有结果来自真实 backend run，禁止任何 fake performance data，把运行参数到晋级实盘的链路串成清晰主线。

## 1. 范围

### 在范围

- 重写 `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift` 与配套 ViewModel / API service / L10n。
- 重写 `NewRunSheet.swift`。
- 后端最小改动：`StartBacktestRequest` 加 `slippage_bps`、`BacktestRunResponse` 强类型化 `equity_curve` / `trades`、`failure-clusters` 接口支持 `strategy_uuid` 过滤。
- 重写 user-guide 双语章节。
- 更新 `CLAUDE.md` 的 BacktestLabView 描述。

### 不在范围

- 不动 `ExecutionRecordsView` / `ExecutionDetailSheet`（全量 run 历史，不是本页）。
- 不动 `LiveReadinessView`（⑧ 只跳转过去，不在本页启动实盘）。
- 不动 shadow strategy 生成流程（⑦ 只跳转过去）。
- 不动 Qlib 因子研究（与本页无关）。
- 不动 `strategy_runs` 表结构（mode 五档不变，本页只用 backtest / dry_run 两档）。

## 2. 整体架构

**路由不变**：`AppRoute.backtestSimulation`（Cmd+4），`SidebarSection.strategy` 下。`AppShellView` 渲染入口指向重写后的 `BacktestLabView`。

**页面结构**：左固定 Run Rail（240pt）+ 右纵向叙事主区，九段从上到下：

```
┌─────────────────────────────────────────────────────────────────┐
│ TopBar: 策略选择器 | 执行模式段控(回测/dry_run) | 新建 Run | MOCK│
├──────────┬──────────────────────────────────────────────────────┤
│          │ ① ConfigPanel    运行参数                              │
│  Run     │ ② StatusPanel    回测状态 + 模拟状态（双卡）           │
│  Rail    │ ③ SummaryPanel   收益/回撤/胜率/盈亏比                 │
│  240pt   │ ④ CurvePanel     equity curve + drawdown              │
│          │ ⑤ TradeListPanel trade list + run 内失败聚类           │
│          │ ⑥ ComparePanel   与历史 run 对比（可折叠）             │
│          │ ⑦ RiskPanel      策略级失败聚类 + 风险警告             │
│          │ ⑧ PromotionPanel 晋级准入（闸门摘要 + CTA）            │
│          │ ⑨ DataSourceFooter 数据源说明                         │
└──────────┴──────────────────────────────────────────────────────┘
```

### 叙事流解锁规则

ViewModel 持有 `Phase` 状态机：

```
enum Phase { case idle, configuring, running, completed, failed }
```

- `idle`：未选策略 → 仅 ① 灰显。
- `configuring`：选了策略、未发起 run → ① 可编辑，②-⑧ 灰阶占位。
- `running`：command 已 enqueue → ① 锁定，② 显示进度，③-⑧ 灰阶占位 + 「等待运行完成」。
- `completed`：`status == "completed"` 且 `result` 非空 → 全部解锁。
- `failed`：`status in {"failed","error"}` → ② 显示错误，③-⑥ 隐藏，⑦ 显示失败提示，⑧ 仍展示但 backtest 闸门未通过。

## 3. 组件细化

### TopBar

- **策略选择器**：下拉，options 来自 `APIStrategiesV2.list()`。选中后所有 section 切到该策略。
- **执行模式段控**：两档 — `回测` / `模拟(dry_run)`。切换改变 ① 可编辑字段与 ② 双卡显示。
- **新建 Run 按钮**：弹 `NewRunSheet`。
- **MOCK 徽章**：`NetworkClient` 为 mock 模式时显示，红底白字。

### ① ConfigPanel（运行参数）

所有字段对应 `StartBacktestRequest` / `StartDryRunRequest` 真实入参，无展示型字段：

| 字段 | 控件 | 数据来源 |
|---|---|---|
| 时间周期 | 下拉（只读） | `strategy_version.rule_dsl.timeframe` |
| 日期区间 | `DatePicker` 范围 | 回测必填；dry_run 隐藏 |
| 交易对 | 多选 | DSL `symbols` 白名单，默认全选 |
| 初始资金 | `TextField` + `NumberFormatter` | `initial_capital`，>0 |
| 手续费模型 | 下拉 `交易所默认(0.05%)` / `自定义` | `fee` 字段 |
| 滑点模型 | 下拉 `无` / `固定bps` / `百分比` | 新增 `slippage_bps` 字段；`百分比` 模式前端换算为 bps |
| 执行模式 | 只读展示 | TopBar 已选 |

dry_run 模式下：日期区间隐藏，新增 `stake_amount` / `max_open_trades`（对应 `StartDryRunRequest`）。

`phase == .running` 时所有字段锁定。

### ② StatusPanel（回测运行状态 + 模拟运行状态）

两张并排窄卡：

- **回测卡**：当前选中 backtest_run 的 `status`（pending/running/completed/failed/error）+ 进度（command_status 轮询）+ `created_at` / `completed_at`。运行中每 2s 轮询 `GET /api/v2/backtest/status/{command_id}`。
- **模拟卡**：该策略最近一个 dry_run run 的状态。运行中轮询 `GET /api/v2/dryrun/status/{command_id}`。
- 失败时显示 `error_message` + 「查看日志」按钮（跳 `ExecutionRecordsView` 对应 run 详情）。
- 无数据时显示「尚无回测/模拟运行」空状态，不伪造状态。

dry_run 轮询到 `command_status == "running"` 即停止高频轮询、`phase = .completed`（含义为「dry_run 已启动并运行中」），模拟卡转为 30s 心跳刷新 `open_trades` / `total_profit`。

### ③ SummaryPanel（收益摘要 / 最大回撤 / 胜率 / 盈亏比）

四个主指标横向 4 等分，每卡只有 `指标名（小字灰）+ 数值（大字 mono）+ 一行上下文`：

| 指标 | 字段 | 上下文 |
|---|---|---|
| 收益 | `total_return` | vs 上次 run 差值 |
| 最大回撤 | `max_drawdown` | 始终红色 |
| 胜率 | `win_rate` | 样本数 = `total_trades` |
| 盈亏比 | `profit_factor` | 阈值提示（<1 红字） |

颜色：正向 `PulseColors.success`，负向 `PulseColors.danger`，零附近中性。无 emoji。

### ④ CurvePanel（equity curve + drawdown）

- **equity curve**：来自 `result.equity_curve`（后端 `FreqtradeBacktestRunner` 已解析，schema 需强类型化）。
- **drawdown**：客户端从 equity curve 计算 peak-to-trough，不请求后端。
- 用 Swift Charts（macOS 26 原生），不用手绘 `Path`。equity 面积线，drawdown 红色填充条形。
- 数据缺失时显示「本次运行未导出 equity curve 数据」+ 空图框架，绝不伪造。

### ⑤ TradeListPanel（trade list + run 内失败聚类）

- **trade list**：来自 `result.trades`。表格列：时间 / 交易对 / 方向 / 入场价 / 出场价 / 数量 / 盈亏 / 持仓时长 / MTF 状态。可排序、可按盈亏过滤。
- **run 内失败聚类**：纯客户端，对本次 run 的亏损 trades 按固定特征桶分组（持仓时长桶 / 入场时段桶 / 方向 / MTF 状态），展示 3-5 个簇 + 共性特征。亏损 trades < 5 时显示「亏损样本不足，无法聚类」。

### ⑥ ComparePanel（与历史 run 对比）

Run Rail 勾选 0-3 个历史 run 后自动展开：

- **指标矩阵**：行 = run，列 = return / sharpe / maxDD / winRate / PF / trades。最佳值高亮。
- **equity overlay**：所有选中 run 的 equity curve 叠加在同一张 Swift Charts 图，颜色区分。
- 数据全部来自各自 run 的 `result`，无合成。取消勾选即折叠。

### ⑦ RiskPanel（策略级失败聚类 + 风险警告）

- **策略级失败聚类**：`GET /api/growth/failure-clusters?strategy_uuid={uuid}`。展示簇标签 / 样本数 / 平均亏损 / 共性特征 / 「生成 shadow strategy」按钮（跳现有 shadow-strategy 流程）。
- **风险警告**：前端常量规则表，基于本次 run 指标自动生成纯文本警告条：

```
max_drawdown <= -0.25  → 红色「最大回撤超过 25%，风险过高」
total_trades < 30      → 黄色「样本不足，统计意义有限」
profit_factor < 1.0    → 红色「盈亏比 < 1，策略负期望」
win_rate < 0.35        → 黄色「胜率偏低」
sharpe_ratio < 0       → 黄色「夏普为负，风险调整收益为负」
```

多条命中按严重度排序，最多 5 条。

### ⑧ PromotionPanel（晋级实盘准入）

- 调用 `GET /api/v2/strategies/{id}/workspace` 取 `readiness` 字段（`LiveReadinessService.compute_for_strategy` 结果）。
- 展示 11 道闸门摘要（点名 + 通过/未通过/不适用），重点高亮 `backtest` 和 `dryrun` 两道（本页负责）。
- 顶部展示 `grand_status`（`not_live → needs_config → needs_validation → paper_passed → ready_for_live` 五档）。
- 底部主 CTA：
  - 未通过 → 「查看 Live Readiness 面板」（跳 `.liveReadiness`）。
  - 全通过且 `grand_status == "ready_for_live"` → 「前往启动 live_small」（跳 `.liveReadiness`，由那边调 `LiveSmallService`）。
- **不在本页直接启动实盘**，避免越权。

### ⑨ DataSourceFooter（数据源说明）

- 一行小字：`回测引擎：Freqtrade backtesting | 数据源：{exchange} OHLCV | 执行时间：{completed_at - created_at} | DSL hash：{dsl_hash}`。
- 点击展开 modal 展示 `config` 完整快照（来自 `BacktestRunResponse.config`）。

## 4. 后端改动

### 4.1 `StartBacktestRequest` 加 `slippage_bps`

`backend/app/schemas/backtest_v2.py`:

```python
class StartBacktestRequest(BaseModel):
    ...
    slippage_bps: Optional[float] = Field(default=None, ge=0, le=100)
```

`FreqtradeBacktestRunner` 在 `_build_config` 中应用：Freqtrade 无原生 slippage，用 fee 近似（`effective_fee = fee + slippage_bps / 10000`），并在 `data_source` 中记录 slippage 模型供前端 ⑨ 展示。

### 4.2 `BacktestRunResponse` 强类型化 `equity_curve` / `trades`

```python
class EquityPoint(BaseModel):
    timestamp: str
    equity: float
    drawdown: float = 0

class TradeRow(BaseModel):
    open_time: str
    close_time: str
    pair: str
    side: str
    open_price: float
    close_price: float
    quantity: float
    profit: float
    duration: str
    mtf_state: Optional[str] = None

class BacktestRunResponse(BaseModel):
    ...
    equity_curve: list[EquityPoint] = []
    trades: list[TradeRow] = []
    result: dict[str, Any] = {}  # 保留兼容
```

`BacktestRun` ORM 仍把完整结果存 `result` JSON；`BacktestRunResponse` 在序列化时从 `result` 提取并强类型化。

### 4.3 `failure-clusters` 接口支持 `strategy_uuid`

`backend/app/routers/growth.py` 现有 `GET /api/growth/failure-clusters` 加 `strategy_uuid: Optional[UUID] = None` 查询参数，过滤 `failure_clusters.strategy_id`（需 join `strategies` 表匹配 uuid）。若现有接口已按 `strategy_id` int 过滤，保留并新增 uuid 参数。

## 5. 数据流与轮询

### 进入页面 / 切换策略

一次 `GET /api/v2/strategies/{id}/workspace` 拿回 `WorkspaceSnapshotResponse`：
- `recent_backtests` → 填 Run Rail。
- `recent_dryruns` → 填 Run Rail dry_run 段。
- `readiness` → 填 ⑧。
- 策略版本 + DSL（`timeframe` / `symbols` 白名单）→ 填 ①。

### 选中 Run Rail 某 run

- 回测：`GET /api/v2/backtest/{backtest_id}` 拿完整 `BacktestRunResponse`（含 `result` / `equity_curve` / `trades`），填 ③④⑤。
- dry_run：`GET /api/v2/dryrun/{dryrun_id}`。

### 发起新 run

- 回测：`POST /api/v2/backtest` → `command_id` → `phase = .running`。
- dry_run：`POST /api/v2/dryrun` → 同上。

### 轮询策略

仅 `phase == .running` 时轮询，2s 间隔：

- 回测 `GET /api/v2/backtest/status/{command_id}`：
  - `command_status == "completed"` 且 `backtest_run.status == "completed"` → 停止，`phase = .completed`，拉完整 run。
  - `command_status in {"failed","error","cancelled"}` → 停止，`phase = .failed`。
  - 硬上限 15 分钟 → `phase = .failed` + 「运行超时」。
- dry_run `GET /api/v2/dryrun/status/{command_id}`：轮询到 `command_status == "running"` 即停止高频轮询、`phase = .completed`，模拟卡转 30s 心跳。

页面不可见时（`NSApplication.willResignActiveNotification`）暂停轮询，恢复时（`didBecomeActiveNotification`）继续。

### 对比数据流

Run Rail 勾选历史 run 时，对每个被勾选 run 调 `GET /api/v2/backtest/{id}`（主 run 不重复拉），缓存到 `comparedRuns`。取消勾选移除。⑥ 完全由缓存驱动。

### 失败聚类数据流

- run 内聚类（⑤）：纯客户端，无网络请求。
- 策略级聚类（⑦）：`GET /api/growth/failure-clusters?strategy_uuid={uuid}`，`phase == .completed` 时触发一次，缓存。

### 清理

切换策略时取消所有 in-flight `URLSessionTask` + 停止轮询 timer。`viewModel.onDisappear` 同样清理。

## 6. 错误处理与空状态

### 分层错误处理

- **网络层**：超时 > 30s → `NetworkError.timeout`；5xx → `NetworkError.serverError`。
- **ViewModel 层**：每个请求 catch 分两路：
  - 可恢复（timeout / 5xx / 网络中断）→ section 顶部 inline 错误条 + 「重试」按钮，不清空已有数据，不污染其他 section。
  - 不可恢复（4xx 业务错误）→ 弹 sheet 显示 `error_message` 全文。
- **运行失败**（`status == "failed"`）：② 红色状态条 + `error_message`；③-⑥ 隐藏；⑦ 显示「本次运行失败，无结果可分析」+ 跳转 ExecutionRecordsView；⑧ backtest 闸门显示「未通过 — 最近运行失败」。

### 空状态矩阵

| Section | 无数据场景 | 展示 |
|---|---|---|
| Run Rail | 该策略无历史 run | 空状态插画 + 「尚无运行记录，发起首次回测」 |
| ① ConfigPanel | 策略无 DSL | 禁用所有字段 + 「该策略版本无 DSL，无法回测」 |
| ② StatusPanel | 未发起 run | 两卡「待发起」灰阶 |
| ③ SummaryPanel | phase != .completed | 灰阶占位 + 「等待运行完成」 |
| ④ CurvePanel | result 无 equity_curve | 「本次运行未导出 equity curve」+ 空图 |
| ⑤ TradeListPanel | result 无 trades | 「本次运行无成交」 |
| ⑤ run 内聚类 | 亏损 trades < 5 | 「亏损样本不足，无法聚类」 |
| ⑥ ComparePanel | 未勾选历史 run | 折叠态 + 「在 Run Rail 勾选 run 启用对比」 |
| ⑦ 策略级聚类 | 无 failure_clusters | 「暂无策略级失败聚类记录」 |
| ⑧ PromotionPanel | readiness 接口失败 | 「准入评估暂不可用」+ 重试，不阻塞其他 section |
| ⑨ DataSourceFooter | run 未完成 | 隐藏 |

### Mock 模式透明化

- TopBar `MOCK` 徽章常驻。
- mock 模式下 `recent_backtests` / `recent_dryruns` 返回空数组（不是假数据）。mock factory 只用于「新建 run 后的本地回显」，不用于历史列表。
- 空状态文案改为「mock 模式不提供历史数据」。

### 不可变性约束

- ① 在 `phase == .running` 时锁定所有字段。
- 发起 run 按钮在 `phase == .running` 时禁用。
- Run Rail 历史 run 项不可删除（避免影响晋级评估的历史依据）。

## 7. 测试

### 后端测试（pytest）

- `tests/test_backtest_v2_api.py` — `slippage_bps` 字段校验（`ge=0, le=100`）+ runner 应用 slippage 单测。
- `tests/test_backtest_runner.py` — `BacktestResult.equity_curve` / `trades` 解析并写入 `BacktestRun.result`。
- `tests/test_failure_clusters_api.py` — `?strategy_uuid=` 过滤。
- `tests/test_backtest_schema.py` — `BacktestRunResponse.equity_curve` / `trades` 强类型字段序列化。

CI 门槛 `--cov-fail-under=30` 不变。

### 前端测试（XCTest）

- `BacktestLabViewModelTests` — phase 转换（idle→configuring→running→completed / →failed）；轮询启停；15 分钟超时。
- `BacktestLabViewModelTests` — network timeout inline 错误条 + 重试不清空已有数据。
- `RunInFailureClusteringTests` — 纯函数：trades 按特征桶分簇；亏损 < 5 返回空。
- `RiskWarningRulesTests` — 纯函数：metrics 命中正确警告条目与排序。
- `BacktestLabViewSnapshotTests` — 各 phase 快照（idle / running / completed / failed）。

## 8. 验收清单

### 链路完整性

- [ ] 选策略 → 填参数 → 发起回测 → ② 进度 → 完成后 ③-⑧ 依次亮起 → ⑧ 闸门状态。
- [ ] 发起 dry_run → ② 模拟卡运行中 → 30s 心跳刷新 `open_trades` / `total_profit`。
- [ ] 切换策略时所有 section 重置 + 取消 in-flight 请求 + 停止轮询。

### 数据真实性

- [ ] ④ equity curve 与后端 `result.equity_curve` 完全一致；断网时图不显示，不出现 PRNG 伪造。
- [ ] ⑤ trade list 行数 = `result.trades` 长度。
- [ ] ③ 四指标 = `BacktestRunResponse` 顶层字段，无客户端计算。
- [ ] mock 模式下 TopBar 显示 `MOCK` 徽章 + 历史列表为空。

### 失败路径

- [ ] 运行失败：② 显示 `error_message`，③-⑥ 隐藏，⑦ 失败提示，⑧ backtest 闸门未通过。
- [ ] 网络中断：对应 section inline 错误条 + 重试，其他 section 不受影响。
- [ ] 轮询超 15 分钟：`phase = .failed` + 「运行超时」。

### 对比

- [ ] Run Rail 勾选 2-3 个历史 run → ⑥ 展开 → 指标矩阵最佳值高亮 → equity overlay 多色叠加。
- [ ] 取消勾选 → ⑥ 折叠。

### 失败聚类

- [ ] ⑤ run 内聚类：亏损 trades ≥ 5 时展示 3-5 簇 + 共性特征。
- [ ] ⑦ 策略级聚类：展示 `failure_clusters` 记录 + 「生成 shadow strategy」跳转可用。

### 晋级链路

- [ ] ⑧ 展示 11 道闸门摘要 + `grand_status`。
- [ ] 未通过 CTA 跳 `.liveReadiness`；全通过 CTA 跳 `.liveReadiness`（由那边启动 live_small）。
- [ ] 本页不直接发起任何实盘启动请求。

### i18n

- [ ] 所有用户可见字符串走 `L10n.BacktestLab.*`，新增 key 入 `L10n+Backtest.swift`。
- [ ] 中英双语切换实时生效。

### 风险警告

- [ ] `max_drawdown <= -25%` 显示红色警告条。
- [ ] 多条命中按严重度排序，最多 5 条。

## 9. 文档更新

- 本 spec 提交到 `docs/superpowers/specs/2026-06-22-backtest-sim-refactor-design.md`，frontmatter `supersedes: 2026-06-17-strategy-workbench-canvas-first-design.md`。
- `docs/user-guide/content/{zh,en}/pages/strategy/backtest-simulation.html` 重写，对应新九段结构。
- `docs/README.md` 索引更新。
- `CLAUDE.md` macOS app 段：替换 `BacktestLabView` 描述（3-column → 叙事流）。
