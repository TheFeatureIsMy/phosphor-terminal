# PulseDesk v2.5 Freqtrade Runtime Contract

## 1. Runtime 边界

PulseDesk 不重写交易执行引擎。Crypto 第一阶段执行由 Freqtrade 承担。

PulseDesk 负责：

```text
StrategyRuleDSL
DSL Validator
RulePackage 发布
RiskPolicy 门禁
Command Bus
Execution Ledger
Order Sync
Reconciliation
EmergencyStop
```

Freqtrade 负责：

```text
backtest
dry-run
live_small execution
exchange order placement via CCXT
strategy callback execution
```

## 2. 固定策略模板

Freqtrade 只加载：

```text
user_data/strategies/PulseDeskUniversalStrategy.py
```

该文件必须：

```text
读取 StrategyRuleDSL RulePackage
使用内存缓存和版本探测
在 bot_loop_start 或低频生命周期点 reload
禁止在 populate_indicators / populate_entry_trend 等热路径每根 K 线 json.load
禁止 eval / exec
禁止动态 import 用户代码
```

## 3. RulePackage 部署

部署流程：

```text
StrategyVersion validated
  → RiskPolicy deployment check
  → DeployRulesCommand
  → write versioned strategy_rules.json
  → write checksum / manifest
  → Freqtrade run reads last-known-good package
```

必须包含 manifest：

```json
{
  "strategy_version_id": "uuid",
  "dsl_hash": "sha256",
  "rule_package_version": "2.5",
  "created_at": "iso8601",
  "validator_version": "2.5"
}
```

## 4. Risk Engine 与 Freqtrade 的真实边界

不要假设 PulseDesk 可以在 Freqtrade 每笔订单前同步审批。

v2.5 正确边界：

```text
部署前：RiskEngine 审批 StrategyRuleDSL + RiskPolicy + CapitalPool
运行中：UniversalStrategy 内置硬门禁 + Freqtrade 原生风控
执行后：ExecutionLedger + Reconciliation + EmergencyStop
```

## 5. Freqtrade Config 必填硬风控

所有 backtest / dry-run / live_small config 必须包含：

```text
stoploss
max_open_trades
stake_amount 或 tradable_balance_ratio
cooldown / pair lock
pairlist allowlist
dry_run 明确值
exchange API permission mode
```

live_small 额外要求：

```text
human_confirmed=true
capital_pool_id
max_position_pct_per_trade
max_total_exposure_pct
max_daily_loss_pct
emergency_stop_enabled=true
```

## 6. 状态模型

```text
created
starting
running
degraded
reconciliating
manual_review_required
stopping
stopped
failed
```

`reconciliating` 是阻塞态。该状态下：

```text
禁止部署新规则
禁止启动新 dry-run
禁止 RequestLiveSmall
允许 EmergencyStop
允许 StartReconciliation
```

## 7. Order Sync

订单同步优先级：

```text
1. Freqtrade REST / WebSocket
2. Freqtrade DB read-only sync
3. Exchange AccountDataAdapter read-only reconciliation
```

同步结果写入：

```text
execution_ledger_events
execution_orders
execution_trades
execution_positions
```

不得只更新 UI 状态。

## 8. EmergencyStop

EmergencyStopCommand 必须：

```text
锁定 strategy_run
阻止新 entry
调用 Freqtrade stop / force exit 机制，具体能力按 Freqtrade 支持实现
写 ExecutionLedger
进入 manual_review_required 或 stopped
```
