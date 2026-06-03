# PulseDesk v2.0 AI 辅助开发 Prompt 集

## 1. 通用开发 Prompt

```text
你是 PulseDesk v2.0 的资深全栈开发工程师。

产品定位：
PulseDesk 是个人 AI 量化交易工作台，不是 SaaS。
核心主线：
AI研究 / RAG / 价格预测 / 因子研究 / FreqAI / 市场情绪 / 操控雷达
→ 统一生成 Signal
→ Signal Center
→ Strategy Workspace
→ Backtest / Paper / Dry-run
→ RiskEngine
→ Freqtrade Adapter
→ Execution Logs
→ SHAP / 归因 / 自我成长。

强制架构原则：
1. Signal Center 是中枢。
2. Freqtrade 是 Crypto 执行底座。
3. AI/Agent 不允许直接下单。
4. 所有 TradeIntent 必须经过 RiskEngine。
5. 第一阶段禁止 live_trade。
6. 所有数据模型必须有 Pydantic Schema 和 TypeScript 类型。
7. 所有 API 必须有错误处理和日志。
8. 所有 LLM 输出必须 JSON parse + Pydantic validate。
9. 所有失败必须返回安全默认值。
10. 不允许写 TODO 空实现。

当前任务：
[在这里粘贴具体模块需求]

请输出：
1. 文件结构
2. 后端代码
3. 前端代码
4. 类型定义
5. API 调用示例
6. 单元测试
7. 错误处理
8. 验收标准
```

## 2. Signal Center Prompt

```text
本轮任务：实现 PulseDesk Signal Center。

要求：
1. 定义 Signal Pydantic Schema。
2. 定义前端 TypeScript Signal 类型。
3. 实现 Signal CRUD API。
4. 实现 Signal list/filter/sort 页面。
5. 支持 source_type：
   tradingagents, ai_trader_agent, finbert, timesfm, chronos, qlib, freqai, technical, onchain, manipulation, rag, manual, dag_strategy。
6. Signal 默认 can_live_trade=false。
7. Signal 可以生成 StrategyDraft，但不能直接执行。
8. 所有 Signal 操作写 audit log。
9. 实现 mock 数据。
10. 实现 conflict-check：同一 symbol 不同方向高置信度 Signal 视为冲突。
```

## 3. Freqtrade Adapter Prompt

```text
本轮任务：实现 Freqtrade Adapter。

要求：
1. 使用 Freqtrade 官方 Docker 镜像。
2. 后端负责生成 config.json 和 StrategyRuleDSL RulePackage；不得生成开放式 Strategy.py。
3. 支持 backtest run。
4. 支持 dry-run start/stop。
5. 支持读取 Freqtrade REST API。
6. 支持订阅 WebSocket RPC。
7. 支持同步 orders / trades / status。
8. 禁止 live trade。
9. Docker 只允许操作 PulseDesk 创建的容器。
10. API Key 不允许写入日志和 Git 目录。
11. 所有执行写 freqtrade_runs 和 execution_logs。
```

## 4. Strategy Workspace Prompt

```text
本轮任务：实现 Strategy Workspace。

要求：
1. 策略来源支持 manual, ai_chat, tradingagents, rag, freqai, canvas, signal_center, order_intelligence。
2. 策略状态支持 draft, validated, backtested, paper_running, paper_passed, live_pending, live_small, paused, archived, rejected。
3. 新建策略入口支持：
   - 手动创建
   - AI 对话创建
   - 从 Signal 创建
   - 从 AI 研究创建
   - 从 RAG 创建
   - 从画布创建
4. 策略卡片展示：
   - 名称
   - 来源
   - 状态
   - mode
   - sharpe
   - max_drawdown
   - last_signal
   - risk_status
5. 策略必须先 validate 才能 backtest。
6. backtested 后才能 paper。
7. 第一阶段禁止 live。
```

## 5. TradingAgents Adapter Prompt

