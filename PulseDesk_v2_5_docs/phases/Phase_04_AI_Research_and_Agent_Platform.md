# Phase 04 — AI 投研室与 Agent 平台

## 目标

融合 TradingAgents 和 AI-Trader 思想，建立 AI 投研委员会与个人 Agent 平台。

## 范围

### 本阶段做

- TradingAgents Adapter
- ResearchReport
- AI 多 Agent 流程展示
- 发布 TradingSignal
- 生成 StrategyDraft
- Agent Registry
- Agent Permission
- Agent Signal Publisher
- Agent Performance Tracker

### 本阶段不做

- Agent 直接实盘
- 复制交易社区
- 多用户 Agent 平台
- 自动提升 Agent 到 live

## TradingAgents Adapter

### 输入

```json
{
  "symbol": "BTC/USDT",
  "market": "crypto",
  "timeframe": "1h",
  "depth": "standard",
  "context": {
    "ohlcv": [],
    "technical_features": {},
    "sentiment": {},
    "onchain": {},
    "position": {},
    "risk_state": {}
  }
}
```

### 输出

```json
{
  "report_id": "xxx",
  "symbol": "BTC/USDT",
  "rating": "overweight",
  "direction": "long",
  "confidence": 0.72,
  "risk_level": "medium",
  "agent_opinions": {
    "technical": "...",
    "sentiment": "...",
    "onchain": "...",
    "bull": "...",
    "bear": "...",
    "risk": "...",
    "portfolio": "..."
  },
  "suggested_signal": {},
  "strategy_draft": {}
}
```

## Agent Runtime

Agent 类型：

```text
btc_conservative_agent
trend_follow_agent
mean_reversion_agent
news_event_agent
whale_monitor_agent
manipulation_risk_agent
high_risk_hunt_agent
risk_guard_agent
reflection_agent
```

权限：

```text
observe_only
signal_only
paper_trade_allowed
live_requires_confirm
disabled
```

Agent 不允许直接执行订单。

## Agent Performance

统计：

- signal_count
- win_rate_after_signal
- average_return_after_signal
- max_drawdown_after_signal
- false_positive_rate
- risk_hit_rate
- last_30d_score

## API

```text
POST /api/research/tradingagents/run
GET  /api/research/reports
POST /api/research/{id}/publish-signal
POST /api/research/{id}/create-strategy-draft

POST /api/agents
GET  /api/agents
GET  /api/agents/{id}
POST /api/agents/{id}/enable
POST /api/agents/{id}/disable
GET  /api/agents/{id}/performance
POST /api/agents/{id}/publish-signal
```

## 安全约束

1. Research Signal 默认 can_live_trade=false。
2. Agent 最高只能到 live_requires_confirm。
3. Agent 表现差时自动降权，不自动升 live。
4. 所有 Agent 输出必须有 evidence。
5. LLM 失败返回 hold/high risk。

## 阶段验收

- [ ] 可运行 BTC/USDT AI 研究；
- [ ] 可看到多 Agent 观点；
- [ ] 可发布 tradingagents Signal；
- [ ] 可创建 StrategyDraft；
- [ ] 可创建 Agent；
- [ ] Agent 可发布 Signal；
- [ ] Agent 表现可查看；
- [ ] Agent 不可实盘。

---

# v2.2 补充：AI Research 必须先接入 Inference Worker Queue

## 新增目标

TradingAgents、Ollama、TimesFM、Chronos、SHAP 不允许直接在 API 请求线程内执行。必须通过 Inference Worker Queue 调度。

## 新增任务

### 1. InferenceJob 表和 API

实现：

```text
POST /api/inference/jobs
GET  /api/inference/jobs
GET  /api/inference/jobs/{id}
POST /api/inference/jobs/{id}/cancel
GET  /api/inference/runtime-state
```

### 2. Provider Adapter

至少实现 mock adapter 和两个真实 adapter：

- mock_provider：测试用；
- finbert_provider：情绪任务；
- ollama_provider 或 llm_provider：研究任务。

TimesFM / Chronos / SHAP 可先实现 mock，占位但接口固定。

### 3. UI 队列状态

AI 投研室和 AI 服务管理页面必须展示：

- queued；
- running；
- timeout；
- degraded；
- failed；
- succeeded。

## 新增验收标准

- 运行 AI 研究时创建 InferenceJob；
- heavyweight job 串行；
- job 超时不会阻塞 API；
- 失败会生成 degraded ResearchReport/Signal；
- UI 可以看到任务状态。

---

# v2.3 Addendum — Cloud / Hybrid AI Routing Tasks

## 1. Phase 04 新增目标

Phase 04 不再默认本地运行所有 AI 模型。新增目标：

```text
实现 LLMRouter v2.3
实现 CloudLLMProvider + LocalFallback
实现 ProviderTrace
实现 PrivacyRedactor
实现云端结构化情绪分析
预留 TimesFM / Chronos / SHAP 远程模型 Provider
```

## 2. 新增任务清单

### 4.x.1 LLMRouter Provider 抽象

交付：

```text
ai_quant_core/providers/base.py
ai_quant_core/llm_router.py
ai_quant_core/provider_policy.py
```

验收：

```text
给定 task_type=research_deep_dive，能选择 cloud provider。
给定 privacy_level=local_only，必须选择 local provider 或拒绝。
provider 不可用时，能 fallback。
```

### 4.x.2 Cloud Provider 接入

最小实现一个：

```text
DeepSeekProvider 或 OpenAIProvider
```

验收：

```text
能完成一次 structured JSON 输出。
输出通过 Pydantic validate。
provider_trace 入库。
```

### 4.x.3 PrivacyRedactor

验收：

```text
输入包含 api_key / secret / token 时，输出必须删除。
输入订单明细时，默认聚合为摘要。
输出 input_hash。
```

### 4.x.4 Cloud Sentiment Signal

验收：

```text
新闻文本 → LLMRouter → SentimentSignal
SentimentSignal 包含 provider_trace
can_live_trade=false
失败时 fallback 到本地或 neutral degraded
```

### 4.x.5 AI 服务 UI 升级

验收：

```text
AI 服务页面能看到 provider 状态、任务路由、成本、延迟、队列状态、本地 GPU 状态。
```

## 3. 本阶段禁止事项

```text
禁止云端模型生成 Strategy.py
禁止云端模型直接生成 live order
禁止把 API Key / exchange secret 发送给云端
禁止 live_small 依赖实时 LLM 响应
```

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。
