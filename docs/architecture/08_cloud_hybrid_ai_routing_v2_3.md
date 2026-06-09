# 08 — Cloud / Hybrid AI Routing v2.3

> 版本：v2.3  
> 目的：把 v2.2 的本地推理队列进一步升级为“云优先 + 本地兜底 + 远程专用模型服务”的混合 AI 路由架构，降低本地 VRAM 压力、提升推理质量和系统稳定性。

---

## 1. 结论

v2.2 已经加入 `Inference Worker Queue / VRAM Scheduler`，用于解决本地多模型并发踩踏问题。v2.3 的结论是：

**PulseDesk 不应默认把所有 AI 模型都部署在本地。**

推荐改为：

```text
云端 LLM 优先
  ↓
远程专用时序/归因模型服务
  ↓
本地轻量兜底
  ↓
本地 GPU 只保留可控、低频、离线任务
```

核心原因：

1. 个人设备显存有限，12GB 级别消费 GPU 同时运行 LLM、TimesFM、Chronos、FinBERT、SHAP 容易 OOM；
2. AI 投研、RAG、Agent 辩论不是 HFT 低延迟链路，适合异步云端调用；
3. 云端结构化输出可显著降低本地模型维护复杂度；
4. PulseDesk 本地应主要承担控制流、风控、Freqtrade 管理、数据持久化，而非承担全部推理计算。

---

## 2. 架构调整

### 2.1 v2.2 架构

```text
AI Quant Core
├── LLMRouter
├── Inference Worker Queue
├── Ollama
├── FinBERT
├── TimesFM
├── Chronos
└── SHAP
```

### 2.2 v2.3 架构

```text
AI Quant Core
├── LLMRouter
│   ├── CloudLLMProvider
│   │   ├── OpenAIProvider
│   │   ├── AnthropicProvider
│   │   ├── DeepSeekProvider
│   │   └── OtherCompatibleProvider
│   ├── RemoteModelProvider
│   │   ├── ReplicateProvider
│   │   ├── RunPodProvider
│   │   └── PrivateModelServerProvider
│   └── LocalModelProvider
│       ├── OllamaProvider
│       ├── LocalFinBERTProvider
│       └── LocalFallbackProvider
│
├── Inference Worker Queue
│   ├── cloud_llm_queue
│   ├── remote_model_queue
│   └── local_gpu_queue
│
├── Provider Policy Engine
├── Cost / Latency Tracker
├── Privacy Redaction Layer
└── Structured Output Validator
```

---

## 3. 模块平替方案

## 3.1 AI 投研室 / RAG / Agent 平台

### 当前问题

TradingAgents-style 多 Agent 投研会产生大量长上下文、多轮辩论、结构化总结任务。如果使用本地 Ollama，容易出现：

- 推理慢；
- 上下文长度受限；
- 多 Agent 并发时显存压力大；
- 输出 JSON 稳定性弱；
- 研报质量不稳定。

### v2.3 方案

默认使用云端 LLM：

```text
AI 投研室：DeepSeek / OpenAI / Anthropic
RAG 摘要：轻量云模型
Agent 辩论：性价比云模型
最终裁判：高质量云模型
```

推荐任务路由：

| 任务 | 默认 Provider | 兜底 Provider | 本地兜底 |
|---|---|---|---|
| TradingAgents 深度研究 | DeepSeek Reasoning / Claude / GPT | OpenAI / Anthropic | Ollama only if cloud unavailable |
| 多 Agent 辩论 | DeepSeek Chat / GPT mini-class | OpenAI mini-class | Ollama |
| RAG 文档摘要 | 低成本云模型 | 本地 Ollama | none |
| StrategyDraft 生成 | 云端结构化输出模型 | Anthropic / OpenAI | 禁止本地自由输出直接执行 |
| Signal reasoning | 云端轻量模型 | 本地 Ollama | 允许 degraded |

### 强制规则

1. AI 投研输出必须经过 JSON Schema 校验；
2. 所有云端 LLM 输出默认只能生成 `ResearchReport / Signal / StrategyDraft`；
3. 不允许云端 LLM 生成开放式 `Strategy.py`；
4. 云端 Provider 超时后进入 degraded，不阻塞 Freqtrade 原生风控；
5. 低成本任务不得默认使用最高价模型。

---

## 3.2 FinBERT 情绪分析

### 原方案

```text
本地 FinBERT → SentimentSignal
```

### v2.3 方案

默认改为：

```text
云端 LLM Structured Output → SentimentSignal
```

原因：

- 币圈文本大量包含黑话、反讽、KOL 暗示、项目方营销话术；
- 传统 FinBERT 对金融新闻有效，但对加密货币社媒语境不一定足够；
- 云端 LLM 可以通过 prompt 输出结构化情绪、叙事、风险与操控线索；
- 本地 FinBERT 降级为可选 fallback。