```text
本轮任务：实现 TradingAgents Adapter。

要求：
1. TradingAgents 只作为 AI 投研委员会，不直接交易。
2. 输出 ResearchReport, TradingSignal, RiskOpinion, StrategyDraft。
3. 展示多 Agent 过程：
   - Technical Analyst
   - Sentiment Analyst
   - Onchain Analyst
   - Bull Researcher
   - Bear Researcher
   - Risk Manager
   - Portfolio Manager
4. 所有输出必须结构化 JSON。
5. LLM 输出失败返回 hold / high risk。
6. 发布 Signal 时 can_live_trade=false。
7. 支持生成策略草稿但不自动执行。
```

## 6. Manipulation Radar Prompt

```text
本轮任务：实现 Manipulation Radar。

要求：
1. 计算 manipulation_score, stop_hunt_score, holder_concentration_score, liquidity_trap_score, pump_dump_score, funding_squeeze_score。
2. 输入包括：
   - OHLCV
   - volume
   - funding_rate
   - open_interest
   - liquidation
   - exchange_inflow
   - holder concentration
   - news sentiment
3. 输出 ManipulationSignal。
4. manipulation_score > 80 时 can_live_trade=false 且 risk_level=extreme。
5. 输出 reasoning 和 evidence。
6. 所有风险信号进入 Signal Center。
```

## 7. Growth Engine Prompt

```text
本轮任务：实现 Growth Engine。

要求：
1. 同步历史订单。
2. 为每笔订单保存 entry_feature_snapshot。
3. 平仓后标记 win/loss/breakeven。
4. 使用 SHAP 分析特征贡献。
5. 挖掘盈利订单共同特征。
6. 挖掘亏损订单共同特征。
7. 生成 StrategyCandidate。
8. Candidate 只能进入 backtest，不允许直接 paper/live。
9. 输出 daily_review, weekly_diagnosis, candidate_strategy。
```

## 8. UI Prompt

```text
本轮任务：按照 PulseDesk 当前截图风格实现页面。

视觉约束：
1. 白底。
2. 绿色主色。
3. 卡片式布局。
4. macOS 原生窗口感。
5. 左侧固定导航。
6. 顶部状态栏。
7. 交易数字使用等宽字体。
8. 风险用黄/红提示。
9. 不要做 SaaS 后台风。
10. 不要做重色彩 dashboard。

页面需支持：
AI 总控台、AI 投研室、Agent 平台、信号中心、策略工作台、策略画布、回测中心、执行记录、风控中心、操控雷达、复盘成长、AI 服务。
```

---

# v2.1 开发 AI 总约束 Prompt

每次让开发 AI 写代码前，先粘贴本段。

```text
你正在开发 PulseDesk，一个个人 AI 量化交易工作台。不要把它做成 SaaS、多用户平台或普通交易面板。

核心主线：
数据 → 特征 → AI/Agent → Signal → 策略 → 回测/dry-run → RiskEngine → Freqtrade → 订单 → 归因 → 自我进化。

强制架构规则：
1. Signal Center 是所有模块的中枢。
2. AI/Agent/模型/市场情绪/预测/因子/操控雷达都必须输出统一 Signal。
3. AI 和 Agent 不允许直接下单。
4. PulseDesk 不直接连接交易所下单，Crypto 执行只通过 Freqtrade Docker + CCXT。
5. 所有 TradeIntent 必须经过 RiskEngine。
6. Freqtrade dry-run 和 backtest 是两个不同状态，不允许混用。
7. 策略画布只是策略工作台中的编辑模式，不是一级主线。
8. 高风险猎币必须使用独立资金池，默认不开杠杆，默认不允许自动实盘。
9. 所有对象必须有生命周期状态和审计日志。
10. 不允许使用 TODO 留空实现；无法完成时必须返回明确错误。
```

## Signal Center 开发 Prompt

