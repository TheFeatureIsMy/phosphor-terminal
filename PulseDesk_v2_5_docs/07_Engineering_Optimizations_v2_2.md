# PulseDesk v2.2 工程化优化方案

本文件专门描述 v2.2 新增的工程级优化：本地多模型推理调度、策略 DSL 编译、Signal 存储治理、MCP Server、Freqtrade 双层风控兜底。

---

## 1. 本地多模型推理调度：Inference Worker Queue

### 1.1 背景

PulseDesk 会同时集成：

- Ollama / 本地 LLM；
- FinBERT；
- TimesFM；
- Chronos；
- SHAP；
- TradingAgents / LangGraph 工作流。

这些模型如果在单卡 GPU 上并发运行，容易出现：

- VRAM OOM；
- 推理延迟飙升；
- UI degraded；
- 后端 worker 崩溃；
- Signal 生成超时；
- Freqtrade dry-run 监控被 AI 任务阻塞。

### 1.2 设计结论

AI 信号不是 HFT 高频链路，必须牺牲并发换稳定性。

强制原则：

```text
所有本地 heavyweight 推理任务必须进入 Inference Worker Queue。
默认同一张 GPU 同时只运行一个 heavyweight 任务。
Signal 生成允许延迟，但不允许拖垮执行监控。
```

### 1.3 任务等级

| 等级 | 示例 | 并发策略 | 超时 | 可取消 |
|---|---|---|---|---|
| lightweight | 简单规则、Redis 查询、Signal 聚合 | 可并发 | 5s | 是 |
| medium | FinBERT 单文本、短 RAG 摘要 | 小并发 | 30s | 是 |
| heavyweight | Ollama LLM、TradingAgents、TimesFM、Chronos、SHAP 批量解释 | GPU 串行 | 180s-900s | 是 |
| critical | Freqtrade 状态同步、RiskEngine、Emergency Stop | 不进入 AI 队列 | 2s-10s | 不建议取消 |

### 1.4 后端模块

```text
ai_quant_core/
├── inference_queue.py
├── vram_scheduler.py
├── model_registry.py
├── model_runtime_state.py
├── job_store.py
└── provider_adapters/
    ├── ollama_adapter.py
    ├── finbert_adapter.py
    ├── timesfm_adapter.py
    ├── chronos_adapter.py
    └── shap_adapter.py
```

### 1.5 InferenceJob Schema

```json
{
  "id": "job_xxx",
  "task_type": "llm_research|finbert_sentiment|timesfm_forecast|chronos_forecast|shap_explain",
  "priority": "low|normal|high|critical",
  "model_provider": "ollama|openai|deepseek|local_finbert|timesfm|chronos|shap",
  "model_name": "qwen2.5:7b",
  "resource_class": "lightweight|medium|heavyweight",
  "gpu_required": true,
  "estimated_vram_mb": 8000,
  "status": "queued|loading_model|running|succeeded|failed|cancelled|timeout|degraded",
  "input_ref": "storage://inference_inputs/job_xxx.json",
  "output_ref": "storage://inference_outputs/job_xxx.json",
  "timeout_sec": 300,
  "created_at": "2026-06-02T10:00:00Z",
  "started_at": null,
  "finished_at": null,
  "error": null
}
```

### 1.6 调度策略

1. `critical` 系统任务不进入 AI 队列，避免被 LLM 阻塞。
2. `heavyweight` 默认 GPU 串行。
3. `medium` 可配置并发 1-2。
4. UI 上必须显示 AI 任务队列状态。
5. 任务超过 timeout 进入 `timeout`，并产出 degraded Signal，而不是阻塞主流程。
6. Provider 支持降级：本地模型 OOM 时可切换云模型，或输出“AI unavailable”。
7. 同一 symbol 的同类 forecast 任务必须去重，避免重复推理。

---

## 2. 禁止动态 Strategy.py：采用 StrategyRuleDSL + UniversalStrategy

### 2.1 背景

直接让 LLM 或画布生成 Freqtrade `Strategy.py` 有高风险：

- Python 语法错误；
- Freqtrade API 过期；
- pandas/ta-lib 写法错误；
- 缩进错误；
- 代码注入；
- 任意文件读写；
- 容器启动失败；
- 策略回测结果不可复现。

### 2.2 强制原则

```text
LLM / Canvas / StrategyDraft 不允许直接生成开放式 Python 代码。
只允许生成 StrategyRuleDSL(JSON)。
Freqtrade 侧只使用固定、审计过的 PulseDeskUniversalStrategy.py。
```

### 2.3 新执行链路

```text
AI / Signal / Canvas
  ↓
StrategyDraft
  ↓
StrategyRuleDSL(JSON)
  ↓
DSL Validator
  ↓
Strategy Compiler
  ↓
写入 strategy_rules.json / Redis / DB
  ↓
PulseDeskUniversalStrategy.py 读取规则
  ↓
Freqtrade backtest / dry-run
```

### 2.4 StrategyRuleDSL 示例