### 输出 Schema

```json
{
  "source_type": "cloud_llm_sentiment",
  "source_name": "deepseek_sentiment_v1",
  "symbol": "BTC/USDT",
  "sentiment_score": 0.72,
  "sentiment_label": "positive|neutral|negative|mixed",
  "confidence": 0.83,
  "narrative_tags": ["ETF", "rate_cut", "exchange_inflow"],
  "manipulation_clues": ["coordinated_hype", "suspicious_kol_push"],
  "reasoning": "...",
  "model_provider": "deepseek",
  "created_at": "..."
}
```

### 保留本地 FinBERT 的场景

```text
云端不可用
隐私敏感文本
批量离线分析
成本控制
```

---

## 3.3 TimesFM / Chronos 价格预测

### 当前问题

主流通用 LLM 服务商通常不直接提供 TimesFM / Chronos 这类时序基础模型 API。直接本地跑会占用 GPU/CPU，并与 LLM / SHAP 争抢资源。

### v2.3 方案

采用三层策略：

```text
Remote Dedicated Model API 优先
  ↓
Private Cloud Model Server
  ↓
Local Queue Fallback
```

### 方案 A：Serverless / 托管推理服务

适用：低频预测、按需调用、减少本地运维。

```text
PulseDesk → RemoteModelProvider → Replicate / RunPod / Similar Service → TimesFM / Chronos Container
```

要求：

1. 模型必须封装成稳定 HTTP API；
2. 请求必须异步；
3. 默认超时 30–120 秒；
4. 预测失败返回 degraded PredictionSignal；
5. 禁止阻塞交易执行链路。

### 方案 B：私有云 AI Model Server

适用：你有云端 VPS / GPU / CPU 节点。

```text
PulseDesk Backend
  ↓ HTTPS + Token
Private Model Server
  ├── TimesFM API
  ├── Chronos API
  ├── SHAP API
  └── batch job queue
```

要求：

1. 私有服务必须有 API Token；
2. 每个任务有 job_id；
3. 支持异步轮询；
4. 支持结果缓存；
5. 不允许私有云服务直接访问交易所 API Key。

### 输出 PredictionSignal

```json
{
  "source_type": "timesfm|chronos",
  "source_name": "remote_timesfm_v1",
  "symbol": "BTC/USDT",
  "timeframe": "1d",
  "horizon": "7d",
  "direction": "long|short|hold",
  "confidence": 0.61,
  "forecast_range": {
    "p10": 62000,
    "p50": 66000,
    "p90": 71000
  },
  "permission": {
    "can_show": true,
    "can_backtest": true,
    "can_paper_trade": true,
    "can_live_trade": false,
    "requires_human_confirm": true
  }
}
```

---

## 3.4 SHAP 归因

### 推荐调整

SHAP 不应在交易实时链路中同步运行。它应作为：

```text
离线复盘任务
批量归因任务
策略进化证据任务
```

推荐部署：

```text
Growth Engine → SHAP Job → RemoteModelProvider or LocalBatchQueue → AttributionReport
```

强制规则：

1. SHAP 不参与下单实时决策；
2. SHAP 结果只用于解释、复盘、候选策略生成；
3. SHAP 批处理任务可运行在夜间；
4. SHAP 失败不得影响 Freqtrade dry-run/live_small 风控。

---

## 4. LLMRouter v2.3 设计

### 4.1 路由目标

LLMRouter 不只是“选模型”，而是基于任务类型、成本、延迟、隐私等级、结构化输出能力、可用性进行路由。

### 4.2 Routing Policy

```json
{
  "task_type": "research_deep_dive",
  "privacy_level": "medium",
  "latency_class": "slow_ok",
  "quality_level": "high",
  "structured_output_required": true,
  "max_cost_usd": 1.5,
  "fallback_chain": ["deepseek_reasoner", "claude", "gpt", "ollama"]
}
```

### 4.3 TaskType 枚举

```text
research_deep_dive
agent_debate
rag_summary
sentiment_classification
strategy_draft_generation
signal_reasoning
prediction_timeseries
shap_attribution
manipulation_explanation
code_assistant_readonly
```

### 4.4 Provider Capability Matrix

| Provider | LLM | Structured Output | Reasoning | Long Context | Low Cost | Local VRAM | 用途 |
|---|---:|---:|---:|---:|---:|---:|---|
| OpenAI | yes | strong | yes | yes | medium | no | 高质量结构化输出、策略草稿 |
| Anthropic | yes | strong | yes | yes | medium/high | no | 长文本研报、投研解释 |
| DeepSeek | yes | json mode | yes | yes | low/medium | no | 多 Agent 辩论、低成本投研 |
| Ollama | yes | weak/medium | depends | local limit | zero API cost | yes | 云不可用兜底 |
| Replicate/RunPod | model-dependent | API wrapper | no/depends | depends | usage-based | no local | TimesFM/Chronos/SHAP |
| Private Model Server | model-dependent | custom | depends | custom | infra cost | no local | 私有时序/归因服务 |

