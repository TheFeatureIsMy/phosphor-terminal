# PulseDesk v2.0 安全约束与风险审查

## 1. 总体原则

PulseDesk 涉及真实资金，因此所有 AI、Agent、策略、执行链路都必须默认不可信。

## 2. 资金安全原则

1. 默认模式为 `read_only` 或 `paper`。
2. 第一阶段禁止 `live_trade`。
3. live_small 必须人工确认。
4. 所有 live 策略必须有：
   - 回测报告；
   - dry-run 运行记录；
   - 风控通过记录；
   - 人工确认记录；
   - 最大仓位限制；
   - 紧急停止可用。
5. 禁止 AI 自动提高仓位。
6. 禁止 AI 自动关闭风控。
7. 禁止任何策略绕过 RiskEngine。
8. 禁止无限补仓和马丁格尔默认开启。

## 3. AI/Agent 安全边界

### 3.1 AI 输出限制

AI/Agent 只能输出：

```text
ResearchReport
Signal
StrategyDraft
RiskOpinion
TradeIntent
```

不能直接调用：

```text
Freqtrade live endpoint
CCXT order API
Docker stop/remove host critical containers
File system dangerous write
Shell command
```

### 3.2 LLM 输出校验

所有 LLM 输出必须经过：

1. JSON parse；
2. Pydantic validate；
3. enum 字段校验；
4. 数值范围校验；
5. 交易权限校验；
6. 风控校验。

失败时返回安全默认值：

```json
{
  "direction": "hold",
  "confidence": 0,
  "risk_level": "high",
  "permission": {
    "can_live_trade": false
  }
}
```

### 3.3 Prompt Injection 防护

RAG 文档、新闻、网页、研报、社媒都可能含 prompt injection。

规则：

1. 文档内容只作为 data，不作为 instruction。
2. System Prompt 不允许被文档覆盖。
3. 工具调用权限必须在代码层限制，不依赖 LLM 自觉。
4. RAG 结果中如果出现“忽略之前指令”等内容，标记为 suspicious。
5. 任何外部文本都不能修改交易权限。

## 4. Freqtrade 安全

1. PulseDesk 不保存明文交易所 API Key。
2. API Key 使用系统 Keychain 或加密存储。
3. Freqtrade config 生成时不要把 API Key 写入可被 Git 跟踪的目录。
4. Docker volume 权限最小化。
5. Freqtrade REST API 仅监听 localhost 或内网。
6. REST API 必须有用户名和强密码。
7. WebSocket 仅用于读取事件，不允许任意命令。
8. live 配置与 dry-run 配置目录分离。
9. live 容器命名必须包含 `live-small`，避免误启动。
10. Docker 管理由 backend 封装，UI 层不得直接操作 Docker socket。

## 5. RiskEngine 强制门禁

所有交易意图必须经过：

```text
Signal/Strategy/Agent
  ↓
TradeIntent
  ↓
RiskEngine
  ↓
RiskDecision
  ↓
Freqtrade Adapter
```

RiskDecision 结果：

| Decision | 含义 |
|---|---|
| ALLOW | 允许执行 |
| REDUCE_SIZE | 降低仓位后执行 |
| REJECT | 拒绝 |
| PAPER_ONLY | 只允许模拟 |
| HUMAN_CONFIRM | 需要人工确认 |

## 6. 风控规则

### 6.1 全局风控

```json
{
  "max_position_pct_per_trade": 0.03,
  "max_total_position_pct": 0.30,
  "max_daily_loss_pct": 0.03,
  "max_consecutive_losses": 3,
  "cooldown_after_loss_minutes": 60,
  "max_slippage_pct": 0.005,
  "allow_leverage": false,
  "emergency_stop": false
}
```

### 6.2 Agent 风控

