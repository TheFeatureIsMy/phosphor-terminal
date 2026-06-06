# PulseDesk v2.5 开发计划（最小闭环优先）

> 目标：尽快达成 StrategyRuleDSL → Validator → Command Bus → Freqtrade backtest/dry-run → Execution Ledger 完整闭环。
> 禁止提前实现：AI Research、复杂 Canvas、Growth Engine、live trading、macOS UI。

---

## Phase 00：工程骨架 + 数据库基础

### 目标

搭建 v2.5 工程基础设施。PostgreSQL 替换 SQLite，建立全部核心表，清理旧代码冲突。

### 输入文档

- `00_MASTER_ARCHITECTURE_DECISION_v2_5.md`
- `10_Database_ERD_v2_5.md`
- `14_Command_Bus_Worker_Contract_v2_5.md`
- `15_Execution_Ledger_Contract_v2_5.md`

### 允许实现

1. PostgreSQL 配置（database.py、config.py、.env、docker-compose.yml）
2. Alembic migration 初始化
3. 建表（一次性建齐核心表，避免后续反复迁移）：
   - signal_identity
   - signals（分区表）
   - signal_payloads
   - signal_evidence
   - signal_lifecycle_events
   - signal_snapshots
   - provider_traces
   - strategies
   - strategy_versions
   - strategy_rule_dsl_versions
   - risk_policies
   - risk_policy_versions
   - capital_pools
   - strategy_risk_policy_bindings
   - strategy_runs
   - freqtrade_runs
   - command_bus_commands
   - execution_ledger_events（分区表）
   - execution_orders
   - execution_trades
   - execution_positions
   - order_fills
   - outbox_events
4. SQLAlchemy v2.5 ORM 模型（UUID 主键）
5. 清理旧模型冲突标记（CanvasWorkflow.code_snapshot、Strategy.freqtrade_strategy_id 等）
6. 更新 CLAUDE.md 写入 v2.5 约束

### 禁止实现

- 禁止实现业务逻辑
- 禁止新建 API 端点
- 禁止新建前端页面

### 修改目录

```
backend/app/database.py
backend/app/config.py
backend/app/models/          — 重写全部 ORM 模型
backend/migrations/          — Alembic 初始化 + 初始迁移
docker-compose.yml
.env / .env.example
CLAUDE.md
```

### 交付物

- PostgreSQL 连接 + docker-compose 服务
- 23 张核心表（含分区表、索引）
- 全部 SQLAlchemy ORM 模型
- Alembic 初始迁移脚本
- 旧模型冲突清理

### 验收标准

- `docker compose up` 启动 PostgreSQL 成功
- `alembic upgrade head` 建表成功
- 全文搜索 `strategy_file_path`，仅存在废弃标记
- 全文搜索 `code_snapshot`，不存在有效实现
- 所有表 UUID 主键、TIMESTAMPTZ 时间字段
- signals / execution_ledger_events 分区表可创建当月分区

---

## Phase 01：Signal Center 后端 + StrategyRuleDSL + Validator

### 目标

实现 Signal Center 服务层和 StrategyRuleDSL 完整校验链。这两个是 Phase 02 闭环的前置依赖。

### 输入文档

- `11_Module_Boundaries_v2_4.md`（§2.1 Signal Center、§2.2 Strategy Center）
- `13_StrategyRuleDSL_Semantics_v2_5.md`
- `phases/Phase_01_Signal_Center.md`

### 允许实现

**Signal Center 服务**：

- SignalRepository（统一查询接口，冷归档 fallback 接口骨架）
- Signal CRUD 服务（创建、查询列表、查询详情、状态流转、归档）
- Signal 生命周期管理（状态变更写 lifecycle_events）
- Signal 列表轻量化（列表不返回 payload 大文本）
- Pydantic Schemas：SignalCreate / SignalView / SignalSummary / SignalPayload / SignalEvidence / ProviderTrace

**Signal Center API**：

- `POST   /api/v2/signals`
- `GET    /api/v2/signals`
- `GET    /api/v2/signals/{id}`
- `POST   /api/v2/signals/{id}/transition`
- `POST   /api/v2/signals/{id}/archive`

**StrategyRuleDSL 核心**：

- DSL JSON Schema 定义（schema_version 2.5）
- Pydantic Validator
  - Rule type 白名单（8 种）
  - Indicator 白名单（14 种）
  - Operator 白名单（10 种）
