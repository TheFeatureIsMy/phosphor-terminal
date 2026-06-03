# PulseDesk v2.3 Revision Changelog

> v2.3 在 v2.2 工程安全版基础上，加入“云优先 + 远程专用模型 + 本地兜底”的 Hybrid AI Routing 架构。

---

## 1. 背景

v2.2 已解决：

- 本地多模型并发需要 Inference Worker Queue；
- 禁止 LLM / Canvas 动态生成 Strategy.py；
- Signal 存储需要分区和归档；
- MCP Server 只读优先；
- Freqtrade 必须有原生硬风控兜底。

v2.3 进一步发现：

单纯“本地推理排队”仍然不是最佳方案。对于个人工作台，AI 投研、RAG、Agent 辩论、情绪分析、时序预测、SHAP 归因不应全部压在本地 GPU 上。更合理的是：

```text
云端 LLM 做高质量语义推理
远程专用模型服务做 TimesFM / Chronos / SHAP
本地 Ollama / FinBERT 只做兜底
PulseDesk 本地只做控制流、风控、执行管理与审计
```

---

## 2. 采纳的优化建议

| 优化项 | 采纳状态 | 优先级 | 处理方式 |
|---|---:|---:|---|
| AI 投研 / RAG / Agent 平台全量接入云端 LLM | 采纳 | P0 | LLMRouter 增加 CloudLLMProvider |
| FinBERT 用云端 Structured Output 平替 | 采纳 | P1 | 本地 FinBERT 降级为 fallback |
| TimesFM / Chronos 远程推理 | 采纳 | P1 | RemoteModelProvider / PrivateModelServer |
| SHAP 远程或离线批处理 | 采纳 | P1 | 不进入实时交易链路 |
| LLMRouter 混合路由 | 强制采纳 | P0 | task_type + privacy + latency + cost 路由 |
| 云端 Provider Trace | 强制采纳 | P0 | Signal / ResearchReport 必须记录 provider_trace |
| 隐私数据出云分级 | 强制采纳 | P0 | PrivacyRedactor 必须执行 |

---

## 3. 新增文件

- `08_Cloud_Hybrid_AI_Routing_v2_3.md`

---

## 4. 更新文件

- `README.md`
- `02_Technical_Architecture.md`
- `03_App_IA_and_UI_Layouts.md`
- `04_Data_Models_API_DB.md`
- `05_Security_Risk_Guardrails.md`
- `06_AI_Development_Prompts.md`
- `phases/Phase_04_AI_Research_and_Agent_Platform.md`

---

## 5. v2.3 强制原则

1. AI 投研 / RAG / Agent 辩论默认云端 LLM；
2. 本地 Ollama 默认只作为 fallback；
3. TimesFM / Chronos / SHAP 默认远程或离线，不进入实时交易链路；
4. 云端输出必须 JSON Schema 校验；
5. 云端模型不得生成开放式 Strategy.py；
6. API Key / exchange secret / 原始订单明细默认禁止出云；
7. Provider 切换不得改写历史 Signal；
8. Signal 必须记录 provider_trace；
9. live_small 不得依赖实时 LLM 响应；
10. AI Provider degraded 不得影响 Freqtrade 原生硬风控。

---

## 6. v2.3 MVP

最小可交付：

```text
1. LLMRouter Provider 抽象
2. 至少接入一个云端 Provider
3. 本地 Ollama fallback
4. Structured Output Validator
5. Provider Trace 入库
6. AI 服务页面展示 Provider 状态
7. FinBERT 云端结构化平替入口
```


## v2.3.1 — 全阶段开发计划同步修订

本次修订确认 v2.3 的 Cloud-First Hybrid AI Routing 不仅影响 Phase 04，也会影响 Signal、Freqtrade、Strategy、Manipulation、Growth、Live Safety 等阶段。因此对所有 Phase 文件补充了 v2.3 同步约束：

- Phase 01：Signal 必须记录 provider_trace / privacy_level / cost / latency；Signal Center 必须能展示云端/本地来源。
- Phase 02：Freqtrade Adapter 严禁从云端 LLM 输出直接生成 Strategy.py；只允许 StrategyRuleDSL + UniversalStrategy 模板。
- Phase 03：Canvas 只生成 StrategyRuleDSL，不生成 Python；从云端生成的 StrategyDraft 必须先进入 draft + validate。
- Phase 04：Cloud-first AI Research、Provider Policy、PrivacyRedactor、Structured Output Validator、Ollama fallback。
- Phase 05：操控雷达分成本地快速特征、远程重模型分析、云端文本理解三类任务。
- Phase 06：SHAP / 归因默认离线或远程批处理，不进入实时交易链路。
- Phase 07：云端 AI 不作为 live_small 的实时风控唯一依据；Freqtrade 原生硬风控必须独立生效。

