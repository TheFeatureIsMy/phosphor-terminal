# Phase 06 — Growth Engine 自我成长系统

## 目标

根据历史订单、策略执行结果、Signal 表现、Agent 表现和 SHAP 归因，总结高胜率策略、低胜率过滤条件，并生成候选策略。

## 范围

### 本阶段做

- 同步历史订单
- Entry Feature Snapshot
- Win/Loss 标签
- SHAP 特征归因
- 盈利订单共性挖掘
- 亏损订单共性挖掘
- Signal 有效性分析
- Agent 表现分析
- Candidate Strategy 生成
- 自动回测候选策略

### 本阶段不做

- 自动替换 live 策略
- 自动提升仓位
- 自动关闭风控
- 自动 live

## 数据要求

每笔订单必须保存入场时特征：

```json
{
  "rsi": 28.4,
  "macd_hist": -0.02,
  "price_percentile_90d": 0.08,
  "sideways_days": 18,
  "volume_zscore": 2.1,
  "funding_rate": 0.001,
  "oi_change_pct": 0.12,
  "sentiment_score": 0.34,
  "whale_exchange_inflow": false,
  "manipulation_score": 42,
  "agent_signal_score": 3.8,
  "tradingagents_confidence": 0.72
}
```

平仓后打标签：

```text
win
loss
breakeven
stopped_by_risk
manual_exit
```

## Growth Reports

### Daily Review

- 今日交易数
- 今日 PnL
- 盈利订单特征
- 亏损订单特征
- 风控拦截是否有效
- 明日建议

### Weekly Diagnosis

- 策略排名
- Agent 排名
- Signal 来源有效性
- 亏损主要原因
- 建议禁用信号
- 建议调整参数

### Candidate Strategy

```json
{
  "source": "order_intelligence",
  "hypothesis": "低位横盘超过 14 天且 manipulation_score < 60 时小仓位买入胜率更高",
  "strategy_type": "bottom_accumulation",
  "config": {},
  "status": "generated"
}
```

## SHAP

SHAP 用于解释：

- 模型预测；
- FreqAI 信号；
- 盈亏分类模型；
- 高胜率特征；
- 亏损特征。

## 状态机

```text
generated
  ↓ static_checked
backtested
  ↓
paper_running
  ↓
paper_passed
  ↓
human_approved
  ↓
live_small
```

Growth Engine 只能创建 `generated`，最多自动推进到 `backtested`，不能自动 live。

## API

```text
POST /api/growth/daily-review
POST /api/growth/weekly-diagnosis
POST /api/growth/order-mining
GET  /api/growth/reports
GET  /api/growth/candidates
POST /api/growth/candidates/{id}/backtest
POST /api/growth/candidates/{id}/paper-run
```

## 阶段验收

- [ ] 每笔订单有 feature_snapshot；
- [ ] 平仓订单可标记 win/loss；
- [ ] 可生成每日复盘；
- [ ] 可生成盈利/亏损特征摘要；
- [ ] 可生成 SHAP 特征重要性；
- [ ] 可生成 StrategyCandidate；
- [ ] Candidate 可自动回测；
- [ ] Candidate 不能自动 live。

---

# v2.3.1 同步修订：SHAP / Growth Engine 的远程与离线批处理

## 变更原因

SHAP、历史订单挖掘、候选策略生成属于重计算和长耗时任务，不应占用实时交易链路资源，也不应与 AI 投研实时任务争抢本地 GPU。v2.3 后，Growth Engine 必须默认异步化、批处理化、可远程化。

## 新执行模式

```text
Execution Logs / Orders / Feature Snapshots
  ↓
Growth Job Queue
  ↓
Remote SHAP / Local Batch SHAP / Cloud LLM Summary
  ↓
AttributionReport
  ↓
StrategyCandidate
```

## Provider Policy

SHAP 或归因摘要任务使用：

```json
{
  "task_type": "growth_attribution",
  "privacy_level": "medium",
  "latency_class": "slow_ok",
  "structured_output_required": true,
  "fallback_chain": ["private_model_server", "local_batch", "openai", "deepseek"]
}
```

## 隐私约束

订单明细默认不直接出云。云端摘要任务只允许发送：

- 去标识化订单统计；
- 特征聚合；
- 盈亏标签；
- 不含 API Key / exchange account id / 原始钱包地址的内容。

## 新增 Job 状态

```text
queued
running
remote_running
local_running
completed
failed
cancelled
```

## 验收标准补充

- SHAP 任务不阻塞 Freqtrade；
- Growth Job 可以取消；
- AttributionReport 记录 provider_trace；
- 云端任务不会发送原始 API Key、账户 ID、交易所密钥；
- CandidateStrategy 只能进入 backtest，不得直接进入 dry-run/live。

## 禁止事项

- 禁止 SHAP 同步阻塞交易执行；
- 禁止 Growth Engine 自动替换 live 策略；
- 禁止把云端归因结果当作确定事实，必须标记 provider 和 data_quality。


---

# v2.3.2 Addendum: Growth Engine Cold Signal Lookup

## Required implementation tasks

1. Growth Engine must call `SignalRepository.get_signal()` for all signal evidence lookup.
2. Growth Engine must support hot and cold Signal evidence transparently.
3. If a signal is archived, Growth Engine must use `signal_reference_snapshots` or archive lookup.
4. Missing evidence must be marked as `evidence_missing`, not silently ignored.
5. Attribution reports must include evidence coverage ratio.

## Acceptance criteria

- A 6-month order attribution report can include archived Signal reasoning.
- Candidate strategy generation reports which signals were hot, cold, or missing.
- Missing Signal evidence lowers confidence of generated strategy candidates.

## v2.4 补充：Growth Engine 依赖 FeatureSnapshot 与 ExecutionLedger

### 必做任务

1. TradeIntent 创建前必须保存或引用 `feature_snapshot_id`。

2. 创建 TradeIntent 时必须写入 `trade_intent_signal_snapshots`。

3. Growth Engine 查询历史订单时必须从以下来源重建事实：

```text
execution_ledger_events
orders
positions
feature_snapshots
trade_intent_signal_snapshots
risk_decisions
```

4. Growth Engine 不允许直接依赖 signals 热表。

5. CandidateStrategy 必须写入策略候选表，并只能进入 backtest，不能直接 live。

### 验收标准

```text
即使历史 Signal 被归档，订单归因仍能看到触发时的 signal snapshot。
每笔已关闭订单都能找到 entry feature snapshot。
Growth 报告可以解释：盈利来自哪些特征，亏损来自哪些特征。
```

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。