- DSL Interpreter（规则求值引擎，针对 DataFrame 逐行求值）
- RulePackage manifest 生成（含 dsl_hash sha256）
- Missing Data 行为（指标窗口不足→false、Signal缺失→false、manipulation_score缺失→reject）
- Safe Hold 触发条件定义
- Validation Error Code 结构化输出（12 个错误码）

**Strategy 服务**：

- Strategy / StrategyVersion CRUD
- StrategyVersion 状态机（draft → validated → backtested → paper_running → paper_passed）
- DSL 版本管理（strategy_rule_dsl_versions 写入）

**Strategy API**：

- `POST   /api/v2/strategies`
- `GET    /api/v2/strategies`
- `POST   /api/v2/strategies/{id}/versions`
- `GET    /api/v2/strategies/{id}/versions/{vid}`
- `POST   /api/v2/strategies/{id}/versions/{vid}/validate`

**Golden Tests（10 个）**：

1. RSI < 30 → entry=true（filter 通过时）
2. RSI missing → entry=false
3. manipulation_score missing → reject live_small entry
4. entry AND → 全部 rule 为 true 才入场
5. exit OR → 任一 rule 为 true 即出场
6. invalid operator → validation 失败
7. DSL hash mismatch → deployment 失败
8. RiskPolicy max_position_pct 裁剪 DSL position_pct
9. reconciliating 状态阻塞新部署
10. safe hold 写 ledger event

### 禁止实现

- 禁止生成开放式 Strategy.py
- 禁止 eval / exec / 动态 import
- 禁止实现 Canvas 编辑器
- 禁止实现 AI 策略草稿生成
- 禁止实现 Freqtrade 容器管理
- 禁止实现 backtest / dry-run 执行
- 禁止实现 Signal Center UI
- 禁止 Signal Center 创建 TradeIntent

### 修改目录

```
backend/app/schemas/         — Signal / Strategy / DSL schemas
backend/app/services/        — signal_repository.py, dsl_validator.py, dsl_interpreter.py, strategy_service.py
backend/app/routers/         — signals_v2.py, strategies_v2.py
tests/                       — Signal 测试 + 10 个 Golden Tests
```

### 交付物

- SignalRepository 服务
- Signal CRUD API（5 端点）
- DSL JSON Schema + Pydantic Validator + Interpreter
- RulePackage manifest 生成器
- Strategy CRUD API（5 端点）
- 10 个 Golden Tests
- Validation Error Code 结构化输出

### 验收标准

- Signal 列表不扫描 signal_payloads
- 所有 Signal 状态变更写 lifecycle_events
- 无过滤全表查询被拒绝
- 非法 operator 被 Validator 拒绝
- missing data 进入 safe hold（不静默填充）
- 不存在生成开放式 Strategy.py 的路径
- StrategyDraft 不可直接执行
- StrategyVersion validated 后状态正确流转
- 10 个 Golden Tests 全部通过
- `pytest tests/ -q` 全部通过

---

## Phase 02：Command Bus + Execution Ledger + Freqtrade Adapter（最小闭环）

### 目标

打通完整闭环：创建策略 → 校验 DSL → 提交 Command → Worker 消费 → Freqtrade 容器运行 backtest/dry-run → 结果写 Execution Ledger。

### 输入文档

- `14_Command_Bus_Worker_Contract_v2_5.md`
- `15_Execution_Ledger_Contract_v2_5.md`
- `16_Freqtrade_Runtime_Contract_v2_5.md`
- `11_Module_Boundaries_v2_4.md`（§2.3 Freqtrade Adapter）
- `phases/Phase_02_Freqtrade_Adapter.md`

### 允许实现

**PulseDeskUniversalStrategy.py（固定模板）**：

- 内存缓存 `_rules_cache` + mtime/hash 版本探测
- `bot_loop_start()` 低频 reload
- last-known-good fallback
- 白名单指标计算（14 种）
- entry/exit/filter 规则求值
- 禁止 eval/exec/动态 import

**Command Bus Worker**：

- `FOR UPDATE SKIP LOCKED` 锁获取
- 幂等语义（idempotency_key 唯一约束）
- 状态机（pending → running → succeeded/failed/retry_waiting/timeout/cancelled）
- 命令处理器：
  - DeployRulesCommand — 发布 RulePackage（原子文件替换：tmp → fsync → rename）
  - StartBacktestCommand — 启动 backtest 容器
  - StartDryRunCommand — 启动 dry-run 容器
  - StopDryRunCommand — 停止 dry-run
  - EmergencyStopCommand — 紧急停止（骨架）
