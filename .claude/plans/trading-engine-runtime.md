# 交易引擎运行时层 — 实施计划

## Context

AlphaLoop 的核心基础设施（Command Bus Worker、Execution Ledger、Risk Engine、Freqtrade Adapter）已**完整实现**，包括：状态机、幂等性、FOR UPDATE SKIP LOCKED、event hash 去重、correlation/causation 链路、8 个命令处理器、全覆盖测试。

**缺失的是运行时编排层** — 把这些组件串联成一个持续运行的系统。当前 `main.py` 只启动了 ProviderHealthScheduler 和 BinanceTickerStream，没有启动 Command Worker 循环和交易同步。

---

## 实施顺序（6 项）

### Item 6: DeployRulesHandler 原子写入

**改动最小，零依赖，先做。**

**修改文件**: `backend/app/workers/deploy_rules_handler.py`

新增 `_atomic_write(path, content)` 工具函数：write tmp → fsync → `os.replace()`（POSIX 原子）。失败时清理 tmp。将两处 `write_text()` 替换为 `_atomic_write()`。

**测试**: `backend/tests/test_deploy_rules_handler.py` — 正常写入验证内容完整；模拟 `os.replace` 失败验证 tmp 清理。

---

### Item 5: Worker 中的 Reconciliation 阻塞

**修改文件**: `backend/app/workers/command_worker.py`

在 `acquire_next()` 中，获取命令锁后、改状态为 RUNNING 前，调用 `_is_blocked_by_reconciliation(cmd)`:
- `emergency_stop` 类型永远放行
- 其他类型检查 `cmd.aggregate_id` 对应的 FreqtradeRun 是否 status="reconciliating"
- 若被阻塞，不改状态直接返回 None（锁在事务结束后自动释放）

**测试**: 扩展 `backend/tests/test_command_worker.py` — 阻塞场景 + emergency_stop 放行场景。

---

### Item 1: 后台 Command Worker 循环

**新建文件**: `backend/app/workers/worker_loop.py`

`CommandWorkerLoop` 类，模式同已有的 `ProviderHealthScheduler`：
- `start()` → `asyncio.create_task(self._loop())`
- `_loop()` — 每 2s 调用一次 `_tick()`，每 60s 调用一次 `_recover_stale()`
- `_tick()` — 创建独立 DB session，实例化 `CommandWorker`，调 `poll_once()`，commit/rollback
- `stop()` — set Event，await task with timeout 10s
- 优雅关闭：当前正在执行的 handler 完成后才退出

**修改文件**: `backend/app/main.py` — lifespan 中 `await cmd_worker_loop.start()`，yield 后 `await cmd_worker_loop.stop()`

**修改文件**: `backend/app/config.py` — 新增 `command_worker_poll_interval_s=2.0`、`command_worker_stale_recovery_s=60.0`、`command_worker_enabled=True`

**测试**: `backend/tests/test_worker_loop.py` — tick 处理 pending 命令；stop event 终止循环；recover_stale 恢复超时命令。

---

### Item 2: 实时交易同步循环

**新建文件**: `backend/app/workers/trade_sync_loop.py`

`TradeSyncLoop` 类：
- 每 15s 查询所有 status in ("running", "degraded") 的 FreqtradeRun
- 对每个 run：
  1. `FreqtradeClient.ping()` — 成功更新 `last_heartbeat_at` + Redis heartbeat
  2. 超时 → status 改 "degraded"，写 `FREQTRADE_RUN_DEGRADED` ledger event
  3. 存活 → 调已有 `DryRunSyncService.sync_trades()` 同步交易到 Ledger
  4. 调 `StrategyPromotionService.promote_if_eligible()` 检查晋升（Item 4）

**修改文件**: `backend/app/main.py` — lifespan 中启动/停止

**修改文件**: `backend/app/config.py` — `trade_sync_interval_s=15.0`、`trade_sync_enabled=True`

**测试**: `backend/tests/test_trade_sync_loop.py` — mock FreqtradeClient；测试正常同步/降级转换/去重。

---