```text
本轮只开发 Signal Center 契约与最小闭环。

请实现：
1. TypeScript SignalV21 类型。
2. Pydantic SignalCreate / SignalRead / SignalLifecycleEvent。
3. PostgreSQL signals / signal_lifecycle_events / signal_evidence 表 migration。
4. FastAPI routes:
   - POST /api/signals
   - GET /api/signals
   - GET /api/signals/{id}
   - POST /api/signals/{id}/archive
   - POST /api/signals/{id}/publish-to-strategy
   - POST /api/signals/{id}/observe-paper
5. 前端 Signal Center 页面：列表、筛选、详情抽屉、生命周期、权限展示。
6. Mock 数据必须包含 tradingagents、sentiment、prediction、factor、freqai、manipulation 六类 Signal。

约束：
- Signal 必须包含 source_type/source_name/symbol/direction/confidence/expires_at/status/permission。
- AI/Agent/Prediction/FreqAI Signal 默认 can_live_trade=false。
- 发布 Signal 时必须写 lifecycle event。
- 任何字段校验失败返回 422，不允许静默兼容。
```

## Freqtrade Adapter 开发 Prompt

```text
本轮开发 Freqtrade Adapter，不实现真实交易，只实现 backtest + dry-run 管理。

请实现：
1. FreqtradeRun 数据模型和数据库 migration。
2. StrategyRuleDSL + Validator + PulseDeskUniversalStrategy.py 固定模板，先支持一个最小 RSI 规则。
3. config.json 生成器，必须支持 dry_run=true。
4. Docker manager：start/stop/status/logs。
5. Backtest runner：运行 Freqtrade backtesting 并解析结果。
6. Dry-run manager：启动 dry-run 容器并记录 heartbeat。
7. API：
   - POST /api/freqtrade/strategy/generate
   - POST /api/freqtrade/config/generate
   - POST /api/freqtrade/backtest/run
   - POST /api/freqtrade/docker/start
   - POST /api/freqtrade/docker/stop
   - GET /api/freqtrade/status
8. 前端 dry-run 监控页面显示 run status、heartbeat、last_error。

约束：
- 不允许 live trading。
- 不允许后端直接保存交易所 API key 明文。
- Docker 操作只能在 backend 内部执行，UI 不直接操作 Docker。
- Freqtrade 失连时 run 状态必须变为 degraded。
```

## 策略工作台与画布 Prompt

```text
本轮开发策略工作台，不把画布做成一级页面。

请实现：
1. Strategy / StrategyVersion / RiskPolicy 类型。
2. 策略列表与详情页。
3. 策略详情 Tab：Overview / Signals / Rules / Canvas / Backtest / Dry-run / Risk / Execution / Growth。
4. Canvas 只在策略详情页 Canvas Tab 中打开。
5. Canvas 输出 Strategy DSL，不直接触发执行。
6. 从 Signal 创建 StrategyDraft，并编译为 StrategyRuleDSL 草稿。
7. 策略状态机：draft → validated → backtested → dry_running → dry_run_passed → live_pending。

约束：
- Canvas 不允许直接调用 Freqtrade。
- 策略进入 dry-run 前必须 backtested。
- 策略进入 live_pending 前必须 dry_run_passed。
```

---

# v2.2 开发 AI 强制 Prompt 补充

## 1. Inference Queue 开发约束

```text
你正在开发 PulseDesk 的 ai_quant_core 推理队列。

强制要求：
1. 所有 heavyweight AI 任务必须进入 InferenceJob 队列。
2. 不允许在 FastAPI 请求线程内直接运行 Ollama、TimesFM、Chronos、SHAP 批量解释。
3. Job 必须支持 queued/running/succeeded/failed/cancelled/timeout/degraded 状态。
4. 每个 Job 必须有 timeout_sec。
5. OOM 或模型失败不得导致 API 主进程崩溃。
6. Freqtrade 状态同步、RiskEngine、Emergency Stop 不进入该队列。
7. 提供 mock provider，确保无 GPU 环境也能运行单元测试。
```

## 2. StrategyRuleDSL 开发约束

```text
你正在开发 PulseDesk 策略生成模块。

强制要求：
1. 禁止让 LLM 或画布直接生成 Freqtrade Strategy.py。
2. 只能生成 StrategyRuleDSL JSON。
3. DSL 必须经过 Pydantic 校验。
4. 指标、操作符、字段必须使用白名单。
5. 非白名单字段直接拒绝。
6. Freqtrade 侧只使用固定 PulseDeskUniversalStrategy.py 模板。
7. 不允许 exec/eval/import/subprocess/os/sys/open。
8. 生成器必须输出 strategy_rules.json，而不是 Python 代码。
```

