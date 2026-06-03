# 09. Code Implementation Hardening v2.3.2

> 本文件是 PulseDesk v2.3.2 的工程实现前置加固说明。它处理 3 个在真实代码实现中容易被忽略、但会直接影响稳定性、归因完整性与实盘安全的暗坑。

---

## 1. UniversalStrategy 读取 StrategyRuleDSL 的同步 I/O 风险

### 1.1 问题

PulseDesk v2.2 / v2.3 已禁止 AI 或画布动态生成 `Strategy.py`，改为：

```text
StrategyDraft / Canvas / AI
  → StrategyRuleDSL(JSON)
  → DSL Validator
  → PulseDeskUniversalStrategy.py 固定模板
  → Freqtrade
```

但如果 `PulseDeskUniversalStrategy.py` 在 `populate_indicators()`、`populate_entry_trend()` 或其他高频回调中每次都 `json.load()` 读取规则文件，将带来：

- 同步磁盘 I/O 卡顿；
- 高频回测速度下降；
- dry-run / live bot loop 被不必要地阻塞；
- 写入规则文件时出现半写状态读取；
- 并发读写锁争用。

### 1.2 强制原则

`PulseDeskUniversalStrategy.py` 必须采用 **内存缓存 + 版本探测**，不得在每根 K 线或每次指标计算时反复读盘。

### 1.3 推荐实现

规则文件路径：

```text
/user_data/pulsedesk/strategy_rules/{strategy_id}.json
```

规则热加载只允许发生在：

1. `bot_loop_start()`；
2. 策略实例初始化；
3. 回测模式下每个 candle loop 的轻量检查；
4. 人工触发 reload 时。

推荐策略类内部维护：

```python
self._rules_cache: dict | None
self._rules_mtime: float | None
self._rules_hash: str | None
self._rules_version: int | None
self._rules_load_error: str | None
```

### 1.4 文件更新协议

PulseDesk 写规则文件时必须使用原子替换：

```text
write strategy_rules.tmp
fsync
rename strategy_rules.tmp → strategy_rules.json
```

禁止直接覆盖写 `strategy_rules.json`。

### 1.5 失败行为

| 场景 | 行为 |
|---|---|
| JSON parse failed | 继续使用上一份 valid cache |
| schema validation failed | 继续使用上一份 valid cache |
| 文件不存在 | 策略进入 safe hold，不开新仓 |
| version 回退 | 拒绝加载，记录 warning |
| hash 未变化 | 不重新解析 |

### 1.6 验收标准

- `populate_indicators()` 不直接调用 `open()` / `json.load()`；
- `bot_loop_start()` 中最多每轮检查一次 mtime；
- 规则文件损坏时不导致 Freqtrade 容器崩溃；
- 规则热更新后 1 个 bot loop 内生效；
- 回测 1000 根 K 线时规则读取次数明显低于 K 线数量；
- 单元测试覆盖：有效更新、损坏 JSON、schema 错误、文件缺失、版本回退。

---

## 2. Signal 分区归档后的证据链断裂风险

### 2.1 问题

`trade_intents.source_signal_ids` 记录触发交易的源 Signal。如果 Signal 表采用月度分区，并由 Data Vacuum 将过期 Signal 迁移到 SQLite / Parquet 冷存档，则主库中可能无法再直接查到旧 Signal。

这会导致：

- 历史交易归因无法还原当时的 reasoning；
- Growth Engine 无法跨月分析信号有效性；
- 订单证据链断裂；
- `source_signal_ids` 变成死链。

### 2.2 强制原则

PulseDesk 必须引入 **Data Federation Layer**，对上层隐藏冷热存储差异。

所有查询信号证据链的代码禁止直接查 `signals` 表，必须通过：

```python
SignalRepository.get_signal(signal_id)
SignalRepository.get_signals(signal_ids)
SignalRepository.get_signal_evidence(signal_id)
```

### 2.3 查询顺序

```text
Redis latest cache
  ↓ miss
PostgreSQL hot partitions
  ↓ miss
SQLite cold archive
  ↓ miss
Parquet cold archive index
  ↓ miss
return tombstone record
```

### 2.4 迁移前快照

在 Signal 被归档或清理前，如果它已被任何 `trade_intents` / `orders` / `strategy_candidates` 引用，必须生成不可变快照：

```json
{
  "signal_id": "sig_xxx",
  "source_type": "tradingagents",
  "symbol": "BTC/USDT",
  "direction": "long",
  "confidence": 0.72,
  "reasoning_snapshot": "...",
  "evidence_snapshot": [...],
  "provider_trace_snapshot": {...},
  "archived_at": "...",
  "archive_uri": "sqlite:///archives/signals_2026_06.db"
}
```

