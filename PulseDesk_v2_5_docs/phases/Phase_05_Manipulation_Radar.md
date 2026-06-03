# Phase 05 — 操控雷达 Market Manipulation Radar

## 目标

识别加密货币中的庄家操控、插针收割、洗盘交易、拉盘出货、资金费率收割、高集中度代币风险，并作为风险模块和高风险猎币模式的前置过滤器。

## 风险类型

```text
Pump & Dump
Wash Trading
Stop Hunt
Funding Squeeze
Holder Concentration
Liquidity Trap
News/KOL Hype Exit
Exchange Inflow Dump
```

## 数据输入

必须支持：

- OHLCV
- 成交量
- 盘口深度
- funding_rate
- open_interest
- liquidation
- long_short_ratio
- exchange_inflow
- exchange_outflow
- holder_concentration
- top_wallets
- project_wallets
- DEX liquidity
- LP change
- news sentiment
- KOL/social burst

第一版可 mock 部分链上数据，但接口必须预留。

## 特征工程

### Stop Hunt Features

```text
wick_ratio
volume_spike_zscore
reversal_after_spike
liquidation_cluster
orderbook_depth_thin
price_reclaim_speed
```

### Holder Concentration Features

```text
top10_holder_pct
top50_holder_pct
team_wallet_pct
vc_wallet_pct
exchange_wallet_inflow
wallet_activity_sync
```

### Funding Squeeze Features

```text
funding_rate_zscore
oi_change_pct
liquidation_imbalance
price_range_compression
subsequent_spike
```

### Pump Dump Features

```text
social_burst_score
news_positive_burst
volume_price_divergence
exchange_inflow_after_pump
long_upper_wick_after_hype
```

## 输出

```json
{
  "symbol": "XXX/USDT",
  "manipulation_score": 82,
  "stop_hunt_score": 76,
  "holder_concentration_score": 91,
  "liquidity_trap_score": 84,
  "pump_dump_score": 73,
  "funding_squeeze_score": 68,
  "risk_level": "extreme",
  "suggestion": "block_live_trade",
  "reasoning": "...",
  "evidence": []
}
```

## Risk Rules

| 条件 | 决策 |
|---|---|
| manipulation_score > 80 | 禁止实盘 |
| stop_hunt_score > 75 | 禁止追单 |
| holder_concentration_score > 85 | 只允许观察 |
| liquidity_trap_score > 75 | 禁止市价单 |
| funding_squeeze_score > 70 | 降仓 |
| pump_dump_score > 75 | 禁止追高 |

## High-Risk Hunt Mode

强制规则：

```text
独立资金池
默认 paper
单笔 0.2% - 1%
禁止默认杠杆
强制止损
强制分批止盈
禁止补仓摊平
manipulation_score > 80 禁止实盘
必须人工确认
```

## 页面布局

```text
操控雷达
输入：Symbol / Watchlist / Timeframe

卡片：
- Manipulation Score
- Stop Hunt
- Holder Concentration
- Liquidity Trap
- Funding Squeeze
- Pump Dump

图表：
- 插针位置
- OI/Funding 变化
- 交易所流入
- 钱包集中度
- 新闻/KOL 热度

操作：
[发布 Risk Signal] [加入观察] [禁止策略交易]
```

## 阶段验收

- [ ] 可计算 mock manipulation score；
- [ ] 可发布 manipulation Signal；
- [ ] 高风险 Signal 进入风控中心；
- [ ] RiskEngine 可根据 manipulation score 拦截；
- [ ] High-Risk Hunt Mode 只允许 paper。

---

# v2.1 补充：数据源分层与高风险模式边界

## 数据源分层

### 5A：行情可计算特征（必须先做）

数据：OHLCV、成交量。

特征：

- wick_ratio_up / wick_ratio_down；
- volume_zscore；
- candle_range_pct；
- pump_then_dump_score；
- dump_then_recover_score；
- low_liquidity_volatility_score。

### 5B：衍生品特征（第二阶段）

数据：funding rate、open interest、long/short ratio、liquidation。

特征：

- funding_extreme_score；
- oi_spike_score；
- liquidation_cluster_score；
- squeeze_risk_score。

### 5C：链上与钱包集中度（第三阶段）

数据：holder distribution、exchange inflow/outflow、team/VC wallet movement。

候选来源：Dune、Etherscan、Solscan、Arkham、Nansen、Glassnode、CryptoQuant、manual CSV。

## 输出限制

操控雷达只能输出 RiskSignal：

```text
risk / block / reduce_size / paper_only
```

不得输出确定性 long/short 信号。

## 高风险猎币模式

必须绑定 `CapitalPool(pool_type=high_risk_hunt)`。

默认规则：

- 单笔最大资金池 0.5%；
- 总暴露最大资金池 3%；
- 日亏损 1% 停止；
- 最大回撤 8% 停止；
- 不允许杠杆；
- 不允许自动实盘；
- 必须人工确认；
- manipulation_score > 80 禁止 live；
- stop_hunt_score > 75 禁止追单。

---

# v2.3.1 同步修订：操控雷达的云端/本地任务拆分

## 变更原因

操控雷达既包含本地可快速计算的 K 线/成交量特征，也包含适合云端 LLM 理解的新闻/KOL/社媒语义，还可能包含远程重模型或第三方 API 的链上分析。必须拆分任务类型，避免所有能力都压在本地 GPU 或单一后端任务上。

## 任务分层

### Layer A：本地快速特征

适合本地 CPU / PostgreSQL / Pandas 计算：

- wick_ratio；
- volume_zscore；
- price_reversal_speed；
- rolling_high_low_break；
- volatility_spike；
- abnormal_range；
- candle_pinbar_score。

### Layer B：远程市场数据特征

依赖第三方或交易所 API：

- funding_rate；
- open_interest；
- liquidation；
- long_short_ratio；
- orderbook_depth；
- exchange_inflow/outflow。

### Layer C：云端文本理解

适合 Cloud LLM Structured Output：

- KOL coordinated hype；
- project announcement risk；
- social burst narrative；
- misleading marketing；
- suspicious pump language。

## Provider Policy

操控雷达文本分析任务使用：

```json
{
  "task_type": "manipulation_text_analysis",
  "privacy_level": "public",
  "latency_class": "medium",
  "structured_output_required": true,
  "fallback_chain": ["deepseek", "openai", "ollama"]
}
```

## 输出要求

Manipulation Signal 必须包含 provider_trace。如果只使用本地特征，则 provider 为 `system_local_features`。

## 验收标准补充

- 操控雷达详情页区分本地特征、远程市场数据、云端文本分析；
- 缺失链上数据时，风险评分必须显示 data_quality，而不是伪装完整；
- 云端文本分析失败时，仍然可以输出基于本地特征的 degraded Signal；
- manipulation_score > 80 的 Signal 默认 can_live_trade=false。

## 禁止事项

- 禁止在缺少链上数据时给出“钱包集中度高”的确定性结论；
- 禁止云端文本分析直接触发交易；
- 禁止把操控雷达作为收益预测器，它只能是风险/机会辅助信号。

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。