## 3. Signal 存储治理开发约束

```text
你正在开发 Signal Center 存储层。

强制要求：
1. PostgreSQL signals 表必须支持按月分区。
2. Signal Center 默认查询最近 7 天。
3. 列表接口不返回完整 reasoning/evidence 大文本。
4. expired/archived 低分 Signal 需要支持归档任务。
5. 不允许无过滤条件扫描全量 signals。
6. 所有归档和删除操作必须写 audit log。
```

## 4. MCP Server 开发约束

```text
你正在开发 PulseDesk MCP Server。

强制要求：
1. MCP v1 只读。
2. 禁止 MCP 启动 live、下单、修改风控、更新 API Key、写 Python 策略、运行 shell。
3. 只允许读取 signals、strategies、backtest reports、freqtrade status、orders、risk events、growth reports。
4. 默认监听 127.0.0.1。
5. 所有调用必须写 mcp_audit_logs。
6. 返回值必须脱敏。
```

## 5. Freqtrade 双层风控开发约束

```text
你正在开发 Freqtrade Adapter。

强制要求：
1. 生成 config 时必须包含 stoploss。
2. 生成 config 时必须包含 max_open_trades。
3. live_small 不允许 stoploss = 0。
4. 高风险策略不允许 unlimited max_open_trades。
5. REST/WebSocket 失连时必须进入 degraded 状态。
6. 有持仓且 PulseDesk 失连时，必须显示 freqtrade_native_guard_only。
7. 不允许把全部止损逻辑只写在 PulseDesk 后端。
```

---

# v2.3 Cloud / Hybrid AI Routing 开发 Prompt

## 1. LLMRouter v2.3 Prompt

```text
本轮任务：实现 PulseDesk LLMRouter v2.3。

目标：
把 AI Quant Core 从“本地模型优先”升级为“云端 LLM 优先 + 远程专用模型 + 本地兜底”。

必须实现：
1. Provider 抽象：BaseProvider。
2. CloudLLMProvider：OpenAIProvider / AnthropicProvider / DeepSeekProvider 至少预留接口。
3. LocalModelProvider：OllamaProvider 作为 fallback。
4. RemoteModelProvider：ReplicateProvider / RunPodProvider / PrivateModelServerProvider 预留接口。
5. ProviderPolicyEngine：根据 task_type、privacy_level、latency_class、quality_level、max_cost_usd 选择 Provider。
6. PrivacyRedactor：所有云端请求前必须脱敏。
7. StructuredOutputValidator：所有云端输出必须 JSON Schema + Pydantic validate。
8. ProviderTrace：所有云端生成的 Signal / ResearchReport 必须记录 provider_trace。
9. CostTracker：记录 latency_ms、estimated_cost_usd、status。
10. FallbackChain：云端失败后降级到下一个 Provider；全部失败时返回 degraded，不抛崩溃。

强制禁止：
1. 不允许把 API Key / secret / token 发给云端模型。
2. 不允许云端模型生成 Strategy.py。
3. 不允许云端模型直接生成 live order。
4. 不允许 Provider 切换改写历史 Signal。
5. 不允许 AI Provider 失败影响 Freqtrade 原生风控。

请输出：
1. 后端目录结构
2. Pydantic Schema
3. Provider base class
4. DeepSeek 或 OpenAI provider 示例实现
5. Ollama fallback 示例实现
6. PrivacyRedactor
7. ProviderTrace 入库逻辑
8. 单元测试
9. Mock provider
10. 验收标准
```

## 2. Cloud Sentiment Signal Prompt

```text
本轮任务：把原本 FinBERT 本地情绪分析升级为云端 LLM Structured Output 情绪分析，并保留本地 FinBERT fallback。

要求：
1. 输入新闻/公告/社媒/KOL 文本。
2. 调用 LLMRouter，task_type=sentiment_classification。
3. 输出 SentimentSignal JSON。
4. 必须包含 sentiment_score, sentiment_label, confidence, narrative_tags, manipulation_clues, reasoning。
5. 失败时 fallback 到 LocalFinBERTProvider。
6. 如果 cloud 和 local 都失败，返回 neutral degraded Signal。
7. permission.can_live_trade 必须为 false。
8. provider_trace 必须入库。
```