- 重试机制（retry_count / max_retries / next_retry_at）
- 超时检测（locked_at 超时释放）
- Reconciliation blocking（reconciliating 时只允许 EmergencyStop）
- 每个命令写 2 个 Ledger 事件（STARTED + SUCCEEDED/FAILED）

**Execution Ledger 服务**：

- append-only 写入（禁止 update/delete）
- event_hash 幂等去重（sha256）
- correlation_id / causation_id 链路追踪
- Freqtrade 事件写入（RUN_STARTED / ORDER_OPENED / ORDER_FILLED / TRADE_CLOSED 等）
- PulseDesk 事件写入（COMMAND_STARTED / COMMAND_SUCCEEDED / COMMAND_FAILED 等）
- 物化到 execution_orders / execution_trades / execution_positions

**Freqtrade Adapter**：

- Docker 容器管理（start / stop / inspect / logs / heartbeat）
- config.json 生成器（必含 stoploss / max_open_trades / stake_amount / dry_run）
- RulePackage 原子发布
- Backtest Runner（运行回测、解析结果、写 Ledger）
- Dry-run Manager（启动、心跳检测、状态同步、基础订单同步、失连降级）
- FreqtradeRun 状态机（created → starting → running → degraded → stopping → stopped → failed）
- 基础 Order Sync（Freqtrade REST/DB → ledger → materialized tables）

**后端 API**：

- `POST   /api/v2/commands` — 提交命令
- `GET    /api/v2/commands/{id}` — 查询命令状态
- `GET    /api/v2/strategy-runs` — 运行实例列表
- `GET    /api/v2/strategy-runs/{id}` — 运行详情
- `GET    /api/v2/strategy-runs/{id}/orders` — 订单列表
- `GET    /api/v2/strategy-runs/{id}/ledger` — Ledger 事件
- `POST   /api/v2/strategies/{id}/versions/{vid}/backtest` — 快捷回测入口
- `POST   /api/v2/strategies/{id}/versions/{vid}/dryrun` — 快捷 dry-run 入口

### 禁止实现

- 禁止 UI / AI 直接操作 Docker
- 禁止加载 AI 生成的 Strategy.py
- 禁止 Execution Ledger update / delete
- 禁止实现 live_small / live trading（不实现 RequestLiveSmallCommand）
- 禁止实现 Reconciliation 完整流程（只建骨架状态）
- 禁止实现 Exchange API 直连
- 禁止实现 WebSocket 推送
- 禁止实现前端 UI

### 修改目录

```
backend/app/services/        — command_bus_worker.py, execution_ledger.py, freqtrade_adapter.py, docker_manager.py, config_generator.py
backend/app/routers/         — commands_v2.py, runs_v2.py, 扩展 strategies_v2.py
freqtrade/user_data/strategies/PulseDeskUniversalStrategy.py
freqtrade/                   — config 模板目录
docker-compose.yml           — 加入 Freqtrade 服务
tests/                       — 命令幂等、Worker、Ledger、闭环集成测试
```

### 交付物

- PulseDeskUniversalStrategy.py 固定模板
- Command Bus Worker（5 个命令处理器）
- Execution Ledger append-only 服务
- Freqtrade Docker 管理器
- config.json 生成器
- Backtest Runner + Dry-run Manager
- RulePackage 原子发布器
- 8 个 API 端点
- 闭环集成测试

### 验收标准

- **最小闭环可跑通**：创建策略 → 校验 DSL → 提交 StartBacktestCommand → Worker 消费 → 容器运行 → 结果写 Ledger → API 可查
- 命令 idempotency_key 唯一，重复提交不重复启动容器
- Worker 崩溃后命令可恢复（locked_at 超时释放）
- 每次 backtest / dry-run 都有 StrategyRun + FreqtradeRun + Ledger events
- Ledger 只有 INSERT，无 UPDATE/DELETE
- Ledger 事件含 correlation_id 可追踪完整链路
- config 缺 stoploss 时拒绝运行
- Freqtrade REST 失连后状态变为 degraded
- PulseDeskUniversalStrategy.py 热路径不重复读 JSON
- 损坏 JSON 不导致 Freqtrade 崩溃（last-known-good fallback）
- reconciliating 状态下 DeployRules / StartBacktest 被拒绝
- `pytest tests/ -q` 全部通过

---

## Phase 03：Risk Engine（部署前风控）

### 目标

实现三层风控的第一层：策略部署前风控检查。所有 backtest / dry-run 启动前必须经过风控校验。

### 输入文档