```json
{
  "schema_version": "2.2",
  "strategy_id": "strategy_bottom_001",
  "strategy_type": "bottom_accumulation",
  "symbol": "BTC/USDT",
  "timeframe": "1h",
  "indicators": [
    {"name": "rsi", "period": 14},
    {"name": "rolling_low", "window": 90},
    {"name": "atr", "period": 14}
  ],
  "entry_rules": {
    "operator": "AND",
    "conditions": [
      {"left": "price_percentile_90d", "op": "<", "right": 0.15},
      {"left": "sideways_days", "op": ">=", "right": 14},
      {"left": "manipulation_score", "op": "<", "right": 60}
    ]
  },
  "exit_rules": {
    "operator": "OR",
    "conditions": [
      {"left": "rsi", "op": ">", "right": 72},
      {"left": "stop_loss_pct", "op": "<=", "right": -0.06}
    ]
  },
  "risk": {
    "position_pct": 0.02,
    "max_total_position_pct": 0.08,
    "stoploss": -0.06,
    "trailing_stop": true,
    "max_open_trades": 2
  },
  "permissions": {
    "can_backtest": true,
    "can_dry_run": true,
    "can_live": false,
    "requires_human_confirm": true
  }
}
```

### 2.5 DSL 白名单

允许的指标：

```text
rsi, macd, ema, sma, atr, bollinger, rolling_low, rolling_high,
price_percentile, volume_zscore, funding_rate, oi_change,
manipulation_score, sentiment_score
```

允许的操作符：

```text
<, <=, >, >=, ==, !=, cross_above, cross_below, between
```

禁止：

```text
import
exec
eval
open
subprocess
os
sys
requests
任意 Python 表达式
任意文件路径
任意 shell command
```

### 2.6 PulseDeskUniversalStrategy.py 约束

`PulseDeskUniversalStrategy.py` 是固定模板，只允许读取：

```text
strategy_rules.json
Freqtrade dataframe
Freqtrade config
只读 Redis/DB 快照，可选
```

它不允许：

```text
动态 import
执行 LLM 生成代码
联网请求
文件写入
shell command
读取 API Key
```

---

## 3. Signal 存储治理：分区、TTL、归档、Vacuum

### 3.1 背景

操控雷达、技术指标、预测模型、Agent 信号如果对大量币种和 1m/15m 周期运行，会快速产生大量 Signal。Signal 又包含 reasoning/evidence JSONB 和文本解释，长期保存在主表会导致：

- 查询变慢；
- 索引膨胀；
- JSONB 存储成本过高；
- UI 加载迟缓；
- 备份体积过大。

### 3.2 分层存储策略

| 数据 | 存储 | 保留期 | 说明 |
|---|---|---|---|
| active Signal | PostgreSQL + Redis latest index | 未过期 | 主查询 |
| expired 高分 Signal | PostgreSQL 分区表 | 90 天 | 用于复盘 |
| expired 低分 Signal | SQLite/Parquet 冷存档 | 14 天后迁移 | 减轻主库 |
| Signal reasoning 大文本 | 单独表或对象文件 | 按需加载 | UI 列表不直接查大文本 |
| latest signal index | Redis TTL | 1h-24h | 快速查询 |

### 3.3 PostgreSQL 分区建议

`signals` 按 `created_at` 月度 RANGE 分区：

```sql
CREATE TABLE signals (
    id UUID NOT NULL,
    source_type TEXT NOT NULL,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL,
    confidence NUMERIC(5,4),
    score NUMERIC(8,4),
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    payload JSONB NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
```

月度分区：