1. `observe_only` Agent 只能输出观察。
2. `signal_only` Agent 只能发布 Signal。
3. `paper_trade_allowed` Agent 只能进入 paper。
4. `live_requires_confirm` Agent 需要人工确认。
5. 连续表现差的 Agent 自动降权。
6. 低置信度 Agent Signal 不允许生成 live 策略。

### 6.3 操控风险

| 条件 | 处理 |
|---|---|
| manipulation_score > 80 | 禁止实盘 |
| stop_hunt_score > 75 | 禁止追单 |
| holder_concentration_score > 85 | 只允许观察 |
| exchange_inflow_spike | 禁止加仓 |
| funding_extreme | 降仓或只观察 |
| liquidity_trap_score > 75 | 禁止市价单 |

## 7. 策略安全

1. 策略必须经过状态机：
   ```text
   draft → validated → backtested → paper_running → paper_passed → live_pending → live_small
   ```
2. `draft` 不允许执行。
3. `validated` 只允许回测。
4. `backtested` 可进入 paper。
5. `paper_passed` 才可申请 live。
6. `live_pending` 必须人工确认。
7. `live_small` 必须小仓位。

## 8. 自我成长安全

Growth Engine 只能生成：

```text
CandidateStrategy
ParameterSuggestion
RiskSuggestion
AgentWeightSuggestion
```

不能自动执行：

```text
替换实盘策略
提高仓位
关闭止损
关闭风控
删除日志
```

## 9. 审计日志

必须记录：

- Signal 创建；
- Signal 转 StrategyDraft；
- Strategy 版本变更；
- Backtest 运行；
- Paper 运行；
- TradeIntent 创建；
- RiskDecision；
- Freqtrade 容器启动/停止；
- 订单同步；
- Agent 输出；
- LLM 原始输出摘要；
- 人工确认；
- emergency stop。

## 10. 开发安全 Prompt

开发 AI 必须遵守：

```text
不允许实现任何绕过 RiskEngine 的交易路径。
不允许实现 AI 直接调用 Freqtrade live 的代码。
不允许默认开启 live trading。
不允许把 API Key 写入日志。
不允许忽略 Pydantic 校验。
不允许写 TODO 空实现。
不允许捕获异常后静默失败。
所有失败必须返回安全默认值和错误日志。
```

---

# v2.1 安全与风险补强

## 6. 高风险猎币模式资金池规范

高风险猎币模式必须使用独立资金池，不能与主策略资金池共享预算、仓位、止损和自动化权限。

### 6.1 默认配置

| 参数 | 默认值 | 是否可上调 | 说明 |
|---|---:|---:|---|
| total_budget | 账户权益的 1%-5% | 可手动 | 独立预算 |
| max_position_pct_per_trade | 0.5% | 不建议 | 单笔最大资金池占比 |
| max_total_exposure_pct | 3% | 不建议 | 高风险总暴露 |
| max_daily_loss_pct | 1% | 不建议 | 日亏损达到即暂停 |
| max_drawdown_pct | 8% | 不建议 | 回撤到达即停止资金池 |
| allow_leverage | false | 第一阶段不可改 | 默认禁止杠杆 |
| allow_auto_trade | false | 第一阶段不可改 | 只能人工确认 |
| requires_human_confirm | true | 不可关闭 | 必须确认 |
| manipulation_score > 80 | reject live | 不可关闭 | 只允许观察/模拟 |

### 6.2 禁止行为

- 禁止补仓摊平；
- 禁止自动扩大仓位；
- 禁止关闭止损；
- 禁止使用主资金池；
- 禁止 AI/Agent 自动进入 live；
- 禁止在 Freqtrade 失连或数据过期时继续交易。

## 7. AI / Agent 安全规则

1. LLM 输出必须通过 JSON schema 校验。
2. LLM 输出不得直接写入 Strategy.py，必须进入 StrategyDraft。
3. Agent 权限默认为 `signal_only`。
4. 云模型不可用时，Agent 权限降级，不允许 live_small。
5. 本地模型输出质量不稳定时，只允许生成 `pending` Signal。
6. 所有 Prompt 版本必须记录。
7. 所有工具调用必须使用白名单。
8. 禁止 Agent 读取 API Key 明文。