### Item 4: 策略自动晋升

**新建文件**: `backend/app/services/strategy_promotion_service.py`

`StrategyPromotionService`:
- `evaluate_promotion(strategy_run_id)` — 检查 4 个条件：
  1. dryrun 持续时间 >= 72h
  2. 无 circuit breaker 触发
  3. 总交易数 >= 5
  4. 胜率 >= 40%
- `promote_if_eligible()` — 评估 + 执行 `PAPER_RUNNING → PAPER_PASSED` 转换
- 使用已有 `validate_transition()` + `is_system_only()` 校验
- 写 `PULSEDESK_STRATEGY_PROMOTED` ledger event

**测试**: `backend/tests/test_strategy_promotion_service.py` — 满足/不满足各条件的场景。

---

### Item 3: TradeIntent → RiskDecision → 执行管道

**新建文件**: `backend/app/services/trade_intent_service.py`

`TradeIntentService.submit_intent()` 流程：
1. 创建 `TradeIntent` 记录 (status=CREATED) + 可选 `TradeIntentSignalSnapshot`
2. 调 `RiskEngine.four_layer_position_clip()` 评估仓位
3. 创建 `RiskDecision` 记录，更新 intent status=RISK_EVALUATED
4. 若 REJECT → intent.status=REJECTED，返回
5. 若 HUMAN_CONFIRM（live_small 模式）→ 等待人工确认，返回
6. 若 ALLOW → 创建 `ExecutionOrder`，通过 `FreqtradeClient` 下单，intent.status=SENT
7. 每步都写 Ledger event

**新建文件**: `backend/app/routers/trade_intents.py` — API 端点：
- `POST /api/v2/trade-intents` — 提交交易意图
- `GET /api/v2/trade-intents/{id}` — 查询状态
- `POST /api/v2/trade-intents/{id}/confirm` — 人工确认（live_small）

**修改文件**: `backend/app/main.py` — include router

**测试**: `backend/tests/test_trade_intent_service.py` — 完整流程（approve/reject/human_confirm）+ mock FreqtradeClient。

---

## 关键复用（不新建）

| 已有组件 | 位置 | 复用方式 |
|---------|------|----------|
| `CommandWorker.poll_once()` | `workers/command_worker.py` | Item 1 直接调用 |
| `DryRunSyncService.sync_trades()` | `services/dryrun_sync.py` | Item 2 定期调用 |
| `HeartbeatMonitor` | `services/heartbeat_monitor.py` | Item 2 记录心跳 |
| `RiskEngine.four_layer_position_clip()` | `services/risk_engine.py` | Item 3 仓位裁剪 |
| `validate_transition()` / `is_system_only()` | `services/strategy_transition.py` | Item 4 状态转换 |
| `ReconciliationService.is_reconciliating()` | `services/reconciliation_service.py` | Item 5 检查阻塞 |
| `FreqtradeClient` | `services/freqtrade_client.py` | Item 2/3 通信 |
| `LedgerRepository.compute_event_hash()` | `repositories/ledger_repository.py` | 所有 item 写 ledger |

---

## Config 变更汇总 (`backend/app/config.py`)

```python
command_worker_poll_interval_s: float = 2.0
command_worker_stale_recovery_s: float = 60.0
command_worker_enabled: bool = True
trade_sync_interval_s: float = 15.0
trade_sync_enabled: bool = True
trade_sync_heartbeat_stale_s: int = 30
```

---

## 验证步骤

1. `pytest backend/tests/ -v` — 所有现有 + 新增测试通过
2. `python3 backend/run.py` 启动后，日志显示 `Command worker loop started` + `Trade sync loop started`
3. 通过 API 提交 `start_backtest` 命令 → 2s 内 worker 消费 → ledger 写入事件
4. 创建 reconciliating 状态的 FreqtradeRun → 提交 deploy_rules → 被阻塞；提交 emergency_stop → 正常执行
5. `ls freqtrade/user_data/strategies/` — deploy 后无残留 `.tmp` 文件
6. SIGTERM 后进程在 10s 内干净退出，无挂起