- `00_MASTER_ARCHITECTURE_DECISION_v2_5.md`（ADR-004）
- `11_Module_Boundaries_v2_4.md`（§2.4 Risk Engine）
- `13_StrategyRuleDSL_Semantics_v2_5.md`（§9 Position Sizing、§10 Risk Mapping）
- `16_Freqtrade_Runtime_Contract_v2_5.md`（§4-5）

### 允许实现

- 部署前风控检查服务（RiskPolicy + CapitalPool + Pairlist 校验）
- RiskDecision 输出（ALLOW / REDUCE_SIZE / REJECT / PAPER_ONLY / DEPLOYMENT_APPROVED / DEPLOYMENT_REJECTED）
- Position Sizing 四层裁剪链（DSL → RiskPolicy → CapitalPool → Freqtrade config，取最小值）
- Risk Mapping → Freqtrade config 字段
- 风控决策写 execution_ledger_events
- 将风控检查嵌入 Phase 02 的 Command 处理器（DeployRules / StartBacktest / StartDryRun 前置检查）
- risk_decisions API 查询
- capital_pools CRUD API

### 禁止实现

- 禁止实现 live_small 风控通道
- 禁止 Risk Engine 操作 Docker
- 禁止 Risk Engine 修改 strategy_versions
- 禁止实现 TradeIntent 完整流程
- 禁止实现 feature_snapshots 采集
- 禁止实现 Risk Engine UI

### 修改目录

```
backend/app/services/        — risk_engine.py
backend/app/services/        — 扩展 command_bus_worker.py（嵌入风控前置检查）
backend/app/routers/         — risk_v2.py
tests/                       — 风控裁剪链、部署拒绝测试
```

### 交付物

- Risk Engine 部署前风控服务
- Position Sizing 四层裁剪链
- RiskDecision 审计写入 Ledger
- 风控嵌入 Command 处理器
- risk_decisions / capital_pools API

### 验收标准

- RiskPolicy 缺失时 dry-run 部署被拒绝
- CapitalPool 超限时 RiskDecision = REDUCE_SIZE 或 REJECT
- Position Sizing 取四层裁剪链最小值
- Freqtrade config 必含 stoploss / max_open_trades
- RiskDecision 写入 execution_ledger_events
- `pytest tests/ -q` 全部通过

---

## Phase 04+：后续阶段（当前不实现，仅列出顺序）

以下阶段在 Phase 00-03 完成并验收后，按顺序推进：

| 顺序 | 名称 | 前置依赖 |
|------|------|----------|
| 04 | Strategy Workspace + Signal Center macOS UI | Phase 03 |
| 05 | Canvas WebView Editor（React Flow 6 类节点） | Phase 04 |
| 06 | AI Research / Agent Platform（LLMRouter） | Phase 04 |
| 07 | Manipulation Radar（manipulation_score） | Phase 03 |
| 08 | Growth Engine（订单归因） | Phase 03 + 07 |
| 09 | Live Small Safety（人工确认 + EmergencyStop + Reconciliation） | Phase 03 + 07 + 08 |

每个后续阶段的详细计划在进入该阶段时再制定，避免过早设计。

---

## 依赖关系

```
Phase 00 (骨架+建表)
   │
   ▼
Phase 01 (Signal Center + DSL Validator)
   │
   ▼
Phase 02 (Command Bus + Ledger + Freqtrade Adapter) ← 最小闭环达成
   │
   ▼
Phase 03 (Risk Engine 嵌入)
   │
   ├──→ Phase 04 (UI)
   │       ├──→ Phase 05 (Canvas)
   │       └──→ Phase 06 (AI Research)
   ├──→ Phase 07 (Manipulation Radar)
   │
   └──→ Phase 08 (Growth Engine)
               │
               ▼
          Phase 09 (Live Small Safety)
```

---

## 全局约束

1. v2.5 是唯一有效架构版本
2. 禁止实现开放式 Strategy.py 生成器
3. 禁止 AI 直接生成可执行 Python 策略代码
4. 策略只能通过 StrategyRuleDSL JSON → Validator → PulseDeskUniversalStrategy.py 执行
5. Canvas 只是 DSL 可视化编辑器，不是执行引擎
6. RiskEngine 是交易权限门禁
7. Freqtrade 是执行底座，不是业务中枢
8. 所有异步执行任务必须通过 Command Bus
9. 所有执行事实必须写入 Execution Ledger
10. 当前阶段禁止实现 AI Research、复杂 Canvas、Growth Engine、live trading