## 8. 技术依赖风险清单

| 风险 | 等级 | 安全措施 |
|---|---|---|
| Freqtrade 策略生成错误 | 高 | 生成后先 `validate`，再 backtest，禁止直接 dry-run |
| Docker 管理权限过大 | 高 | backend 封装 Docker 操作，UI 不直接访问 socket |
| 交易所 API 限流/异常 | 中 | Freqtrade 处理交易所连接，PulseDesk 只读同步 |
| LLM 延迟影响交易 | 高 | AI Signal 不直接实时交易；实时交易依赖已缓存 Signal |
| 链上数据不完整 | 中 | 数据源状态必须显示，缺失时操控分降级或标记 unknown |
| 预测模型过拟合 | 高 | TimesFM/Chronos/FreqAI 只输出 Signal，必须回测/dry-run |
| 历史订单样本不足 | 中 | Growth Engine 低样本时只能输出观察报告，不生成候选策略 |
| 操控雷达误判 | 高 | 操控雷达输出 RiskSignal，不输出确定交易建议 |


---

# v2.2 新增安全约束

## 1. 本地模型推理安全与资源隔离

### 风险

本地 LLM、TimesFM、Chronos、SHAP、FinBERT 并发运行可能导致 VRAM OOM、延迟飙升或 worker 崩溃。

### 强制约束

1. 所有 heavyweight AI job 必须进入 `Inference Worker Queue`。
2. Freqtrade 状态同步、RiskEngine、Emergency Stop 不能与 AI 推理共用阻塞线程。
3. 本地模型推理必须有 timeout。
4. OOM 或推理失败必须返回 degraded，不允许导致 API 主进程崩溃。
5. UI 必须显示 AI 队列状态和 degraded 原因。

## 2. Strategy.py 代码注入防护

### 强制禁止

- 禁止 LLM 直接生成 Python 策略文件；
- 禁止画布输出 Python；
- 禁止将自然语言策略描述拼接为 Python；
- 禁止运行 `exec/eval/import/subprocess/os/sys/open`；
- 禁止策略模板访问 API Key 或 shell。

### 正确方式

```text
AI / Canvas → StrategyRuleDSL(JSON) → DSL Validator → PulseDeskUniversalStrategy.py
```

## 3. MCP Server 安全

MCP v1 只读。禁止任何交易、写文件、Docker 管理、风控关闭、API Key 更新能力。

MCP Server 必须：

1. 默认监听 `127.0.0.1`；
2. 使用独立 token；
3. 记录 `mcp_audit_logs`；
4. 返回内容脱敏；
5. 不暴露真实 API Key、secret、私钥；
6. 不允许 `run_shell_command` 类工具；
7. 不允许通过 MCP 启动 live_small。

## 4. Freqtrade 双层风控

PulseDesk 上层风控失效时，Freqtrade 必须仍有硬风控。

所有由 PulseDesk 生成的可运行策略配置必须包含：

- `stoploss`；
- `max_open_trades`；
- 仓位约束；
- 订单类型约束；
- dry-run/live 标识；
- 高风险策略额外限制。

禁止：

- `live_small` 策略 `stoploss = 0`；
- 高风险猎币使用 unlimited `max_open_trades`；
- PulseDesk 失联时自动加仓；
- 把止损逻辑只放在 PulseDesk 后端。

## 5. Signal 存储安全

1. Signal 大文本 reasoning 不进入列表查询；
2. archived/expired 低分 Signal 应归档或清理；
3. 冷存档文件不得包含 API Key；
4. 归档任务必须可审计；
5. 删除 Signal 前必须保留被执行交易的关联证据。

---

# v2.3 Addendum — Cloud AI Security Guardrails

## 1. 云端 AI 使用边界

