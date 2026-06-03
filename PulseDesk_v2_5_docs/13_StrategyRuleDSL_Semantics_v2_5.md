# PulseDesk v2.5 StrategyRuleDSL Semantics

> 本文定义 StrategyRuleDSL 的可执行语义。开发时不得只依据示例 JSON 推断行为，必须按本文实现 Validator、Interpreter 和 Golden Tests。

## 1. DSL 总体定位

StrategyRuleDSL 是 PulseDesk 唯一允许进入 Freqtrade 的策略表达格式。

```text
Manual Editor / Canvas / AI StrategyDraft
  → StrategyRuleDSL
  → DSL Validator
  → RulePackage
  → PulseDeskUniversalStrategy.py
```

禁止：

```text
生成 Python
嵌入任意表达式执行器
嵌入 eval / exec
动态 import 用户代码
在 DSL 中声明自定义 Python 函数
```

## 2. RulePackage 结构

```json
{
  "schema_version": "2.5",
  "strategy_version_id": "uuid",
  "dsl_hash": "sha256",
  "timeframe": "1h",
  "symbols": ["BTC/USDT"],
  "entry": {
    "logic": "AND",
    "rules": []
  },
  "exit": {
    "logic": "OR",
    "rules": []
  },
  "filters": [],
  "position_sizing": {},
  "risk": {},
  "metadata": {}
}
```

## 3. Evaluation Order

每根 K 线按以下顺序执行：

```text
1. Load last-known-good RulePackage from memory cache
2. Validate symbol / timeframe scope
3. Compute whitelisted indicators
4. Evaluate global filters
5. Evaluate entry rules
6. Evaluate exit rules
7. Apply position sizing
8. Apply Freqtrade hard risk config
9. Emit entry / exit columns for Freqtrade
```

### 3.1 Filter 优先级

`filters` 是前置门禁。任一 filter 判定为 reject，则本 candle 不允许 entry。

```text
filters = AND by default
entry = config.logic, default AND
exit = config.logic, default OR
```

## 4. Rule 类型白名单

第一阶段只允许：

```text
indicator_threshold
indicator_cross
signal_confirmation
manipulation_score_filter
volume_filter
volatility_filter
cooldown_filter
portfolio_exposure_filter
```

不允许：

```text
custom_python
raw_formula
webhook_runtime_code
llm_runtime_decision
arbitrary_sql
```

## 5. Indicator 白名单

第一阶段支持：

```text
rsi
ema
sma
macd
macd_signal
bb_upper
bb_lower
atr
volume
volume_sma
close
open
high
low
```

所有指标必须由 PulseDeskUniversalStrategy 内部固定实现或固定依赖库实现。

## 6. Operator 白名单

```text
>
>=
<
<=
==
!=
crosses_above
crosses_below
between
not_between
```

`between` 使用闭区间：

```text
min <= value <= max
```

## 7. Missing Data 行为

### 7.1 指标窗口不足

当指标窗口不足时：

```text
entry = false
exit = false
filter = reject
```

不得用 0、均值或上一根 K 线静默填充。

### 7.2 Signal 缺失

当 DSL 依赖 Signal，但当前 symbol / timeframe 没有 active signal：

```text
signal_confirmation = false
```

### 7.3 Manipulation Score 缺失

默认行为：

```text
reject entry
```

可通过 DSL 显式设置：

```json
{
  "missing_data_policy": "degrade_to_paper_only"
}
```

但 live_small 不允许因为缺失操控分而继续自动入场。

## 8. Multi-timeframe 语义

第一阶段只允许一个执行 timeframe。

可读取辅助 timeframe，但必须满足：

```text
辅助 timeframe 只用于 filter
不得在同一条 rule 中混用未对齐数据
必须使用 closed candle，不使用进行中 candle
```

## 9. Position Sizing

第一阶段只支持固定仓位百分比：

```json
{
  "type": "fixed_pct",
  "position_pct": 0.02
}
```

风控裁剪顺序：

```text
DSL position_pct
  → RiskPolicy max_position_pct_per_trade
  → CapitalPool remaining exposure
  → Freqtrade stake_amount / tradable_balance_ratio
```

最终仓位取最小值。

## 10. Risk Mapping to Freqtrade

DSL `risk` 必须映射到 Freqtrade config / Strategy attributes：

```text
stoploss
trailing_stop
trailing_stop_positive
trailing_stop_positive_offset
max_open_trades
cooldown
pair_lock
stake_amount / tradable_balance_ratio
```

live_small 必填：

```text
stoploss
max_open_trades
position_pct
capital_pool_id
human_confirmed=true
```

## 11. Safe Hold 行为

任何以下情况必须进入 safe hold：

```text
DSL validation failed
RulePackage hash mismatch
RulePackage schema_version unsupported
provider data stale
manipulation score missing in live_small
RiskPolicy missing
CapitalPool emergency_stop=true
Freqtrade run state=reconciliating
```

safe hold 的行为：

```text
不产生新 entry
允许 exit / stoploss / emergency close
记录 ExecutionLedger event
标记 StrategyRun degraded 或 manual_review_required
```

## 12. Validation Error Code

Validator 必须返回结构化错误：

```json
{
  "code": "DSL_UNSUPPORTED_OPERATOR",
  "path": "entry.rules[0].operator",
  "message": "operator is not allowed",
  "severity": "error"
}
```

常用错误码：

```text
DSL_SCHEMA_VERSION_UNSUPPORTED
DSL_MISSING_REQUIRED_FIELD
DSL_UNSUPPORTED_RULE_TYPE
DSL_UNSUPPORTED_INDICATOR
DSL_UNSUPPORTED_OPERATOR
DSL_INVALID_POSITION_PCT
DSL_RISK_FIELD_MISSING
DSL_SYMBOL_NOT_ALLOWED
DSL_TIMEFRAME_NOT_ALLOWED
DSL_MISSING_DATA_POLICY_INVALID
DSL_HASH_MISMATCH
```

## 13. Golden Tests

必须建设以下 Golden Tests：

```text
1. RSI < 30 produces entry=true when filter passes.
2. RSI missing produces entry=false.
3. manipulation_score missing rejects live_small entry.
4. entry AND requires all entry rules true.
5. exit OR triggers when any exit rule true.
6. invalid operator fails validation.
7. DSL hash mismatch fails deployment.
8. RiskPolicy max_position_pct clips DSL position_pct.
9. reconciliating state blocks new deployment.
10. safe hold emits ledger event.
```