---

## 5. 隐私与安全策略

### 5.1 数据出云分级

```text
public_market_data：可发送云端
research_text：可发送云端，但需记录 provider_trace
trade_history_summary：默认脱敏后发送
raw_order_history：默认不发送云端
api_keys：永不发送云端
exchange_secret：永不发送云端
wallet_address_book：默认不发送云端，除非人工确认
```

### 5.2 Redaction Layer

所有云端请求必须经过：

```text
PrivacyRedactor
  ↓
移除 API Key / Secret / Token
脱敏账户 ID
脱敏本地路径
压缩订单明细为统计摘要
记录 provider_trace
```

### 5.3 Provider Trace

每个由云端生成的 Signal / ResearchReport 必须记录：

```json
{
  "provider_trace": {
    "provider": "deepseek",
    "model": "xxx",
    "request_id": "xxx",
    "input_hash": "sha256:...",
    "schema_version": "signal_v2_3",
    "latency_ms": 3400,
    "estimated_cost_usd": 0.03,
    "created_at": "..."
  }
}
```

---

## 6. Inference Queue v2.3

v2.2 的 Inference Queue 保留，但职责调整：

```text
CloudQueue：管理云端 LLM 请求、限流、重试、成本预算
RemoteModelQueue：管理 TimesFM / Chronos / SHAP 远程任务
LocalGPUQueue：仅作为 fallback 或夜间批处理
```

### 6.1 队列策略

| 队列 | 并发 | 超时 | 重试 | 用途 |
|---|---:|---:|---:|---|
| cloud_llm_queue | 2-5 | 60s | 2 | RAG、投研、情绪、策略草稿 |
| remote_model_queue | 1-3 | 180s | 1 | TimesFM、Chronos、SHAP |
| local_gpu_queue | 1 | 300s | 0 | 本地 fallback / 夜间任务 |

### 6.2 降级策略

```text
云端 LLM 不可用 → 本地 Ollama 只读分析 → Signal status=degraded
远程时序不可用 → 不生成 PredictionSignal，不阻塞策略执行
SHAP 失败 → 复盘报告标记 attribution_unavailable
本地 GPU OOM → 禁止自动重试，标记 local_gpu_unavailable
```

---

## 7. UI 更新

AI 服务页面需要新增：

```text
Provider 路由策略
云端 / 本地 / 远程模型服务状态
模型任务映射表
今日 API 调用成本
平均延迟
失败率
隐私等级设置
本地 GPU 状态
队列状态
```

AI 总控台需要展示：

```text
AI Provider 状态：normal / degraded / cloud_unavailable / local_queue_busy
本地 GPU 状态：idle / busy / OOM_protected
今日 AI 成本
```

Signal 详情页需要展示：

```text
生成 Provider
模型名称
latency
cost
privacy_level
input_hash
```

---

## 8. 开发约束

1. 云端模型输出必须 JSON Schema 校验；
2. 云端模型不得生成开放式 `Strategy.py`；
3. 云端模型不得接收 API Key / exchange secret；
4. 本地模型只能作为 fallback，不得阻塞交易执行链路；
5. TimesFM / Chronos / SHAP 默认异步远程或离线批处理；
6. 所有 Provider 调用必须有 timeout、retry、audit log；
7. Provider 切换不得改变已有 Signal 的历史记录，只能影响新任务；
8. Signal 必须记录 provider_trace；
9. 成本预算超过阈值后，非关键 AI 任务自动降级或暂停；
10. live_small 决策不得依赖“当前正在运行中的 LLM 实时响应”。

---

## 9. v2.3 MVP 范围

v2.3 不要求立即接入所有云厂商。最小可交付：

```text
1. LLMRouter Provider 抽象
2. OpenAI 或 DeepSeek 任一云 Provider
3. 本地 Ollama fallback
4. Structured Output Validator
5. Provider Trace 入库
6. AI 服务页面显示 Provider 状态
7. FinBERT 云端结构化平替入口
```

TimesFM / Chronos 远程服务可以在 Phase 04 后半段或 Phase 05 前实施。

---

## 10. Sources

- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs
- Anthropic Structured Outputs: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- DeepSeek JSON Output: https://api-docs.deepseek.com/guides/json_mode
- Replicate Deployments: https://replicate.com/docs/topics/deployments
- Replicate autoscaling / scale to zero: https://replicate.com/
- MCP Intro: https://modelcontextprotocol.io/docs/getting-started/intro