## 3. Remote Timeseries Provider Prompt

```text
本轮任务：实现 TimesFM / Chronos 远程模型 Provider 抽象。

要求：
1. 实现 RemoteModelProvider base class。
2. 支持 submit_job / poll_job / fetch_result。
3. 支持 ReplicateProvider / RunPodProvider / PrivateModelServerProvider 预留。
4. 请求必须异步。
5. 超时后生成 degraded PredictionSignal。
6. 不允许阻塞交易执行链路。
7. PredictionSignal 默认 can_live_trade=false。
8. provider_trace 必须入库。
```

## 4. AI Service UI v2.3 Prompt

```text
本轮任务：升级 AI 服务管理页面。

页面新增模块：
1. Provider 列表：OpenAI / Anthropic / DeepSeek / Ollama / Replicate / RunPod / Private Model Server。
2. 每个 Provider 展示：启用状态、用途、平均延迟、今日成本、失败率。
3. Task Routing Matrix：每种任务当前使用哪个 Provider。
4. Privacy Level 设置：public / medium / sensitive / local_only。
5. Inference Queue 状态：cloud_llm_queue / remote_model_queue / local_gpu_queue。
6. 本地 GPU 状态：idle / busy / OOM_protected / unavailable。
7. Provider Trace 查看入口。

强制：
1. 不在 UI 展示完整 API Key。
2. API Key 只允许写入安全配置，不写日志。
3. Provider disabled 后新任务不能再路由过去。
4. 历史 Signal 保持 provider_trace 不变。
```


---

# v2.3.2 Prompt Addendum for Code AI

When implementing PulseDeskUniversalStrategy, do not read JSON rule files in every dataframe callback. Use cached rules, mtime/hash/version checks, and last-known-good fallback.

When implementing Signal archival, do not let `trade_intents.source_signal_ids` become dead links. Build `SignalRepository` and snapshot referenced signals before archive/deletion.

When implementing Freqtrade reconnect logic, never resume trading immediately after REST reconnect. Enter `reconciliating`, block outbound intents, pull Freqtrade truth state, patch local DB, run risk scan, and only then return to healthy.

## v2.4 开发 AI 全局约束 Prompt

```text
你正在开发 PulseDesk v2.4。必须遵守：

1. 不允许把 RawData / Feature / Insight 全部写成 Signal。Signal 只表示可进入策略判断的交易信号。
2. signals 表只能作为轻量索引表，reasoning / evidence / raw_output / provider_trace 必须拆表。
3. 所有策略来源最终必须编译为 StrategyRuleDSL(JSON)。
4. 禁止生成开放式 Strategy.py。Freqtrade 只加载固定 PulseDeskUniversalStrategy.py。
5. 画布只是 StrategyRuleDSL 的可视化编辑器，不直接操作 Freqtrade。
6. 所有 Freqtrade 写操作必须通过 Command Bus。
7. UI、AI、Canvas 不允许直接调用 Docker。
8. Execution Ledger 只能 append，不能 update/delete。
9. TradeIntent 创建时必须保存 signal snapshot 和 feature_snapshot_id。
10. Growth Engine 只能生成 StrategyCandidate，不能自动替换实盘策略。
11. 交易所原生 API 第一阶段只读，交易执行只走 Freqtrade。
12. API Key / secret 永不进入 Cloud LLM / MCP / 日志。
```


---

## v2.5 收口说明

本文件中若仍存在与 `00_MASTER_ARCHITECTURE_DECISION_v2_5.md` 冲突的旧描述，以 v2.5 Master Architecture Decision 为准。特别是：禁止开放式 Strategy.py 生成；禁止 Canvas 生成 Python；Freqtrade 只加载固定 `PulseDeskUniversalStrategy.py` 并读取 StrategyRuleDSL RulePackage。
