# Phase 02 — Freqtrade Adapter 工程落地计划

## 目标

PulseDesk 不重写交易引擎，而是管理 Freqtrade Docker，实现 StrategyRuleDSL RulePackage 发布、config 生成、backtest、dry-run、状态与订单同步。

## 周期

建议 1-2 周。

## 本阶段不做

- 不做 live trading；
- 不接真实 API Key；
- 不做复杂策略生成；
- 不做多交易所完整兼容。

## 支持范围

第一阶段只支持：

```text
market: crypto
exchange: binance 或 dry-run mock
mode: backtest / dry_run
strategy_template: RSI minimal
```

## 任务拆分

### T1. FreqtradeRun 模型

字段：

- id
- strategy_id
- strategy_version
- mode
- container_name
- config_path
- rules_path
- rule_package_hash
- fixed_strategy_template = PulseDeskUniversalStrategy.py
- status
- heartbeat_at
- last_error
- started_at
- stopped_at

验收：run 状态可记录、可查询、可更新。

### T2. StrategyRuleDSL RulePackage 发布器

先支持最小 RSI 策略：

- buy: RSI < 30；
- sell: RSI > 70；
- stoploss: -0.1；
- timeframe: 1h；
- minimal_roi 可配置。

验收：生成的文件能被 Freqtrade 加载。

### T3. config.json 生成器

必须包含：

- dry_run=true；
- exchange.name；
- pair_whitelist；
- stake_currency；
- stake_amount；
- timeframe；
- api_server 可选；
- strategy path。

验收：config 可用于 Freqtrade backtest/dry-run。

### T4. Docker Manager

能力：

- start container；
- stop container；
- inspect status；
- read logs；
- record heartbeat。

约束：UI 不直接操作 Docker。

### T5. Backtest Runner

能力：

- 运行 backtesting；
- 解析收益、回撤、交易次数、胜率；
- 保存 backtest report。

### T6. Dry-run Manager

能力：

- 启动 dry-run；
- 心跳检测；
- 状态同步；
- 订单同步；
- 失连降级。

## 状态机

```text
queued → config_generated → container_starting → running → degraded/stopped/failed/completed
```

## 验收标准

- 从一个 StrategyDraft 生成 StrategyRuleDSL，并通过 Validator 生成 RulePackage；
- 可触发 backtest 并读取结果；
- 可启动 dry-run 容器；
- dry-run 状态能在 UI 展示；
- 容器停止后状态变为 stopped；
- Freqtrade REST 失连后状态变为 degraded。

## 安全约束

- 禁止 live trading；
- 禁止保存真实 API Key 明文；
- Docker socket 只允许 backend 使用；
- 策略文件生成后必须先 validate/backtest；
- dry-run 不等于 backtest，状态必须独立。

---

# v2.2 补充：Freqtrade Adapter 必须改为 DSL + 双层风控

## 新增目标

Phase 02 不允许再实现开放式 Strategy.py 生成。必须实现固定模板 + JSON DSL。

## 新增任务

### 1. PulseDeskUniversalStrategy.py

创建固定 Freqtrade 策略模板：

```text
user_data/strategies/PulseDeskUniversalStrategy.py
```

要求：

- 只读取 `strategy_rules.json`；
- 根据 DSL 计算指标；
- 根据 DSL entry_rules/exit_rules 生成 entry/exit signals；
- 不允许动态执行 Python；
- 不允许联网请求；
- 不允许读取 API Key。

### 2. StrategyRuleDSL Validator

后端实现：

```text
strategy_center/strategy_rule_dsl.py
strategy_center/dsl_validator.py
strategy_center/dsl_compiler.py
```

要求：

- 指标白名单；
- 操作符白名单；
- 字段白名单；
- 类型校验；
- 风控字段必填；
- live 权限默认 false。

### 3. Freqtrade native risk config

生成 `config.json` 时必须写入：

- stoploss；
- max_open_trades；
- trailing_stop 配置；
- tradable_balance_ratio；
- dry_run 标识；
- stake / order_types 基础配置。

### 4. 失连状态机

实现：

```text
healthy
connection_lost
pulse_degraded
freqtrade_native_guard_only
reconciliating
failed
```

## 新增验收标准

- 不存在 LLM 直接写 Strategy.py 的路径；
- StrategyRuleDSL 能通过 API 校验；
- Freqtrade 能加载固定模板；
- backtest 能读取 DSL 规则运行；
- config 缺 stoploss 时拒绝运行；
- REST/WebSocket 失连时进入 degraded；
- 有持仓失连时进入 native guard only。

---

# v2.3.1 同步修订：Freqtrade Adapter 与云端 AI 的边界

## 变更原因

v2.3 引入云端 LLM 后，必须进一步收紧策略生成链路。云端模型质量更高，但也更容易让开发误以为可以直接生成 Freqtrade Strategy.py。这里必须明确：无论云端还是本地，LLM 都不得直接生成可执行 Python 策略文件。

## 强制架构