### 2.5 数据表要求

新增：

```text
signal_archive_index
signal_reference_snapshots
```

`signal_archive_index` 字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| signal_id | UUID | 原 Signal ID |
| archive_type | text | sqlite / parquet |
| archive_uri | text | 冷存档位置 |
| partition_month | text | yyyy_mm |
| archived_at | timestamptz | 归档时间 |
| checksum | text | 完整性校验 |

`signal_reference_snapshots` 字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| reference_type | text | trade_intent / order / candidate |
| reference_id | UUID | 引用对象 ID |
| signal_id | UUID | Signal ID |
| snapshot_json | JSONB | 最小证据快照 |
| created_at | timestamptz | 创建时间 |

### 2.6 验收标准

- 删除或归档旧 Signal 后，执行记录仍可展示来源 Signal；
- Growth Engine 可跨 6 个月反查 Signal reasoning；
- 归档任务不会物理删除仍被引用但未快照的 Signal；
- `trade_intents.source_signal_ids` 不直接作为唯一查询方式，必须经 Repository；
- 冷库缺失时返回 tombstone record，而不是抛异常。

---

## 3. Reconciliating 状态机的原子对账要求

### 3.1 问题

PulseDesk 与 Freqtrade 失连后，Freqtrade 仍可能独立触发：

- stoploss；
- trailing stop；
- force exit；
- open order cancel；
- partial fill；
- entry / exit fill。

如果恢复连接后，PulseDesk 基于旧本地状态继续下发 TradeIntent，会造成：

- 本地持仓与真实持仓不一致；
- 重复开仓；
- 错误补仓；
- 错误平仓；
- Growth Engine 记录脏数据。

### 3.2 强制原则

`reconciliating` 状态下，PulseDesk 必须进入 **只读对账模式**。

禁止：

- 下发新 TradeIntent；
- deploy strategy；
- live_small upgrade；
- 修改 Freqtrade config；
- 启动新 dry-run / live run。

允许：

- 拉取 Freqtrade status；
- 拉取 open trades / closed trades / orders；
- 同步 balances / positions；
- 修正本地数据库；
- 记录 reconciliation event。

### 3.3 真理源规则

在 reconciliation 期间：

```text
Freqtrade / Exchange state > PulseDesk local DB state > UI cache
```

PulseDesk 本地状态必须被 Freqtrade 当前真实状态覆盖，不允许反向覆盖。

### 3.4 对账流程

```text
1. acquire reconciliation lock
2. set system_state = reconciliating
3. block outbound TradeIntent queue
4. fetch Freqtrade status
5. fetch open trades
6. fetch recent closed trades since last_seen_trade_id / timestamp
7. fetch recent orders since last_seen_order_id / timestamp
8. fetch balances / positions when supported
9. compare local orders / positions / trade count
10. insert missing orders
11. update changed orders
12. mark locally-open but remotely-closed trades as closed_by_freqtrade_native_guard
13. recompute portfolio exposure
14. run post-reconciliation risk scan
15. release outbound queue only if no critical mismatch
16. set system_state = healthy or degraded_manual_review_required
```

### 3.5 状态转换

```text
healthy
  ↓ heartbeat missed
pulse_degraded
  ↓ REST unavailable but Freqtrade process alive
freqtrade_native_guard_only
  ↓ REST restored
reconciliating
  ↓ all checks passed
healthy
  ↓ mismatch unresolved
manual_review_required
```

### 3.6 API 行为

| API | reconciliating 行为 |
|---|---|
| POST /trade-intents | 409 SYSTEM_RECONCILING |
| POST /strategies/deploy | 409 SYSTEM_RECONCILING |
| POST /freqtrade/start-live | 409 SYSTEM_RECONCILING |
| GET /positions | 返回 `stale=true` |
| GET /orders | 返回 `sync_state=reconciliating` |
| POST /risk/emergency-stop | 允许，但仅调用 Freqtrade native / exchange emergency path |

### 3.7 验收标准

- 断线期间 Freqtrade 平仓，恢复后 PulseDesk 能识别并更新本地订单；
- reconciliating 状态下所有新 TradeIntent 被阻塞；
- 对账未完成时 UI 明确显示“状态恢复中，禁止新交易”；
- 未解决差异时系统进入 `manual_review_required`，不得自动 healthy；
- 对账流程有幂等性，重复执行不会重复写订单。