允许出云：

```text
public_market_data
公开新闻/公告/研报文本
脱敏后的交易统计摘要
Signal reasoning 所需的非敏感上下文
```

禁止出云：

```text
exchange API key
exchange secret
wallet private key / seed phrase
原始订单流水明细，除非人工确认
本地文件绝对路径
数据库连接串
系统环境变量
Freqtrade config 中的 secret 字段
```

## 2. PrivacyRedactor 强制执行

所有 CloudLLMProvider / RemoteModelProvider 请求前必须执行：

```text
PrivacyRedactor.redact(payload) -> RedactedPayload
```

Redactor 必须：

1. 删除 API Key / secret / token；
2. 脱敏账户 ID；
3. 删除本地路径；
4. 原始订单明细默认聚合为统计摘要；
5. 输出 input_hash；
6. 记录 redaction_report。

## 3. Structured Output 强制规则

云端模型输出必须：

```text
JSON Schema validate
Pydantic validate
enum validate
permission validate
安全默认值 fallback
```

失败时：

```text
Signal.status = degraded
Signal.direction = hold 或 risk
permission.can_live_trade = false
```

## 4. Provider 切换规则

1. Provider 切换只影响新任务；
2. 历史 Signal 不允许重写 provider_trace；
3. 如果同一输入用新 Provider 重跑，必须生成新的 Signal version；
4. Provider 降级不得自动升级交易权限；
5. 云端 Provider 不可用时，不允许为了“继续交易”而降低风控要求。

## 5. 成本与速率限制

```text
daily_cost_limit_usd
per_task_cost_limit_usd
max_concurrent_cloud_requests
provider_timeout_seconds
retry_count
cooldown_after_failure
```

成本超限时：

```text
非关键 AI 任务暂停
Signal generation 标记 cost_limited
交易执行链路不受影响
```

## 6. live_small 安全边界

1. live_small 不得依赖实时云端 LLM 响应；
2. live_small 只能使用已生成、已过风控、未过期的 Signal；
3. AI Provider degraded 时，live_small 不自动加仓；
4. Freqtrade 原生 stoploss / trailing_stop / max_open_trades 必须始终存在。


---

# v2.3.2 Additional Guardrails

1. UniversalStrategy must not repeatedly perform blocking disk I/O on hot-path callbacks.
2. Invalid `StrategyRuleDSL` updates must not crash Freqtrade and must not overwrite last-known-good rules.
3. Referenced Signal evidence must be snapshotted before cold archive or deletion.
4. `reconciliating` blocks all new TradeIntent until Freqtrade truth source has been synchronized.
5. If reconciliation has unresolved mismatches, system state must become `manual_review_required`.

## v2.4 架构审计补丁：数据库与模块安全约束

### 1. 数据库写入边界

```text
UI 不允许直接写数据库。
AI Quant Core 不允许直接写 strategy_versions。
Canvas 不允许直接写 Freqtrade rules 文件。
Freqtrade Adapter 不允许自行决定 live 权限。
Execution Ledger 禁止 update/delete。
```

### 2. Command Bus 安全

所有 Freqtrade 写命令必须有：

```text
command_id
idempotency_key
requested_by
status
payload
audit trail
```

`RequestLiveSmallCommand` 必须包含 `human_confirmed=true`。

### 3. Exchange API 安全

```text
第一阶段交易执行只走 Freqtrade。
交易所原生 API 默认只读。
提现权限永远禁止。
交易 Key 不得暴露给 AI Quant Core / MCP / Cloud Provider。
Cloud LLM 请求不得包含 API Key、secret、未脱敏订单明细。
```

### 4. Reconciliation 安全

在 `reconciliating` 状态：

```text
阻塞所有新 TradeIntent。
只允许 EmergencyStopCommand / StartReconciliationCommand。
以 Freqtrade / Exchange 为真理源覆盖本地状态。
差异无法解决时进入 manual_review_required。
```