```sql
CREATE TABLE signals_2026_06
PARTITION OF signals
FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

### 3.4 Data Vacuum 任务

```text
data_center/data_vacuum.py
```

定时任务：

```text
每天 03:30 执行
```

规则：

1. `expired/archived` 且 `score < 2.5` 且超过 14 天：迁移到 SQLite/Parquet 后从主库删除。
2. `executed/rejected` 且有关联订单/风控：保留 180 天。
3. `high_score` 或 `manipulation_score > 80`：保留 180 天。
4. Signal 列表查询不加载 `reasoning_full`，只加载摘要。
5. 每月创建下月分区，每季度归档历史分区。

### 3.5 查询约束

Signal Center 默认只查：

```text
最近 7 天 + active/pending/executed/rejected
```

历史查询必须有：

```text
时间范围 + symbol/source/status 至少一个过滤条件
```

---

## 4. PulseDesk MCP Server

### 4.1 设计目的

PulseDesk 后续需要和 Claude Code、Cursor、ChatGPT Desktop、OpenAI Agents、其他本地 AI 客户端协作。MCP Server 用于让外部 AI 客户端通过标准工具接口读取 PulseDesk 数据，而不是手工复制日志。

### 4.2 MVP 原则

```text
MCP v1 只读。
不允许 MCP 工具触发交易、启动 live、修改 API Key、关闭风控。
```

### 4.3 MCP Tools

只读 tools：

```text
get_latest_signals(symbol?, source_type?)
get_signal_detail(signal_id)
get_active_strategies()
get_strategy_backtest_report(strategy_id)
get_freqtrade_status(run_id?)
get_open_positions()
get_recent_orders(symbol?, limit?)
get_risk_events(symbol?, level?)
get_manipulation_score(symbol)
get_growth_report(period)
```

受限写入 tools，默认禁用：

```text
create_strategy_draft_from_text(description)
create_research_task(symbol)
```

危险 tools，禁止：

```text
start_live_trade
stop_loss_override
disable_risk_engine
update_exchange_api_key
run_shell_command
write_strategy_python
```

### 4.4 MCP 安全约束

1. MCP Server 默认绑定 `127.0.0.1`。
2. 只读 API 使用独立 token。
3. MCP 工具返回数据必须脱敏：API Key、secret、真实账户敏感信息不可返回。
4. 所有 MCP 调用写入 `mcp_audit_logs`。
5. MCP tool description 必须具体、短、可测试，避免误调用。
6. MCP 不可访问策略文件系统写权限。
7. MCP 不可调用 Docker 管理 live 容器。

---

## 5. Freqtrade 双层风控兜底

### 5.1 问题

PulseDesk 后端、REST API、WebSocket、网络、Docker 管理进程都可能失连。如果发生失连时已有持仓，不能依赖 PulseDesk 实时下发止损。

### 5.2 设计结论

```text
Freqtrade 必须具备独立生存能力。
PulseDesk 上层风控失效时，Freqtrade 仍必须能按照本地 config 和 Strategy 模板守住止损、仓位、开仓数量。
```

### 5.3 Freqtrade 原生风控配置要求

每个由 PulseDesk 生成的 Freqtrade 配置必须包含：

```json
{
  "dry_run": true,
  "max_open_trades": 2,
  "stake_amount": "unlimited",
  "tradable_balance_ratio": 0.3,
  "stoploss": -0.06,
  "trailing_stop": true,
  "trailing_stop_positive": 0.02,
  "trailing_stop_positive_offset": 0.04,
  "trailing_only_offset_is_reached": true,
  "order_types": {
    "entry": "limit",
    "exit": "limit",
    "stoploss": "market",
    "stoploss_on_exchange": false
  }
}
```

> 注意：具体字段以当前 Freqtrade 稳定版文档为准，生成器必须版本锁定并在 CI 中验证 config 可加载。

### 5.4 失连状态机

```text
healthy
  ↓ REST/WebSocket timeout
connection_lost
  ↓ 10s 未恢复
pulse_degraded
  ↓ 有持仓
freqtrade_native_guard_only
  ↓ 恢复连接
reconciliating
  ↓ 对账成功
healthy
```

### 5.5 失连行为

| 场景 | PulseDesk 行为 | Freqtrade 行为 |
|---|---|---|
| REST 失连，无持仓 | 禁止新策略升级 | 继续 dry-run 或暂停，按配置 |
| REST 失连，有持仓 | UI 红色告警，只读 degraded | 原生 stoploss/trailing 生效 |
| WebSocket 失连 | 切换轮询 REST | 原生运行 |
| Docker 容器停止 | 标记 run failed | 无法执行，必须人工确认 |
| Freqtrade 正在 live_small | 禁止任何新开仓升级，要求人工检查 | 原生硬风控兜底 |

### 5.6 禁止事项

- 不允许只在 PulseDesk 中配置止损而 Freqtrade config 没有 stoploss。
- 不允许 live_small 策略 `stoploss = 0`。
- 不允许高风险猎币模式使用 unlimited max_open_trades。
- 不允许 PulseDesk 后端失联时自动提高仓位。

---

## 6. 开发验收清单

### 6.1 Inference Queue 验收

- 可以创建 job；
- 可以查看队列；
- heavyweight job 串行执行；
- job 超时后状态变为 timeout；
- OOM/异常不会导致 API 进程崩溃；
- UI 可看到 degraded 状态。

### 6.2 StrategyRuleDSL 验收

- AI 只能生成 JSON DSL；
- DSL 有 Pydantic 校验；
- 非白名单字段被拒绝；
- DSL 能生成 strategy_rules.json；
- Freqtrade 使用固定 `PulseDeskUniversalStrategy.py` 读取规则；
- 不存在 LLM 直接写 `.py` 策略代码路径。

### 6.3 Signal 存储治理验收

- signals 表按月分区；
- 创建下月分区任务可运行；
- Data Vacuum 可迁移 expired low-score signals；
- Signal Center 默认查询不扫全表；
- 大文本 reasoning 不阻塞列表页。

### 6.4 MCP 验收

- MCP Server 可返回最新 Signal；
- MCP Server 可返回 Freqtrade 状态；
- MCP 不能触发 live；
- MCP 调用写审计日志；
- 返回内容脱敏。

### 6.5 Freqtrade 双风控验收

- 生成 config 必须包含 stoploss；
- 生成 config 必须包含 max_open_trades；
- REST 失连后 UI 显示 degraded；
- 有持仓失连时显示 native guard only；
- live_small 之前检查 Freqtrade native config 完整性。