```text
Cloud LLM / Local LLM / Canvas / Signal Center
  ↓
StrategyDraft
  ↓
StrategyRuleDSL(JSON)
  ↓
DSL Validator
  ↓
PulseDeskUniversalStrategy.py 固定模板
  ↓
Freqtrade backtest / dry-run / live_small
```

## StrategyRuleDSL 示例

```json
{
  "schema_version": "1.0",
  "strategy_type": "bottom_accumulation",
  "symbol": "BTC/USDT",
  "timeframe": "1h",
  "entry_rules": [
    {
      "type": "indicator_threshold",
      "indicator": "rsi",
      "operator": "<",
      "value": 30
    }
  ],
  "filters": [
    {
      "type": "manipulation_score",
      "operator": "<",
      "value": 70
    }
  ],
  "risk": {
    "stoploss": -0.03,
    "trailing_stop": true,
    "max_open_trades": 2,
    "position_pct": 0.02
  }
}
```

## Freqtrade 原生硬风控要求

所有生成的 config / strategy 参数必须包含下层兜底：

- stoploss；
- trailing_stop 或明确禁用原因；
- max_open_trades；
- stake_amount / tradable_balance_ratio 限制；
- dry_run 默认 true；
- live_small 前必须人工确认。

## 后端新增任务

### T-dsl-1. StrategyRuleDSL Pydantic Schema

文件：

```text
backend/strategy_center/strategy_rule_dsl.py
```

要求：

- 严格枚举 rule type；
- 严格枚举 indicator；
- 禁止任意 Python 表达式；
- 禁止 eval / exec；
- 禁止 shell command；
- 禁止导入模块。

### T-dsl-2. UniversalStrategy 模板

文件：

```text
freqtrade/user_data/strategies/PulseDeskUniversalStrategy.py
```

要求：

- 固定 Python 文件；
- 从 JSON 规则读取参数；
- 不允许被 LLM 覆盖；
- 仅由开发者维护；
- 规则变更只修改 JSON，不修改 Python。

## 验收标准补充

- 云端 LLM 生成策略后，只产生 StrategyRuleDSL；
- 系统内不存在“LLM 生成 Strategy.py”入口；
- 无效 DSL 会被 validator 拒绝；
- Freqtrade 容器加载失败时，PulseDesk 显示具体错误并保持 degraded，不进入 dry-run；
- Freqtrade config 中必须有原生 stoploss / max_open_trades。

## 禁止事项

- 禁止把 LLM 输出保存为 `.py`；
- 禁止动态拼接 Python 函数；
- 禁止绕过 DSL Validator；
- 禁止只有 PulseDesk 风控而没有 Freqtrade 原生风控。


---

# v2.3.2 Addendum: UniversalStrategy Rule Loading Hardening

## Mandatory implementation change

`PulseDeskUniversalStrategy.py` must never call `json.load()` from `populate_indicators()`, `populate_entry_trend()`, or any hot-path dataframe calculation on every candle.

Rules must be loaded through:

```text
cached_rules + mtime/hash/version detector + last_known_good_rules fallback
```

## Required implementation tasks

1. Add `_rules_cache`, `_rules_mtime`, `_rules_hash`, `_rules_version`, `_rules_load_error` fields.
2. Add `_maybe_reload_rules()` method.
3. Call `_maybe_reload_rules()` only in `bot_loop_start()` or equivalent low-frequency lifecycle point.
4. Use atomic file replacement from PulseDesk side: write tmp → fsync → rename.
5. Keep previous valid rules if new rules fail JSON parsing or schema validation.
6. Add unit tests for corrupted JSON, version rollback, file missing, schema invalid, valid hot reload.

## Acceptance criteria

- Hot path dataframe functions do not perform direct disk reads.
- Freqtrade container does not crash when rule file is temporarily invalid.
- A valid rule change becomes active within one bot loop.
- Invalid rule change results in `safe_hold` or last known good behavior.

## v2.4 补充：Freqtrade Adapter 与 Command Bus

### 必做任务

1. 新增 Command Bus：

```text
command_bus_commands
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
StopDryRunCommand
RequestLiveSmallCommand
EmergencyStopCommand
```

2. 所有 Freqtrade 写操作必须经 Command Bus，不允许 API handler 直接调用 Docker。

3. 拆分运行实例：

```text
strategy_runs
freqtrade_runs
```

4. Freqtrade Adapter 执行命令后，必须写 `execution_ledger_events`。

5. `PulseDeskUniversalStrategy.py` 只能读取 StrategyRuleDSL，不接受 AI 生成 Python。

### 验收标准

```text
点击“运行回测”只创建 StartBacktestCommand。
后台 worker 消费命令并启动 Freqtrade。
命令有 idempotency_key，重复点击不会重复启动容器。
所有 Freqtrade 状态变化写 Execution Ledger。
```


---

## v2.5 收口说明

本文件中若仍存在与 `00_MASTER_ARCHITECTURE_DECISION_v2_5.md` 冲突的旧描述，以 v2.5 Master Architecture Decision 为准。特别是：禁止开放式 Strategy.py 生成；禁止 Canvas 生成 Python；Freqtrade 只加载固定 `PulseDeskUniversalStrategy.py` 并读取 StrategyRuleDSL RulePackage。

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。
